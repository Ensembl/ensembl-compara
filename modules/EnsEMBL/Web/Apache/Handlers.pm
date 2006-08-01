package EnsEMBL::Web::Apache::Handlers;
# File Apache/EnsEMBL::Handlers.pm

use SiteDefs qw( :APACHE);
use strict;
use Apache::Constants qw(:common :response);
use EnsEMBL::Web::DBSQL::UserDB;
use EnsEMBL::Web::DBSQL::BlastAdaptor;
use EnsEMBL::Web::Object::BlastJobMaster;
use Apache::SizeLimit;
use Apache::URI ();
use CGI::Cookie;
use Time::HiRes qw(time);
my $requests;
my $process_start_time;
my $oracle_home;
use Sys::Hostname;
use Data::Dumper;
1;

my $BLAST_LAST_RUN;
############################################
## Perl Apache init handler
##------------------------------------------
## Copes with the handling of session tracking and user identification
##------------------------------------------
## Sets the three sub process environment variables:
##       session_ID, firstsession_ID and user_ID 
############################################

sub childInitHandler {
  $requests = 0;
  my $T2 = hostname();
  my $TT = "".reverse $$;
     $TT = ( $TT + $TT<<15 ) & 0xffffffff;
  while( $T2=~s/(.{1,4})// ) {
    $TT = $TT ^ unpack( "%32L*", $1 );
  }
  $process_start_time = time;
  srand( time() ^ $TT );

  if( $ENSEMBL_DEBUG_FLAGS & 8 ){
    print STDERR "Child $$: - initialised at @{[time]}\n";
  }
}

sub childExitHandler {
  if( $ENSEMBL_DEBUG_FLAGS & 8 ){
    print STDERR ( "Child $$: - reaped      at @{[time]} - ".
		   "Time: @{[time-$process_start_time]} ".
		   "Req: $requests Size: ".
		   "@{[&$Apache::SizeLimit::HOW_BIG_IS_IT()]}K\n" );
  }
}

sub initHandler {
  $requests ++;
  my $r = shift; # Get the connection handler
  $r->push_handlers( PerlTransHandler => \&transHandler );
  $r->push_handlers( PerlCleanupHandler => \&cleanupHandler );

## Retrieve the firstsession_ID and User ID from the cookie (ENSEMBL_FIRSTSESSION and ENSEMBL_USER)
  my $headers_in = $r->headers_in;
  my %cookies = CGI::Cookie->parse($r->header_in('Cookie'));
  $r->subprocess_env->{'ENSEMBL_FIRSTSESSION'} =
    %cookies && $cookies{$ENSEMBL_FIRSTSESSION_COOKIE} &&
    EnsEMBL::Web::DBSQL::UserDB::decryptID($cookies{$ENSEMBL_FIRSTSESSION_COOKIE}->value) || 0;
  $r->subprocess_env->{'ENSEMBL_USER'} =
    %cookies && $cookies{$ENSEMBL_USER_COOKIE} &&
    EnsEMBL::Web::DBSQL::UserDB::decryptID($cookies{$ENSEMBL_USER_COOKIE}->value) || 0;
  $r->subprocess_env->{'ENSEMBL_STARTTIME'} = time();

  ## hack for oracle/AV problem: if child has used Oracle before, redirect
  ## the request and kill the child
  if( ($ENSEMBL_SITETYPE eq 'Vega') && $oracle_home && ($r->uri =~ /\/textview/) ) {
    warn "[WARN] Killing child process to prevent Oracle/AV error.\n";
    my $location = $r->uri;
    if($r->args) {
      $location .= "?" . $r->args;
    }
    $r->headers_out->set(Location => $location);
    $r->child_terminate;
    return REDIRECT;
  }
  return;
}

sub cleanupHandler {
  my $r = shift;      # Get the connection handler

  ## hack for oracle/AV problem: remember that this child has used Oracle
  $oracle_home ||= $ENV{'ORACLE_HOME'};

  return  if $r->subprocess_env->{'ENSEMBL_ENDTIME'};
  my $end_time    = time();
  my $start_time  = $r->subprocess_env->{'ENSEMBL_STARTTIME'};
  my $length      = $end_time- $start_time;

  if( $length >= $ENSEMBL_LONGPROCESS_MINTIME ) {
    my $u           = $r->parsed_uri;
    my $file        = $u->path;
    my $query       = $u->query.$r->subprocess_env->{'ENSEMBL_REQUEST'};
    my $size        = &$Apache::SizeLimit::HOW_BIG_IS_IT();
    $r->subprocess_env->{'ENSEMBL_ENDTIME'} = $end_time;
    if( $ENSEMBL_DEBUG_FLAGS & 8 ) {
      print STDERR sprintf "LONG PROCESS %10s DT: %24s Time: %10s Size: %10s
LONG PROCESS %10s REQ: %s
LONG PROCESS %10s IP:  %s  UA: %s
", $$,  scalar(gmtime($start_time)), $length, $size, $$, "$file?$query", $$, $r->subprocess_env->{'HTTP_X_FORWARDED_FOR'}, $r->header_in('User-Agent');
    }
  }
  use Fcntl ':flock';
## Now we do the BLAST parser stuff!!
  _process_blast( $r ) if $ENV{'ENSEMBL_SCRIPT'} && $ENSEMBL_BLASTSCRIPT;
  
  if ($ENV{'ENSEMBL_SCRIPT'} && $ENSEMBL_BLASTSCRIPT) {
    #&queue_pending_blast_jobs;
  }

## Now we check if the die file has been touched...
  my $die_file = $ENSEMBL_SERVERROOT.'/logs/ensembl.die';
  if( -e $die_file ) {
    my @temp = stat $die_file;
    my $file_mod_time = $temp[9];
    if( $file_mod_time >= $process_start_time ) { 
      print STDERR sprintf "KILLING CHILD %10s\n", $$;
      if( $Apache::SizeLimit::WIN32 ) {
        CORE::exit(-2); 
      } else {
        $r->child_terminate();
      }
    }
    return DECLINED;
  }
}

sub _run_blast_no_ticket {
  my( $loads, $seconds_since_last_run ) = @_;
  return $loads->{'blast'} < 3 &&
         rand( $loads->{'httpd'} ) < 10 &&
         rand( $seconds_since_last_run ) > 1;
}

sub _run_blast_ticket {
  my( $loads, $seconds_since_last_run ) = @_;
  return $loads->{'blast'} < 8;
}

use vars qw($LOAD_COMMAND);
use Config;
BEGIN {
  if( $Config{'osname'} eq 'dec_osf' ) {
    $LOAD_COMMAND = \&_load_command_alpha;
  } elsif( $Config{'osname'} eq 'linux' ) {
    $LOAD_COMMAND = \&_load_command_linux;
  } $LOAD_COMMAND = \&_load_command_null;
};

sub _load_command_null {
  return 1;
}
sub _load_command_alpha {
  my $command = shift;
  my $VAL = `ps -A | grep $command | wc -l`;
  return $VAL-1;
}
sub _load_command_linux {
  my $command = shift;
  my $VAL = `ps --no-heading -C $command  | wc -l`;
  return $VAL+0;
}

sub _get_loads {
  return { 'blast' => &$LOAD_COMMAND( 'blast' ),
           'httpd' => &$LOAD_COMMAND( 'httpd' ) };
}

sub queue_pending_blast_jobs {

  my $queue_class = "EnsEMBL::Web::Queue::LSF";

  my $species_defs = EnsEMBL::Web::SpeciesDefs->new();
#  my $DB = $species_defs->databases->{'ENSEMBL_BLAST'}; 

  my $DB = { 'NAME' => 'ensembl_blast',
             'USER' => 'ensadmin',
             'PASS' => 'ensembl',
             'HOST' => 'ensarc-1-08',
             'PORT' => '3306' }; 

  my $blast_adaptor = EnsEMBL::Web::DBSQL::BlastAdaptor->new($DB);
  warn "Blast adaptor: " . $blast_adaptor;
  warn "Species def databases: " . $species_defs->databases->{'ENSEMBL_BLAST'};
  my $job_master = EnsEMBL::Web::Object::BlastJobMaster->new($blast_adaptor, $queue_class);
  $job_master->queue_pending_jobs;
  $job_master->process_completed_jobs;

}

sub _process_blast {
  my $r = shift;
  my $directory = $ENSEMBL_TMP_DIR_BLAST.'/pending';
  my $FLAG = 0; 
  my $count=0;
  my $ticket;
  my $_process_blast_called_at = time();

  warn "Processing BLAST in Apache: $r";

  $ticket = $ENV{'ticket'};
  ## Lets work out when to run this!!
  my $run_blast;
  my $loads = _get_loads();
  my $seconds_since_last_run = (time() - $BLAST_LAST_RUN);

  if( $ticket ) {
    if( _run_blast_ticket( $loads, $seconds_since_last_run ) ) {
      $FLAG = 1;
      $BLAST_LAST_RUN = time();
    }
  } else {
    ## Current run blasts..
    if( _run_blast_no_ticket( $loads, $seconds_since_last_run ) ) {
      $BLAST_LAST_RUN = time();
      $FLAG = 1;
    }
  }
  while( $FLAG ) {
    $count++;
    $FLAG = 0;
    if(opendir(DH,$directory) ) {
      while( my $FN = readdir(DH) ) {
        my $file = "$directory/$FN";
        next unless -f $file; # File....
        next if -z $file;     # Contains something
        my @STAT = stat( $file );
        next if $STAT[8]+5 > time(); # Was last modified more than 5 seconds ago!
        next if $ticket && $file !~ /$ticket/; 
     ## We have a ticket...
        open  FH, $file;
        flock FH, LOCK_EX;
        my $blast_file = <FH>;
        chomp $blast_file;
        if( $blast_file =~ /^([\/\w\.-]+)/ ) {
          $blast_file = $1;
        }
        (my $FILE2 = $file) =~ s/pending/parsing/;
        rename $file, $FILE2; 
        (my $FILE3 = $file) =~ s/pending/sent/;
        unlink $FILE3;
        flock FH, LOCK_UN;
        my $COMMAND = "$ENSEMBL_BLASTSCRIPT $blast_file $FILE2";
      ## NOW WE PARSE THE BLAST FILE.....
        `$COMMAND`;
        if( $ticket && ( $_process_blast_called_at + 30>time() )) {
          $loads = _get_loads();
          $FLAG = 1 if $count < 15;
        }
      #  warn "$ticket ",$_process_blast_called_at + 30,'>',time(), " $FLAG $count";
        last;
      }
      closedir(DH);
    }
  }
}

############################################
## Perl Apache translation handler 
##------------------------------------------
## REDIRECT species aliases to 'binomial' species name
##------------------------------------------
## Finds the translated filesystem path for URLs containing
##   a 'binomial' species.
## Use the SiteDefs ENSEMBL_PERL_DIR and ENSEMBL_HTDOCS_DIR
##  variables to add extra directories to the search path
##------------------------------------------
## Sets the two sub process environment variables:
##   ENSEMBL_SPECIES and ENSEMBL_SCRIPT
############################################

# Set the heirarchy of mod-perl dirs to search through
# %s will be replaced by species name
my @PERL_TRANS_DIRS;
foreach my $dir( @SiteDefs::ENSEMBL_PERL_DIRS ){
  if( -d $dir ){
    if( -r $dir ){ push( @PERL_TRANS_DIRS, 
                         "$dir/".$ENSEMBL_SITETYPE,
			 "$dir/%s",
			 "$dir/multi", # Hack multi dir coz species=Multi
			 "$dir/private",
			 "$dir/default" ) }
    else{ warn( "ENSEMBL_PERL_DIR $dir is not readable\n" ) }
  }
  else{ warn( "ENSEMBL_PERL_DIR $dir does not exist\n" ) }
}

# Set the heirarchy of htdocs content dirs to search through
# %s will be replaced by species name
my @HTDOCS_TRANS_DIRS;
foreach my $dir( @SiteDefs::ENSEMBL_HTDOCS_DIRS ){
  if( -d $dir ){
    if( -r $dir ){ push( @HTDOCS_TRANS_DIRS, "$dir/%s" ) }
    else{ warn( "ENSEMBL_HTDOCS_DIR $dir is not readable\n" ) }
  }
  else{ warn( "ENSEMBL_HTDOCS_DIR $dir does not exist\n" ) }
}

sub transHandler {
  my $r = shift;      # Get the connection handler
  my $u           = $r->parsed_uri;
  my $file        = $u->path;
  my $querystring = $u->query;

  my @path_segments = split( m|/|, $file );
  shift @path_segments; # Always empty
  my $species   = shift @path_segments;

  my $Tspecies = $species;
  my $script    = undef;
  my $path_info = undef;
  if( $species eq 'das' ) { # we have a DAS request...
    my $DSN = $path_segments[0];
    my $command = '';
    if( $DSN eq 'dsn' ) {
      $path_info = join ('/',@path_segments );
    } else {
      my( $das_species, $assembly, $type, $subtype ) = split /\./, $DSN;
      $command = $path_segments[1];
      my $FN = "/ensemblweb/wwwdev/server/perl/das/$command";
      $das_species = map_alias_to_species( $das_species );
      if( ! $das_species ) {
        $command = 'das_error';
        $r->subprocess_env->{'ENSEMBL_DAS_ERROR'} = 'unknown-species';
      }
      $r->subprocess_env->{'ENSEMBL_SPECIES' }     = $das_species;
      $r->subprocess_env->{'ENSEMBL_DAS_ASSEMBLY'} = $assembly;
      $r->subprocess_env->{'ENSEMBL_DAS_TYPE'}     = $type;
      $r->subprocess_env->{'ENSEMBL_DAS_SUBTYPE'}  = $subtype;
      $r->subprocess_env->{'ENSEMBL_SCRIPT'}  = $command;
      my $error_filename = '';
      foreach my $dir ( @PERL_TRANS_DIRS ) {
        my $filename = sprintf( $dir, $species )."/das/$command";
        my $t_error_filename = sprintf( $dir, $species )."/das/das_error";
        $error_filename ||= $t_error_filename if -r $t_error_filename;
        next unless -r $filename;
        $r->filename( $filename );
        $r->uri( "/perl/das/$DSN/$command" );
        return OK;
      }
      if( -r $error_filename ) {
        $r->subprocess_env->{'ENSEMBL_DAS_ERROR'}  = 'unknown-command';
        $r->filename( $error_filename );
        $r->uri( "/perl/das/$DSN/$command" );
        return OK;
      }
      return DECLINED;
    }
  } else {
  # DECLINE this request if we cant find a valid species
    if( $species && ($species = map_alias_to_species($species)) ) {
      $script = shift @path_segments;
      $path_info = join( '/', @path_segments );
      unshift ( @path_segments, '', $species, $script );
      my $newfile = join( '/', @path_segments );

      if( $newfile ne $file ){ # Path is changed; REDIRECT
        $r->uri( $newfile );
        $r->headers_out->add( 'Location' => join( '?', $newfile, $querystring || () ) );
        $r->child_terminate;
        return REDIRECT;
      }
      # Mess with the environment
      $r->subprocess_env->{'ENSEMBL_SPECIES'} = $species;
      $r->subprocess_env->{'ENSEMBL_SCRIPT'}  = $script;
      # Search the mod-perl dirs for a script to run
      foreach my $dir( @PERL_TRANS_DIRS ){
        $script || last;
        my $filename = sprintf( $dir, $species ) ."/$script";
        next unless -r $filename;
        $r->filename( $filename );
        $r->uri( "/perl/$species/$script" );
        $r->subprocess_env->{'PATH_INFO'} = "/$path_info" if $path_info;
        warn sprintf( "SCRIPT:%-10d /%s/%s?%s\n", $$, $species, $script, $querystring ) if $ENSEMBL_DEBUG_FLAGS | 8 && ($script ne 'ladist' && $script ne 'la' );
        return OK;
      }
    } else {
      $species = $Tspecies;
      $script = join( '/', @path_segments );
    }
  }
  # Search the htdocs dirs for a file to return
  my $path = join( "/", $species || (), $script || (), $path_info || () );
  $r->uri( "/$path" );
  foreach my $dir( @HTDOCS_TRANS_DIRS ){
    my $filename = sprintf( $dir, $path );
    if( -d $filename ) {
      $r->uri( $r->uri . ($r->uri =~ /\/$/ ? '' : '/' ). 'index.html' );
      $r->filename( $filename . ( $r->filename =~ /\/$/ ? '' : '/' ). 'index.html' );
      $r->headers_out->add( 'Location' => $r->uri );
      $r->child_terminate;
      return REDIRECT;
    }
    -r $filename or next;
    $r->filename( $filename );
    return OK;
  }

  # Give up
  return DECLINED;
}

#----------------------------------------------------------------------

=head2 map_alias_to_species

  Arg [0]   : string: species alias
  Function  : maps species aliases to configured species
  Returntype: string: configured species, empty string if unmapped
  Exceptions: 
  Caller    : transHandler
  Example   : $sp = map_alias_to_species('human') || return DECLINED

=cut

my %SPECIES_MAP = map { lc($_), $SiteDefs::ENSEMBL_SPECIES_ALIASES->{$_} }
                 keys %{$SiteDefs::ENSEMBL_SPECIES_ALIASES}; # Conf species
# $SPECIES_MAP{biomart} = 'biomart';                           # Multispecies
$SPECIES_MAP{common} = 'common';                           # Multispecies
$SPECIES_MAP{Common} = 'common';                           # Multispecies
$SPECIES_MAP{multi} = 'Multi';                           # Multispecies
$SPECIES_MAP{Multi} = 'Multi';                           # Multispecies
$SPECIES_MAP{BioMart} = 'biomart';                           # Multispecies
$SPECIES_MAP{biomart} = 'biomart';                           # Multispecies
$SPECIES_MAP{perl}  = $SiteDefs::ENSEMBL_PERL_SPECIES;   # Def species
map{ $SPECIES_MAP{lc($_)} = $_ } values( %SPECIES_MAP );     # Self-mapping

sub map_alias_to_species{
  my $species_alias = shift || ( warn( "Need a species alias" ) && return undef );
  return $SPECIES_MAP{lc($species_alias)} || '';
}

#----------------------------------------------------------------------
#
# EnsEMBL module for Apache::EnsEMBL::Handler
#
# Begat by James Smith <js5@sanger.ac.uk>
#

# POD documentation - main docs after the code

=head1 NAME

Apache::EnsEMBL::Handlers - Apache Mod_perl handler hooks module
to handle session tracking (and session_IDs), and to decide which
script to run 

=head1 SYNOPSIS

=head2 General

This mod_perl contains a number of apache handlers 

=over 4

=item *

PerlInitHandler - initHandler

Handles the initial stages of the session tracking, reading and
setting the session cooking and setting up the subprocess
environment variables C<ENSEMBL_FIRSTSESSION_ID> and C<ENSEMBL_SESSION_ID>

=item *

PerlTransHandler - transHandler

Handles the URL translation phase, to set the environment
variables C<ENSEMBL_SPECIES> and C<ENSEMBL_SCRIPT>  

=item *

PerlCleanupHandler - cleanupHandler

Handles the final stages of the session tracking, updating the
session stats, updating session length and exit pages.

=back  

=head2 initHandler 

=head2 transHandler 

=head2 cleanupHandler 

=head1 RELATED MODULES

See also: SiteDefs.pm Apache::EnsEMBL::DBSQL::UserDB.pm

=head1 FEED_BACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
EnsEMBL modules. Send your comments and suggestions to one of the
EnsEMBL mailing lists.  Your participation is much appreciated.

  http://www.ensembl.org/Dev/Lists - About the mailing lists

=head2 Reporting Bugs

Report bugs to the EnsEMBL bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via
email or the web:

  ensembl-dev@ebi.ac.uk

=head1 AUTHOR

James Smith 

Email - js5@sanger.ac.uk

=cut

