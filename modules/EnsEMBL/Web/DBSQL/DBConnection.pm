package EnsEMBL::Web::DBSQL::DBConnection;

=head1 NAME

EnsEMBL::Web::DBSQL::DBConnection.pm 

=head1 SYNOPSIS

Module to initiate and store database connections for web api

=head1 DESCRIPTION

 my $dbs            = EnsEMBL::Web::DBSQL::DBConnection->new( 'Homo_sapiens' );
 my $core_DBAdaptor = $dbs->get_DBAdaptor('core');
 
 Creates a database object with a default species (current species) set to the
 string passed or to the ENSEMBL_SPECIES environment vaiable if this is
 omitted. Database connections are initiated and stored on the object using
 the 'get_DBAdaptor' call. New databases can be added to the object with
 different species specified.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Brian Gibbins - bg2@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings "uninitialized";
use DBI;
use Carp;

use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use EnsEMBL::Web::Problem;
use Bio::EnsEMBL::Registry;
use EnsEMBL::Web::RegObj;
my $reg = "Bio::EnsEMBL::Registry";

sub new {
  my( $class, $species, $species_defs ) = @_;
  my $self = bless {
    '_default_species'  => $species,
    'species_defs'      => $species_defs,
    '_dbs'              => {}
  }, $class; 
  return $self;
}

=head2 get_DBAdaptor
 
 Arg[1]      : String 
               The database type required (core, vega, est)
 
 Arg[2]      : String 
               OPTIONAL -  Species for the database (or current 'default'
               species if omitted)
 
 Example     : $dbconnection->get_DBAdaptor('core', 'Homo_sapiens')
 Description : gets and sets the specified database for the specified (or
               default) species 
 Return type : The database conection requested

=cut

sub get_DBAdaptor {
  my $self = shift;
  my $database = shift || $self->error( 'FATAL', "Need a DBAdaptor name" );
     $database = "SNP" if $database eq "snp";
     $database = "otherfeatures" if $database eq "est";
  my $species = shift || $self->default_species();
  $self->{'_dbs'}->{$species} ||= {}; 

  # if we have connected to the db before, return the adaptor from the cache
  if(exists($self->{'_dbs'}->{$species}->{$database})){
    return $self->{'_dbs'}->{$species}->{$database};
  }
    
  # try to retrieve the DBAdaptor from the Registry
  my $dba = $reg->get_DBAdaptor($species, $database);
  # warn "$species - $database - $dba";

  # Glovar
  $self->{'_dbs'}->{$species}->{$database} = $dba;

  if (!exists($self->{'_dbs'}->{$species}->{$database})) {
    return undef;
  }
  return $self->{'_dbs'}->{$species}->{$database};
}

=head2 get_databases

 Arg[1]      : String - The databases required (core, vega, est)
 
 Example     : $dbconn->get_databases('core', 'est');
 Description : A wrapper that returns a list of databases for the current
               (default) species 
 Return type : Hashref - The database connections requested

=cut

sub get_databases {
  my $self = shift;
  return $self->get_databases_species($ENV{'ENSEMBL_SPECIES'}, @_);
}

=head2 get_databases_species

 Arg[1]      : String - The species for the database
 Arg[2]      : String - The databases required (core, vega, est)
 Example     : $dbconn->get_databases_species('Homo_sapiens', 'core', 'est');
 Description : A Wrapper that returns a list of databases for the specified
               species 
 Return type : Hashref - The database connections requested

=cut

sub get_databases_species {
  my $self = shift;
  my $species = shift || die( "Need a species!" );
  my @databases =  @_;

  for my $database (@databases){
    unless( defined($self->{'_dbs'}->{$species}->{$database}) ) {
      my $dba = $reg->get_DBAdaptor( $species, $database );
      if (!defined($dba) || $database eq 'glovar'){
        $self->_get_databases_common( $species, $database );
      } else{
        $self->{'_dbs'}->{$species}->{$database} = $dba;
      }
    }
  }

  return $self->{'_dbs'}->{$species};
}

=head2 _get_databases_common

 Arg[1]      : String - The species for the database
 Arg[2]      : String - The databases required (core, vega, est)
 Example     : $dbconn->_get_databases_common('Homo_sapiens', 'core', 'est');
 
    Examples of the parameters:
        'core'       = core ensemble datbase 
        'SNP'        = SNP database 
        'compara'    = Compara db
        'disease'     = disease database
        'family'     = family database
        
    Examples of the result Hash ref that are stored
        'error'     = Error message if fails to connect to core databases
        'SNP','disease',etc. = Handles to respective databases 
        'non_fatal_error' = Error message if fails to connect to any ancillary
          database

 Description : Internal call that gets the database connections 
 Return type : Hashref - The database connections requested 

=cut

sub _get_databases_common {
  my $self = shift;
  my $species = shift || die( "Need a species" );
  ($species) = $self->{'species_defs'}->valid_species($species);

  die "Invalid species: $species"
    unless $species;
    
  $self->{'non_fatal_error'} =  '' ;
  my $default_species_db = $self->{'_dbs'}->{$species} ;
  my %databases = map {($_,1)} @_;

  # find out if core is an annotation DB (like in Vega)
  my $is_annot_db = $self->{'species_defs'}->get_table_size(
    { -db =>'DATABASE_CORE', -table => 'gene_remark'}
  ); 
    ## Get core DB first
  if( $databases{'core'} ) {
    eval{ $default_species_db->{'core'} =  $self->_get_core_database($species); };
    if( $@ ){
      $self->{'error'} = qq(Unable to connect to the database: $@);
      return $self;
    }
    delete $databases{'core'};
  }
    
    ## Simple DBs; no dependence on core  
  my @simple_dbs = grep { $databases{$_} } qw(go fasta help);
  foreach (@simple_dbs) {
    my $getter = "_get_" . lc($_) . "_database";
    my $dbadaptor;
    eval{ $dbadaptor = $self->$getter($species) };
    if ($@) { 
      $self->{'error'} .= "\n$_ database: $@";
      print STDERR $self->{'error'} ."\n\n";
    }
    $default_species_db->{$_} = $dbadaptor;
    delete $databases{$_};
  }
  
  ## More complex databases
  # Attach to core (if available)
  my @attached_to_core = grep { $databases{$_} } qw(SNP blast);
  foreach (@attached_to_core) {
    my $getter = "_get_" . lc($_) . "_database";
    eval{ $default_species_db->{$_} = $self->$getter($species); };
    if( $@ ) { 
      $default_species_db->{$_}->{'error'} .= "\n$_ database: $@";
    } elsif (my $core_db = $default_species_db->{'core'}) {
      $core_db->add_db_adaptor($_, $default_species_db->{$_});
    }
    delete $databases{$_};
  }

  ## Other DBs
  # cdna
  foreach (qw(cdna vega otherfeatures)) {
    if($databases{$_}) {
      $self->_get_db_with_dnadb( $_, $species);
      delete $databases{ $_ };
    }
  }
  # compara
  if( $databases{'compara'} ) {
    eval{ $default_species_db->{'compara'} =  $self->_get_compara_database($species); };
    if( $@ ){ 
      $self->{'error'} .= "\ncompara database: $@";
    } elsif ( my $core_db = $default_species_db->{core}) {
      my $comp_db = $default_species_db->{compara};
         $core_db->add_db_adaptor( 'compara', $comp_db );
      delete $databases{'compara'};
    } 
  }
  # Check all requested db's exist
  if( %databases ) {
    $default_species_db->{'error'} = "You have specified unknown database(s): ".(join ", ",keys %databases);
  }
  return $default_species_db;
}

=head2 _get_core_database

 Arg[1]      : String  
               Species name
 
 Example     : $self->_get_core_database( $species )
 Description : Gets the core database connection
 Return type : Bio::EnsEMBL::DBLoader

=cut

sub _get_core_database{
  my $self = shift;
  my $db_info =  $self->_get_database_info( shift, 'DATABASE_CORE' ) ||
    confess( "No core database for this species" );
  return  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );
}

=head2 _get_db_with_dnadb

 Arg[1]      : String  
               Database name
 Arg[2]      : String  
               Species name
 
 Example     : $self->_get_db_with_dnadb( $db, $species )
 Description : Gets a database connection with core as dnadb
 Return type : none

=cut

sub _get_db_with_dnadb {
  my $self = shift;
  my $db = shift || die("No database given");
  warn "..... $db ........";
  my $species = shift || die("No species given");
  #warn "_GET_DB_WIDTH_DNADB -> $db -> $species";
  my $getter = "_get_" . lc($db) . "_database";
  my $default_species_db = $self->{'_dbs'}->{$species};
  eval{ $default_species_db->{$db} = $self->$getter($species); };
  if( $@ ){ 
    $default_species_db->{$db} = 0;
    $self->{'non_fatal_error'} .= "\n$db database: $@";
    return;
  }
  eval{ $default_species_db->{'core'} ||= $self->_get_core_database($species); };
  if( $@ ){
    $self->{'error'} = qq(Unable to connect to the Core database: $@);
  } else { 
    warn "$db attached to core $default_species_db->{$db}";
    $default_species_db->{$db}->dnadb( $default_species_db->{'core'} );
    $default_species_db->{'core'}->add_db_adaptor($db, $default_species_db->{$db} );
    $default_species_db->{$db}->add_db_adaptor('core', $default_species_db->{'core'} );
  }
}

sub _get_fasta_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'DATABASE_FASTA' ) ||
        die( "No fasta database for this species" );
    my $adpt =  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );
    $self->dynamic_use('Bio::EnsEMBL::ExternalData::FASTA::FASTAAdaptor');
    return Bio::EnsEMBL::ExternalData::FASTA::FASTAAdaptor->new($adpt);
}

=head2 _get_userupload_database

 Arg[1]      : String  
                Species name
 
 Example     : $self->_get_userupload_database($species)
 Description : Gets est database connection
 Return type : Bio::EnsEMBL::DBSQL::DBAdaptor

=cut

sub _get_userdata_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'DATABASE_USERDATA' ) ||
        die( "No est database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' ); 
}

=head2 _get_compara_database

 Arg[1]      : none
 
 Example     : $self->_get_compara_database
 Description : Gets compara database connection
 Return type : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

=cut

sub _get_compara_database{
  my $self = shift;
  my $dba =  $reg->get_DBAdaptor('Multi','compara');
  if(defined($dba)){
    return $dba;
  }
  my $db_info = $self->{'species_defs'}->multidb->{DATABASE_COMPARA} ||
     die( "No compara database for this species" );
  return  $self->_get_database( $db_info, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor' );
}

=head2 _get_go_database

 Arg[1]      : none
 
 Example     : $self->_get_go_database
 Description : Gets go database connection
 Return type : Bio::EnsEMBL::ExternalData::GO::GOAdaptor

=cut

sub _get_help_database{
  my $self = shift;
  my $db_info = $self->{'species_defs'}->multidb->{DATABASE_WEBSITE} ||
     die( "No go database for this species" );
  return  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );
}

sub _get_go_database{
  my $self = shift;
  my $db_info = $self->{'species_defs'}->multidb->{DATABASE_GO} ||
     die( "No go database for this species" );
  return  $self->_get_database( $db_info, 'Bio::EnsEMBL::ExternalData::GO::GOAdaptor' );
}

=head2 _get_blast_database

 Arg[1]      : none
 
 Example     : $self->_get_blast_database
 Description : Gets blast database connection
 Return type : Bio::EnsEMBL::External::BlastAdaptor

=cut

sub _get_blast_database{
  my $self = shift;
  my $db_info = $self->{'species_defs'}->multidb->{DATABASE_BLAST} ||
     die( "No blast database in MULTI" );
  return  $self->_get_database( $db_info, 'Bio::EnsEMBL::External::BlastAdaptor' );
}

=head2 _get_database_info

 Arg[1]      : String
                A species name
                
 Arg[2]      : String
                Configuration key 
 
 Example     : $self->_get_database_info('Homo_sapiens', 'ENSEMBL_CORE')
 Description : Gets the database connection info from ini files
 Return type : HASH
                Database connection info for the required database

=cut

sub _get_database_info{
  my $self = shift;
  my $species  = shift || $ENV{ENSEMBL_SPECIES};
  my $conf_key = shift || die( "Need a DB conf key" );
  my $conf = $self->{'species_defs'}->get_config( $species, 'databases' ) || return undef();
  return $conf->{$conf_key} || undef();
}

=head2 _get_database

 Arg[1]      : Hash 
                From '_get_database_info' method
                
 Arg[2]      : String
                Adaptor type
 
 Example     : $self->_get_database( $db_info, 'Bio::EnsEMBL::External::BlastAdaptor' );
 Description : Creates the database adaptor for the adaptor type passed in ARG[2]
 Return type : A new database adaptor with connection information

=cut

sub _get_database{
  my $self = shift;
  my $db_info = shift || die( "Need DB info" );
  my $a_class = shift || die( "Need an adaptor class" );
  $self->dynamic_use( $a_class );
  return $a_class->new(
    -dbname => $db_info->{NAME},
    -user   => $db_info->{USER},
    -pass   => $db_info->{PASS},
    -host   => $db_info->{HOST},
    -port   => $db_info->{PORT},
    -driver => $db_info->{DRIVER},
  );
}

sub proxy {
  my $self = shift;
  my $URL = shift;
  my $PROXY = 1;
  return 0 unless $URL=~/^https?:\/\/([^:\/]+)/;
  return 0 unless defined $self->{'species_defs'}->ENSEMBL_WWW_PROXY;
  return 1 unless defined $self->{'species_defs'}->ENSEMBL_NO_PROXY;
# return 1;
  my $DOMAIN = $1 ;
  foreach my $suffix ( @{$self->{'species_defs'}->ENSEMBL_NO_PROXY||[]} ) {
    my $suf2 = '.*'.quotemeta($suffix).'$';
    return 0 if $DOMAIN=~/$suf2/;
  }
  return 1; 
}

sub default_species{
  my $self = shift ;
  $self->{'_default_species'} = shift if @_ ;
  return $self->{'_default_species'} 
}

sub has_non_fatal_error {$_[0]->{'non_fatal_error'} ? 1 : 0 ;}
sub has_fatal_error     {$_[0]->{'error'} ? 1 : 0 ;}

sub error{
  my $self = shift;
  $self->{'error'} = shift if @_;
  return $self->{'error'};
}

sub non_fatal_error{
  my $self = shift;
  $self->{'non_fatal_error'} = shift if @_;
  return $self->{'non_fatal_error'};
}

sub dynamic_use {
  my( $self, $classname ) = @_;
  my( $parent_namespace, $module ) = $classname =~/^(.*::)(.*)$/ ? ($1,$2) : ('::',$classname);
  no strict 'refs';
  return 1 if $parent_namespace->{$module.'::'}; # return if already used
  eval "require $classname";
  if($@) {
    warn "DBConnection: failed to use $classname\nDBConnection: $@";
    eval { Carp('xxxxx'); };
    return 0;
  }
  $classname->import();
  return 1;
}


1;
