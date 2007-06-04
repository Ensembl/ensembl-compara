package EnsEMBL::Web::Apache::Handlers;
# File Apache/EnsEMBL::Handlers.pm

use SiteDefs qw( :APACHE);
use strict;
use Apache2::Const qw(:common :http :methods);
use EnsEMBL::Web::DBSQL::BlastAdaptor;
use EnsEMBL::Web::Object::BlastJobMaster;
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::Registry;
use Apache2::SizeLimit;
use Apache2::URI ();
use APR::URI ();
use CGI::Cookie;
use Time::HiRes qw(time);
use Sys::Hostname;
use Data::Dumper;
use Fcntl ':flock';
use EnsEMBL::Web::RegObj;

use Exporter;

our $THIS_HOST;
our $LOG_INFO; 
our $LOG_TIME; 
our $BLAST_LAST_RUN;
our $BIOMART_REGISTRY;

#======================================================================#
# Set up apache-size-limit style load commands                         #
#======================================================================#

our $LOAD_COMMAND;
use Config;
BEGIN {
  $LOAD_COMMAND = $Config{'osname'} eq 'dec_osf' ? \&_load_command_alpha
                : $Config{'osname'} eq 'linux'   ? \&_load_command_linux
                :                                  \&_load_command_null  ;
};


#======================================================================#
# Setting up the directory lists for Perl/webpage                      #
#======================================================================#
# %s will be replaced by species name                                  #
#======================================================================#
our @PERL_TRANS_DIRS;
our @HTDOCS_TRANS_DIRS;
our %SPECIES_MAP;
BEGIN {
  foreach my $dir( @SiteDefs::ENSEMBL_PERL_DIRS ){
    if( -d $dir ) {
      if( -r $dir ){
#       push( @PERL_TRANS_DIRS, "$dir/$ENSEMBL_SITETYPE" ); ## We think this has been deprecated....
        push( @PERL_TRANS_DIRS, "$dir/%s"                );
        push( @PERL_TRANS_DIRS, "$dir/multi"             ) if -d "$dir/multi"   && -r "$dir/multi";
        push( @PERL_TRANS_DIRS, "$dir/private"           ) if -d "$dir/private" && -r "$dir/private";
        push( @PERL_TRANS_DIRS, "$dir/default"           ) if -d "$dir/default" && -r "$dir/default";
      } else {
        warn "ENSEMBL_PERL_DIR $dir is not readable\n";
      }
    } else{
      warn "ENSEMBL_PERL_DIR $dir does not exist\n";
    }
  }

  foreach my $dir( @SiteDefs::ENSEMBL_HTDOCS_DIRS ){
    if( -d $dir ) {
      if( -r $dir ) {
        push( @HTDOCS_TRANS_DIRS, "$dir/%s" );
      } else {
        warn "ENSEMBL_HTDOCS_DIR $dir is not readable\n";
      }
    } else {
      warn "ENSEMBL_HTDOCS_DIR $dir does not exist\n";
    }
  }

  %SPECIES_MAP = (
##      BioMart biomart  biomart biomart
    qw(
      common  common   Common  common
      Multi   Multi    multi   Multi
    ),
    ( 'perl' => $SiteDefs::ENSEMBL_PRIMARY_SPECIES ),
    map { lc($_) => $SiteDefs::ENSEMBL_SPECIES_ALIASES->{$_} } keys %{$SiteDefs::ENSEMBL_SPECIES_ALIASES}
  );

  foreach( values %SPECIES_MAP ) {
    $SPECIES_MAP{lc($_)} = $_;
  }     # Self-mapping
};

1;

#======================================================================#
# Perl apache handlers.... in order they get executed!                 #
#======================================================================#

sub childInitHandler {
### Child Init Handler
### Sets up the web registry object - and initializes the timer!

  my $r = shift;
  my $temp_hostname = hostname();
  my $temp_proc_id  = "".reverse $$;
  my $temp_seed     = ( $temp_proc_id + $temp_proc_id<<15 ) & 0xffffffff;
  while( $temp_hostname=~s/(.{1,4})// ) {
    $temp_seed = $temp_seed ^ unpack( "%32L*", $1 );
  }
  srand( time() ^ $temp_seed );

  $THIS_HOST = `hostname`;

## Create the Registry...
  $ENSEMBL_WEB_REGISTRY = EnsEMBL::Web::Registry->new();
  $ENSEMBL_WEB_REGISTRY->timer->set_process_child_count( 0    );
  $ENSEMBL_WEB_REGISTRY->timer->set_process_start_time(  time );
#  $ENSEMBL_WEB_REGISTRY->memcache;
  if( $ENSEMBL_DEBUG_FLAGS & 8 ){
    printf STDERR "Child %9d: - initialised at %30s\n", $$,''.gmtime();
  }
#  use BioMart::Initializer;
#  my $MART_CONFFILE = "${SiteDefs::ENSEMBL_SERVERROOT}/conf/martRegistry.xml";
#  eval {
#    my $init = BioMart::Initializer->new( registryFile => $MART_CONFFILE );
#    $main::BIOMART_REGISTRY = $init->getRegistry() || die "Can't get registry from initializer";
#    warn $main::BIOMART_REGISTRY;
#  }

}

sub postReadRequestHandler {
  my $r = shift; # Get the connection handler
## Manipulate the Registry...
  $ENSEMBL_WEB_REGISTRY->timer->set_script_start_time( time  ); ## This is the page rendering start time!
#  $r->push_handlers( PerlTransHandler =>   \&transHandler );
#warn "         $$ PTH....";
#  $r->push_handlers( PerlCleanupHandler => \&cleanupHandler );
#warn "         $$ PCH....";
## Retrieve the firstsession_ID and User ID from the cookie (ENSEMBL_FIRSTSESSION and ENSEMBL_USER_ID)
##   Setup User...
##  $ENSEMBL_WEB_REGISTRY->initialize_session( $session_cookie ); ## Initialize the session information
  my $user_cookie = EnsEMBL::Web::Cookie->new({
    'host'    => $ENSEMBL_COOKIEHOST,
    'name'    => $ENSEMBL_USER_COOKIE,
    'value'   => '',
    'env'     => 'ENSEMBL_USER_ID',
    'hash'    => {
      'offset'  => $ENSEMBL_ENCRYPT_0,
      'key1'    => $ENSEMBL_ENCRYPT_1,
      'key2'    => $ENSEMBL_ENCRYPT_2,
      'key3'    => $ENSEMBL_ENCRYPT_3,
      'expiry'  => $ENSEMBL_ENCRYPT_EXPIRY,
      'refresh' => $ENSEMBL_ENCRYPT_REFRESH
    }
  });
  $ENSEMBL_WEB_REGISTRY->initialize_user({
    'cookie'=> $user_cookie,
    'r'     => $r
  }); ## Initialize the user (and possibly group) objects
## Unlikely to go to db - just store the IDs
  return;
}

sub headerParserHandler {
  my $r = shift;
}

sub transHandler {
  my $r = shift;      # Get the connection handler
  my $u           = $r->parsed_uri;
  my $file        = $u->path;
  my $querystring = $u->query;

  my $session_cookie = EnsEMBL::Web::Cookie->new({
    'host'    => $ENSEMBL_COOKIEHOST,
    'name'    => $ENSEMBL_FIRSTSESSION_COOKIE,
    'value'   => '',
    'env'     => 'ENSEMBL_FIRSTSESSION_ID',
    'hash'    => {
      'offset'  => $ENSEMBL_ENCRYPT_0,
      'key1'    => $ENSEMBL_ENCRYPT_1,
      'key2'    => $ENSEMBL_ENCRYPT_2,
      'key3'    => $ENSEMBL_ENCRYPT_3,
      'expiry'  => $ENSEMBL_ENCRYPT_EXPIRY,
      'refresh' => $ENSEMBL_ENCRYPT_REFRESH
    }
  });
  my @path_segments = split( m|/|, $file );
  shift @path_segments; # Always empty
  my $species   = shift @path_segments;

  my $Tspecies = $species;
  my $script    = undef;
  my $path_info = undef;

#  my $F = $ENSEMBL_WEB_REGISTRY->get_memcache->get( "STATIC:$file" );
#  if( $F ) {
#    $r->filename( $F );
#    return OK;
#  }
  if( $species eq 'das' ) { # we have a DAS request...
    my $DSN = $path_segments[0];
    my $command = '';
    if( $path_segments[1] eq 'entry_points' && -e $SiteDefs::ENSEMBL_SERVERROOT."/htdocs/das/$DSN/entry_points" ||
        $DSN eq 'dsn' ) {
## Fall through this is a static page!!
      $path_info = join ('/',@path_segments );
    } else {
# Because assemblies might contain dots themselves - we split DSN on dots
# the first element will be species, the last - source name, and all the field in the middle are the assembly
      my @dsn_fields = split /\./, $DSN;
      my $das_species = shift @dsn_fields;
      my $type = pop @dsn_fields;
      my $assembly = join ('.', @dsn_fields);
      my $subtype;
      ( $type, $subtype ) = split /-/,$type,2;

      $command = $path_segments[1];
      my $FN = $SiteDefs::ENSEMBL_SERVERROOT."/perl/das/$command";
      $das_species = $SPECIES_MAP{lc($das_species)} || '';
      if( ! $das_species ) {
        $command = 'das_error';
        $r->subprocess_env->{'ENSEMBL_DAS_ERROR'} = 'unknown-species';
      }
      $ENSEMBL_WEB_REGISTRY->initialize_session({ 'r' => $r, 'cookie'  => $session_cookie, 'species' => $das_species, 'script'  => $command });
      $r->subprocess_env->{'ENSEMBL_SPECIES'     } = $das_species;
      $r->subprocess_env->{'ENSEMBL_DAS_ASSEMBLY'} = $assembly;
      $r->subprocess_env->{'ENSEMBL_DAS_TYPE'    } = $type;
      $r->subprocess_env->{'ENSEMBL_DAS_SUBTYPE' } = $subtype;
      $r->subprocess_env->{'ENSEMBL_SCRIPT'      } = $command;
      my $error_filename = '';
      foreach my $dir ( @PERL_TRANS_DIRS ) {
        my $filename = sprintf( $dir, $species )."/das/$command";
        my $t_error_filename = sprintf( $dir, $species )."/das/das_error";
        $error_filename ||= $t_error_filename if -r $t_error_filename;
        next unless -r $filename;
        $r->filename( $filename );
        $r->uri( "/perl/das/$DSN/$command" );
        if( $ENSEMBL_DEBUG_FLAGS & 8 ) {
          my @X = localtime();
          $LOG_INFO = sprintf( "SCRIPT:%8s:%-10d %04d-%02d-%02d %02d:%02d:%02d /%s/%s?%s\n",
            substr($THIS_HOST,0,8), $$, $X[5]+1900, $X[4]+1, $X[3], $X[2],$X[1],$X[0],
            'das', "$DSN/$command", $querystring );
          warn $LOG_INFO;
          $LOG_TIME = time();
          $r->push_handlers( PerlCleanupHandler => \&cleanupHandler_script      );
#warn "PUSHING BLASTSCRIPTXX.... $ENSEMBL_BLASTSCRIPT";
#          $r->push_handlers( PerlCleanupHandler => \&cleanupHandler_blast       ) if $ENSEMBL_BLASTSCRIPT;
          $r->push_handlers( PerlCleanupHandler => \&Apache2::SizeLimit::handler );
        }
        return OK;
      }
      if( -r $error_filename ) {
        $r->subprocess_env->{'ENSEMBL_DAS_ERROR'}  = 'unknown-command';
        $r->filename( $error_filename );
        $r->uri( "/perl/das/$DSN/$command" );
        if( $ENSEMBL_DEBUG_FLAGS & 8 ) {
          my @X = localtime();
          $LOG_INFO = sprintf( "SCRIPT:%8s:%-10d %04d-%02d-%02d %02d:%02d:%02d /%s/%s?%s\n",
            substr($THIS_HOST,0,8), $$, $X[5]+1900, $X[4]+1, $X[3], $X[2],$X[1],$X[0],
            'das', "$DSN/$command", $querystring );
          warn $LOG_INFO;
          $LOG_TIME = time();
          $r->push_handlers( PerlCleanupHandler => \&cleanupHandler_script      );
#warn "PUSHING BLASTSCRIPTYY.... $ENSEMBL_BLASTSCRIPT";
#          $r->push_handlers( PerlCleanupHandler => \&cleanupHandler_blast       ) if $ENSEMBL_BLASTSCRIPT;
          $r->push_handlers( PerlCleanupHandler => \&Apache2::SizeLimit::handler );
        }
        return OK;
      }
      return DECLINED;
    }
  } else {
  # DECLINE this request if we cant find a valid species
    if( $species && ($species = $SPECIES_MAP{lc($species)} || '' ) ) {
      $script = shift @path_segments;
      $path_info = join( '/', @path_segments );
      unshift ( @path_segments, '', $species, $script );
      my $newfile = join( '/', @path_segments );

      if( $newfile ne $file ){ # Path is changed; HTTP_TEMPORARY_REDIRECT
        $r->uri( $newfile );
        $r->headers_out->add( 'Location' => join( '?', $newfile, $querystring || () ) );
        $r->child_terminate;
        return HTTP_TEMPORARY_REDIRECT;
      }
      # Mess with the environment
      $r->subprocess_env->{'ENSEMBL_SPECIES'} = $species;
      $r->subprocess_env->{'ENSEMBL_SCRIPT'}  = $script;
      $ENSEMBL_WEB_REGISTRY->initialize_session({ 'r' => $r, 'cookie'  => $session_cookie, 'species' => $species, 'script'  => $script });
      # Search the mod-perl dirs for a script to run
      foreach my $dir( @PERL_TRANS_DIRS ){
        $script || last;
        my $filename = sprintf( $dir, $species ) ."/$script";
        next unless -r $filename;
        $r->filename( $filename );
        $r->uri( "/perl/$species/$script" );
        $r->subprocess_env->{'PATH_INFO'} = "/$path_info" if $path_info;
        if( $ENSEMBL_DEBUG_FLAGS & 8 && $script ne 'ladist' && $script ne 'la' ) {
          my @X = localtime();
          $LOG_INFO = sprintf( "SCRIPT:%8s:%-10d %04d-%02d-%02d %02d:%02d:%02d /%s/%s?%s\n",
           substr($THIS_HOST,0,8), $$, $X[5]+1900, $X[4]+1, $X[3], $X[2],$X[1],$X[0],
           $species, $script, $querystring ) if $ENSEMBL_DEBUG_FLAGS | 8 && ($script ne 'ladist' && $script ne 'la' );
          warn $LOG_INFO;
          $LOG_TIME = time();
	  }
		$r->push_handlers( PerlCleanupHandler => \&cleanupHandler_script      );
#warn "PUSHING BLASTSCRIPTZZ.... $$ - $ENSEMBL_BLASTSCRIPT";
#if( $ENSEMBL_BLASTSCRIPT ) {
#          $r->push_handlers( PerlCleanupHandler => \&cleanupHandler_blast       );
#  warn "YARG $$ ....";
#}
          $r->push_handlers( PerlCleanupHandler => \&Apache2::SizeLimit::handler );
 #       }
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
#        $script || last;
    my $filename = sprintf( $dir, $path );
    if( -d $filename ) {
      $r->uri( $r->uri . ($r->uri =~ /\/$/ ? '' : '/' ). 'index.html' );
      $r->filename( $filename . ( $r->filename =~ /\/$/ ? '' : '/' ). 'index.html' );
      $r->headers_out->add( 'Location' => $r->uri );
      $r->child_terminate;
      return HTTP_TEMPORARY_REDIRECT;
    }
    next unless -r $filename;
    $r->filename( $filename );
#    $ENSEMBL_WEB_REGISTRY->get_memcache->set( "STATIC:$file", $filename ); 
    return OK;
  }

  # Give up
  return DECLINED;
}

sub logHandler {
  my $r = shift;
  $r->subprocess_env->{'ENSEMBL_SCRIPT_TIME'} = sprintf( "%0.6f", time() - $ENSEMBL_WEB_REGISTRY->timer->get_script_start_time );
  return DECLINED;
}
sub cleanupHandler {
  my $r = shift;      # Get the connection handler

#warn "STANDARD CLEAN UP HANDLER $$";

  return  if $r->subprocess_env->{'ENSEMBL_ENDTIME'};
  my $end_time    = time();
  my $start_time  = $ENSEMBL_WEB_REGISTRY->timer->get_script_start_time;
  my $length      = $end_time- $start_time;

  if( $length >= $ENSEMBL_LONGPROCESS_MINTIME ) {
    my $u           = $r->parsed_uri;
    my $file        = $u->path;
    my $query       = $u->query.$r->subprocess_env->{'ENSEMBL_REQUEST'};
    my $size        = &$Apache2::SizeLimit::HOW_BIG_IS_IT();
    $r->subprocess_env->{'ENSEMBL_ENDTIME'} = $end_time;
    if( $ENSEMBL_DEBUG_FLAGS & 8 ) {
      print STDERR sprintf "LONG PROCESS %10s DT: %24s Time: %10s Size: %10s
LONG PROCESS %10s REQ: %s
LONG PROCESS %10s IP:  %s  UA: %s
", $$,  scalar(gmtime($start_time)), $length, $size, $$, "$file?$query", $$, $r->subprocess_env->{'HTTP_X_FORWARDED_FOR'}, $r->headers_in->{'User-Agent'};
    }
  }

                 ##----------------------------------------------------------------------
                 ## Blast now has it's own clean up handler!!!!
                 ##
                 ## Now we do the BLAST parser stuff!!
                 ##  _process_blast( $r ) if $ENV{'ENSEMBL_SCRIPT'} && $ENSEMBL_BLASTSCRIPT;
                 ##
                 ##  if ($ENV{'ENSEMBL_SCRIPT'} && $ENSEMBL_BLASTSCRIPT) {
                 ##    #&queue_pending_blast_jobs;
                 ##  }
                 ##----------------------------------------------------------------------

## Now we check if the die file has been touched...
  my $die_file = $ENSEMBL_SERVERROOT.'/logs/ensembl.die';
  if( -e $die_file ) {
    my @temp = stat $die_file;
    my $file_mod_time = $temp[9];
    if( $file_mod_time >= $ENSEMBL_WEB_REGISTRY->timer->get_process_start_time ) {
      print STDERR sprintf "KILLING CHILD %10s\n", $$;
      if( $Apache2::SizeLimit::WIN32 ) {
        CORE::exit(-2);
      } else {
        $r->child_terminate();
      }
    }
    return DECLINED;
  }
}

sub cleanupHandler_script {
  my $r = shift;
  my @X = localtime();
#  warn "SCRIPT CLEANUP HANDLER $$";
  my ($A,$B) = $LOG_INFO =~ /SCRIPT:(.{8}:\d+) +\d{4}-\d\d-\d\d \d\d:\d\d:\d\d (.*)$/;
  warn sprintf( "ENDSCR:%-19s %04d-%02d-%02d %02d:%02d:%02d %10.3f %s\n",
    $A, $X[5]+1900, $X[4]+1, $X[3], $X[2],$X[1],$X[0], time()-$LOG_TIME, $B );
  if( $ENSEMBL_BLASTSCRIPT ) {
    cleanupHandler_blast( $r );
  }
}

sub childExitHandler {
  my $r = shift;
  $ENSEMBL_WEB_REGISTRY->tidy_up if $ENSEMBL_WEB_REGISTRY; ## Disconnect from the DB
  if( $ENSEMBL_DEBUG_FLAGS & 8 ){
    printf STDERR "Child %9d: - reaped at      %30s;  Time: %11.6f;  Req:  %4d;  Size: %8dK\n",
      $$, ''.gmtime(), time-$ENSEMBL_WEB_REGISTRY->timer->get_process_start_time,
      $ENSEMBL_WEB_REGISTRY->timer->get_process_child_count,
      &$Apache2::SizeLimit::HOW_BIG_IS_IT()
  }
}

#======================================================================#
# BLAST Support functionality.                                         #
#======================================================================#

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

sub  _load_command_null {
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

sub cleanupHandler_blast {
  my $r = shift;
# warn "BLAST CLEANUP HANDLER... $$";
  my $directory = $ENSEMBL_TMP_DIR_BLAST.'/pending';
  my $FLAG = 0;
  my $count=0;
  my $ticket;
  my $_process_blast_called_at = time();

#  warn "Processing BLAST in Apache: $r";

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
#  warn "$FLAG";
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
warn "BLAST: $COMMAND";
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

