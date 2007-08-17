#!/usr/local/bin/perl 
use strict;
use warnings;
use Carp;
use Data::Dumper qw( Dumper );

package test_blast;

use IO::File;
use IO::Scalar;

use FindBin qw($Bin);
use Cwd;
use File::Basename;

use Pod::Usage;
use Getopt::Long;

# --- load libraries needed for reading config ---
BEGIN{
  my $serverroot = dirname( $Bin );
  unshift @INC, "$serverroot/conf";
  eval{ require SiteDefs };

  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

#use Bio::SeqIO;
#use Bio::SearchIO;
use Bio::Tools::Run::Search;
#use Bio::Seq::SeqFactory;
#use Bio::Tools::Run::EnsemblSearchMulti;
#use Bio::Search::Hit::GenericHit;
#use Bio::Search::HSP::EnsemblHSP;

#use Bio::Tools::Run::Search::wublastn;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::External::BlastAdaptor;

our $VERBOSITY = 1;

# Initialise ensembl-specific factories
our( $resfact, $hitfact, $hspfact );
FACTORIES:{
  use Bio::Search::Result::ResultFactory;
  use Bio::Search::Hit::HitFactory;
  use Bio::Search::HSP::HSPFactory;
  use Bio::Search::Result::EnsemblResult; #Test - Factories fail silently!
  use Bio::Search::Hit::EnsemblHit;       #Test - Factories fail silently!
  use Bio::Search::HSP::EnsemblHSP;       #Test - Factories fail silently!

  my $restype = 'Bio::Search::Result::EnsemblResult';
  my $hittype = 'Bio::Search::Hit::EnsemblHit';
  my $hsptype = 'Bio::Search::HSP::EnsemblHSP';
  
  $resfact = Bio::Search::Result::ResultFactory->new(-type=>$restype);
  $hitfact = Bio::Search::Hit::HitFactory->new(-type=>$hittype);
  $hspfact = Bio::Search::HSP::HSPFactory->new(-type=>$hsptype);
}

MAIN:{
  my $species       = '';
  my $database      = '';
  my $method        = '';
  my( $help, $man );
  my $configmode    = '';
  #my $executable    = '';
  my $ensembl_blast = '';
  my $ensembl_core  = '';
  my $cleanup = 1;

  my $opts = GetOptions
    ( "configmode=s"  => \$configmode,
      "species=s"     => \$species,
      "database=s"    => \$database,
      "method=s"      => \$method,
      #"executable=s"  => \$executable,
      "ensembl_blast_database=s" => \$ensembl_blast,
      "ensembl_core_database=s"  => \$ensembl_core,
      "verbosity=i"   => \$VERBOSITY,
      "cleanup=i"     => \$cleanup,
      "help"          => \$help,
      "info"          => \$man ) || pod2usage(2);

  pod2usage(-verbose => 2) if $man;
  pod2usage(1) if $help;
  
  my $seqfile = $ARGV[0] || pod2usage("$0: Need a sequence file" );

  if( ! -e $seqfile ){ pod2usage("$0: file $seqfile does not exist" ) }
  if( ! -f $seqfile ){ pod2usage("$0: file $seqfile is not a plain file" ) }
  if( ! -r $seqfile ){ pod2usage("$0: file $seqfile is not readable" ) }
  $configmode ||= 'ensembl';

  my @valid_configmodes = qw( ensembl search searchio );
  my %all_configmodes = map{$_,1} @valid_configmodes;
  $all_configmodes{$configmode} ||
    pod2usage("$0: configmode $configmode invalid. ".
	      "Use one of ".join(', ', @valid_configmodes).".");

  my( $search, $result );
  if( $configmode eq 'ensembl' ){ 
    $search = get_ensembl_search( $method, $database, $species );
  }
  elsif( $configmode eq 'search'  ){
    $search = get_search( $method, $database, $ensembl_blast, $ensembl_core );
  } 
  elsif( $configmode eq 'searchio' ){
    $result = parse_report( $method, $seqfile, $ensembl_core );
  }

  if( $search ){
    $result = run_search( $search, $seqfile );
    if( -e $search->errorfile ){  
      open( ERR, $search->errorfile );
      warning(0,<ERR>);
    }
  }
  if( $result ){
    &print_result_summary( $result );
  }

  if( $cleanup and $search ){
    $search->remove;
    if( -e $search->reportfile ){
      warning(0,"Reportfile ".$search->reportfile." not removed!");
    }
    if( -e $search->fastafile ){
      warning(0,"Fastafile ".$search->fastafile." not removed!");
    }
    if( -e $search->statefile ){
      warning(0,"Statefile ".$search->statefile." not removed!");
    }
    if( -e $search->errorfile ){
      warning(0,"Errorfile ".$search->errorfile." not removed!");
    }
  }
}

#----------------------------------------------------------------------
# Create and return a Bio::Tools::Run::Search object using the
# command-line args
sub get_search{
  my $method = shift || 
    pod2usage("$0: Need a --method arg to initialise ".
	      "Bio::Tools::Run::Search");
  my $database = shift ||
    pod2usage("$0: Need a --database arg to initialise ".
	      " Bio::Tools::Run::Search");
  my $ensembl_blast = shift;
  my $ensembl_core = shift;

  my $search = Bio::Tools::Run::Search->new( -method   => $method );

  # Configure search
  $search->_eventHandler->register_factory('result',$resfact);
  $search->_eventHandler->register_factory('hit', $hitfact );
  $search->_eventHandler->register_factory('hsp', $hspfact );
  $search->database( $database );
  $search->verbose( $VERBOSITY );

  if( $ensembl_blast ){
    my( $buser_info, $bhost_info ) = split( '@', $ensembl_blast, 2 );
    if( ! $bhost_info ){ $bhost_info = $buser_info; $buser_info = '' }
    my( $buser, $bpass )           = split( ':', $buser_info );
    my( $bhost, $bport, $bdbname ) = split( ':', $bhost_info );
    if( ! $bdbname ){ $bdbname=$bport; $bport = undef };
    $buser ||= getpwuid($>);
    $search->adaptor( Bio::EnsEMBL::External::BlastAdaptor->new
      ( -user=>$buser, -host=>$bhost, -dbname=>$bdbname, 
	$bpass ? (-pass=>$bpass) : (),
	$bport ? (-port=>$bport) : () ) );
  }
  else{warning(0,"No --ensembl_blast_database; storing results to tmpdir")}

  if( $ensembl_core ){
    my( $cuser_info, $chost_info ) = split( '@', $ensembl_core, 2 );
    if( ! $chost_info ){ $chost_info = $cuser_info; $cuser_info = '' }
    my( $cuser, $cpass )           = split( ':', $cuser_info );
    my( $chost, $cport, $cdbname ) = split( ':', $chost_info );
    if( ! $cdbname ){ $cdbname=$cport; $cport = undef };
    $cuser ||= getpwuid($>);
    $search->result->core_adaptor
      ( Bio::EnsEMBL::DBSQL::DBAdaptor->new
	( -user=>$cuser, -host=>$chost, -dbname=>$cdbname, 
	  $cpass ? (-pass=>$cpass) : (),
	  $cport ? (-port=>$cport) : () ) );
  }
  else{ warning( 0, 
		 "No --ensembl_core_database; Can't re-map alignments" ) }
  return $search;
}

#----------------------------------------------------------------------
# Create and return a Bio::Tools::Run::Search object using the Ensembl
# web configuration files.
sub get_ensembl_search{

  # --- load modules needed for reading config ---
  #tie *STDERR, __PACKAGE__;
  require EnsEMBL::Web::SpeciesDefs;
  require EnsEMBL::Web::BlastView::BlastDefs;
  require EnsEMBL::Web::DBSQL::DBConnection;
  my $species_defs = EnsEMBL::Web::SpeciesDefs->new;
  my $blast_defs   = EnsEMBL::Web::BlastView::BlastDefs->new;
  #untie *STDERR;

  $species_defs || die("[*DIE] SpeciesDefs config not found");
  $blast_defs   || die("[*DIE] BlastDefs config not found");
  # --- got modules ---

  my $me = shift;
  my $db = shift;
  my $sp = shift || $species_defs->PERL_DEFAULT_SPECIES;

  my $dbconnection = EnsEMBL::Web::DBSQL::DBConnection->new
      ( $sp, $species_defs );

  my( %env, %args );

  my %all_species   = map{$_=>1} $blast_defs->dice( -out=>'species' );
  my %all_methods   = map{$_=>1} $blast_defs->dice( -out=>'method' );
  my %all_databases = map{$_=>1} $blast_defs->dice( -out=>'database' );
  if( ! %all_species   ){ die("$0: No valid species in conf" ) };
  if( ! %all_methods   ){ die("$0: No valid methods in conf" ) };
  if( ! %all_databases ){ die("$0: No valid databases in conf" ) };

  $sp || die("[*DIE] species arg required; select from:\n".
			 join( "\n", sort keys %all_species ) );
  $me || die("[*DIE] method arg required; select from:\n".
			 join( "\n", sort keys %all_methods ) );
  $db || die("[*DIE] database arg required; select from:\n".
			 join( "\n", sort keys %all_databases ) );

  $all_species{$sp} ||
    die("[*DIE] species $sp not valid; select from:\n".
	      join( "\n", sort keys %all_species ) );

  $all_methods{$me} ||
    die("[*DIE] Method $me not valid; select from:\n".
	      join( "\n", sort keys %all_methods ) );

  $all_databases{$db} ||
    die("[*DIE] database $db not valid; select from:\n".
	      join( "\n", sort keys %all_databases ) );

  my $bd = $species_defs->get_config($sp,'ENSEMBL_BLAST_DATA_PATH');
  my $bx = $species_defs->get_config($sp,'ENSEMBL_BLAST_DATA_PATH_EXTRA');
  my $blastdb   = $bd . ( $bx ? "/$bx" : '' );
  my $blastmat = $species_defs->get_config($sp,'ENSEMBL_BLAST_MATRIX');
  my $blastflt = $species_defs->get_config($sp,'ENSEMBL_BLAST_FILTER');
  my $repeatm  = $species_defs->get_config($sp,'ENSEMBL_REPEATMASKER');

  $blastdb  and $env{BLASTDB}      = $blastdb;
  $blastmat and $env{BLASTMAT}     = $blastmat;
  $blastflt and $env{BLASTFILTER}  = $blastflt;
  $repeatm  and $env{REPEATMASKER} = $repeatm;

  my $bin  = $species_defs->get_config($sp,'ENSEMBL_BINARIES_PATH');
  my $bbin = $species_defs->get_config($sp,'ENSEMBL_BLAST_BIN_PATH');
  my @path = ( $ENV{PATH} );
  $bin  and unshift( @path, $bin );
  $bbin and unshift( @path, $bbin );
  @path and $env{PATH} = join( ':', @path );

  my $me_conf  = $species_defs->get_config($sp,'ENSEMBL_BLAST_METHODS');
  my $db_conf  = $species_defs->get_config($sp,"${me}_DATASOURCES");
  my $db_name  = $db_conf->{$db} || 
    pod2usage("$0: no database $db for species $sp and method $me");

  $args{-method}   = $me_conf->{$me};
  $args{-database} = $db_name;
  $args{-adaptor}  = $dbconnection->_get_blast_database;
  $args{-workdir}  = $species_defs->ENSEMBL_TMP_DIR_BLAST;

  my $search = Bio::Tools::Run::Search->new
    ( -method   => $me_conf->{$me},
      -database => $db_name,
      -adaptor  => $dbconnection->_get_blast_database,
      -workdir  => $species_defs->ENSEMBL_TMP_DIR_BLAST,
      -result_factory => $resfact,
      -hit_factory    => $hitfact,
      -hsp_factory    => $hspfact,
      -verbose        => $VERBOSITY );

  map{ $search->environment_variable($_, $env{$_} ) } keys %env;

  $search->result->core_adaptor
      ($dbconnection->_get_core_database($sp));

  return $search;
}

#----------------------------------------------------------------------
sub parse_report{
  my $method       = shift;
  my $reportfile   = shift;
  my $ensembl_core = shift;

  require Bio::SearchIO;
  my $sio = Bio::SearchIO->new( -format=>$method, 
				-file=>$reportfile );

  $sio->verbose( $VERBOSITY );
  $sio->_eventHandler->register_factory('result',$resfact);
  $sio->_eventHandler->register_factory('hit', $hitfact );
  $sio->_eventHandler->register_factory('hsp', $hspfact );

  my $result = $sio->next_result();
  if( $ensembl_core ){
    my( $cuser_info, $chost_info ) = split( '@', $ensembl_core, 2 );
    if( ! $chost_info ){ $chost_info = $cuser_info; $cuser_info = '' }
    my( $cuser, $cpass )           = split( ':', $cuser_info );
    my( $chost, $cport, $cdbname ) = split( ':', $chost_info );
    if( ! $cdbname ){ $cdbname=$cport; $cport = undef };
    $cuser ||= getpwuid($>);
    $result->core_adaptor( Bio::EnsEMBL::DBSQL::DBAdaptor->new
			   ( -user=>$cuser, -host=>$chost, -dbname=>$cdbname, 
			     $cpass ? (-pass=>$cpass) : (),
			     $cport ? (-port=>$cport) : () ) );
    $result->map_to_genome;  
  }
  else{ warning( 0, 
		 "No --ensembl_core_database; Can't re-map alignments" ) }
  return $result; 
}

#----------------------------------------------------------------------
sub run_search{
  my $search = shift;
  my $seqfile = shift;

  # Read the sequence file into bioperl, and attach to Search
  use Bio::SeqIO;
  my $seq_io = Bio::SeqIO->new( -file=>$seqfile );
  my $seq = $seq_io->next_seq;
  $search->seq($seq);

  # Print the command
  my $cmd;
  eval{ $cmd = $search->command() };
  if( $@ ){
    if( $@ =~ /MSG: (.+) at \// ){ $@ = $1 }
    warning( 0, $@ );
    exit 1;
  }
  info( 0, ( "Command: ".$cmd ) );

  # Run the search and await results
  my $token   = $search->store;
  my $adaptor = $search->adaptor;
  $search->run;
  info( 0, ( "Search Token: ".( $token || '-?-') ) );

  my $max_wait = 120;
  while( ( $search->status eq 'RUNNING' or
	   $search->status eq 'PENDING' ) and
	 $max_wait > 0 ){
    sleep( 10 );
    $search = Bio::Tools::Run::Search->retrieve( $token, $adaptor );
    $max_wait -= 10;
    info( 0, ( "Wait: " . ( 120 - $max_wait ) . "seconds" ) );
  }

  # Test storable
  $search->store;
  undef( $search );
  $search = Bio::Tools::Run::Search->retrieve( $token, $adaptor );

  # Print debug line
  info( 0, ( "Status:    ". ( $search->status || '-?-' ) ) );

  # Assign the result
  my $result = $search->result;
  return $result;
}

#----------------------------------------------------------------------
sub print_result_summary{
  my $result = shift;
  info( 0, ( "Res class: ".( ref( $result)   || '-?-') ) );
  info( 0, ( "Res token: ".( $result->token  || '-?-') ) ) 
    if $result->can('token');
  info( 0, ( "Hits:      ". $result->num_hits() ) ) ;
    
  while( my $hit = $result->next_hit ){
    info(0,"Hit class: ".( ref( $hit)   || '-?-') );
    info(0,"Hit name:  ".($hit->name    || '-?-') );
    info(0,"Num hsps:  ".$hit->num_hsps);

    while( my $hsp = $hit->next_hsp ){
      #info(0,"HSP class: ".( ref( $hsp)   || '-?-') );
      info(0, "HSP qry loc:   ". 
	   $hsp->query->seq_id .":".
	   $hsp->query->start  ."-".
	   $hsp->query->end    ."(". 
	   ( $hsp->query->strand > 0 ? '+' : '-' ).")" );
      info(0,"HSP hit loc:   ". 
	   $hsp->hit->seq_id.":".
	   $hsp->hit->start."-".
	   $hsp->hit->end."(". 
	   ( $hsp->hit->strand > 0 ? '+' : '-' ).")" );
      if( $hsp->contig_hit ){
        info(0,"HSP ctg loc:   ". 
             ( $hsp->contig_hit->seqname || '' ).":".
             ( $hsp->contig_hit->start   || '' )."-".
             ( $hsp->contig_hit->end     || '' )."(". 
             ( ($hsp->contig_hit->strand || 0) > 0 ? '+' : '-' ).")" );
      }
      else{
        info(0,"HSP ctg loc:   UNMAPPED");
      }
      if( $hsp->genomic_hit ){
        info(0,"HSP gnm loc:   ". 
             ( $hsp->genomic_hit->seqname || '' ) . ":" .
             ( $hsp->genomic_hit->start   || '' ) . "-" .
             ( $hsp->genomic_hit->end     || '' ) . "(" . 
             ( ($hsp->genomic_hit->strand || 0) > 0 ? '+' : '-' ) . ")" );
      }
      else{
	info(0,"HSP gnm loc:   UNMAPPED" );
      }
    }
  }
}

#----------------------------------------------------------------------
sub info{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  warn( "[INFO] ".$msg."\n" );
  return 1;
}

#----------------------------------------------------------------------
sub warning{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  warn( "[WARN] ".$msg."\n" );
  return 1;
}

#----------------------------------------------------------------------
# Quick+dirty method of trapping STDERR
sub TIEHANDLE{
  my $class = shift;
  bless {}, $class;
}
sub PRINT {
  my $self = shift;
  # Do nothing!;
}
#----------------------------------------------------------------------
=head1 NAME

test_blast_api.pm - Test the BlastView api

=head1 SYNOPSIS

test_blast_api.pm [options] [infile]

Options:
 --help
 --info
 --verbosity
 --cleanup
 --species
 --database
 --method
 --configmode
 --ensembl_blast_database
 --ensembl_core_database

=head1 OPTIONS

Script to test/demonstrate the Ensembl BlastView API. Use to: EITHER
search the sequences in [infile] against a specified database, and
parse the resulting report. OR parse the search report in [infile].

B<-h,--help>
  Print a brief help message and exits.

B<-i,--info>
  Print man page and exit

B<-v,--verbosity>
  Verbosity of output in range 0-3 (default 1)

B<--cleanup>
  Whether to remove all files and/or db entries on exit (default 1)

B<--configmode>
  If 'ensembl' (default), then the ensembl web config files are used.
  If 'search', testing Search subsystem only; web config is ignored.
  If 'searchio', testing SearchIO subsystem only; [infile] should be a
  search report.

B<-s,--species>
  For configmode 'ensembl'; identifies the <species>.ini config file.
  Ignored for other configmodes.

B<-m,--method>
  For configmode 'ensembl' - method 'confkey' (eg 'BLASTN').
  For configmode 'search'  - Bio::Tools::Run::Search -method (eg wublastn).
  For configmode 'searchio'- Bio::SearchIO -format (eg blast).

B<-d,--database>
  For configmode 'ensembl' - database 'confkey' (eg 'CDNA').
  For configmode 'search'  - method-specific db string (eg /tmp/cdna.fa).
  Ignored for other configmodes.

B<--ensembl_blast_database>
  For configmodes 'search' and 'searchio' - location of ensembl_blast
  database as user:pass@host:port:dbname.
  Ignored for other configmodes.

B<--ensembl_core_database>
  For configmodes 'search' and 'searchio' - location of ensembl core
  database as user:pass@host:port:dbname.
  Ignored for other configmodes.

=head1 DESCRIPTION

B<This program> 

Is a script to test/demonstrate the Ensembl BlastView API. Use to:
EITHER search the sequences in [infile] against a specified database,
and parse the resulting report. OR parse the search report in
[infile].

Maintained by Will Spooner <whs@sanger.ac.uk>

=cut

