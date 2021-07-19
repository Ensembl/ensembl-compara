=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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

=cut

package EnsEMBL::Web::DBSQL::DBConnection;

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;
use Carp;

use Bio::EnsEMBL::Registry;

use Exporter qw(import);
our @EXPORT_OK = qw(register_cleaner);

my $reg = 'Bio::EnsEMBL::Registry';

my %CLEANERS = (
                'Bio::EnsEMBL::Variation::DBSQL::DBAdaptor' => [
sub {
  my ($vdb,$sd) = @_;

  my $c = $sd->ENSEMBL_VCF_COLLECTIONS;
  if($c && $vdb->can('use_vcf')) {
    $vdb->vcf_config_file($c->{'CONFIG'});
    $vdb->vcf_root_dir($sd->DATAFILE_BASE_PATH);
    $vdb->vcf_tmp_dir($sd->ENSEMBL_TMP_DIR);
    $vdb->use_vcf($c->{'ENABLED'});
  }
},
]
                );

sub new {
  my( $class, $species, $species_defs ) = @_;
  my $self = bless {
    '_default_species'  => $species,
    'species_defs'      => $species_defs,
    '_dbs'              => {}
  }, $class;
  return $self;
}

# Call me to register a cleanup function to make an adaptor "good" after
#   creating it for a certain target class
sub register_cleaner {
  my ($target,$cleaner) = @_;

  push @{$CLEANERS{ref $target || $target}||=[]},$cleaner;
}

sub clean {
  my ($self,$db) = @_;

  return unless $db;

  foreach my $klass (keys %CLEANERS) {
    next unless $db->isa($klass);
    $_->($db,$self->{'species_defs'}) for (@{$CLEANERS{$klass}});
  }
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
  my $self     = shift;
  my $database = shift || $self->error('FATAL', 'Need a DBAdaptor name');
  my $species  = shift || $self->default_species;
  
  $self->{'_dbs'}{$species} ||= {}; 

  # if we have connected to the db before, return the adaptor from the cache
  return $self->{'_dbs'}{$species}{$database} if exists $self->{'_dbs'}{$species}{$database};
    
  # try to retrieve the DBAdaptor from the Registry
  my $dba = $reg->get_DBAdaptor($species, $database);
  $self->clean($dba);

  ## Collection databases
  if (! $dba ) {
    my $sg = $self->{species_defs}->get_config($species, "SPECIES_DATASET");
    $dba = eval {$reg->get_DBAdaptor($sg, $database)} if $sg;
    if ($dba) {
      $dba->{_is_multispecies} = 1;
      $dba->{_species_id} = $self->{species_defs}->get_config($species, "SPECIES_META_ID");
    }
  }

  $self->{'_dbs'}{$species}{$database} = $dba;
  
  return $self->{'_dbs'}{$species}{$database};
}

##########################################################################################

####  THESE OTHER METHODS SEEM ONLY TO BE USED BY SOME OLD DUMPING SCRIPTS

##########################################################################################


=head2 get_databases

 Arg[1]      : String - The databases required (core, vega, est)
 
 Example     : $dbconn->get_databases('core', 'est');
 Description : A wrapper that returns a list of databases for the current
               (default) species 
 Return type : Hashref - The database connections requested

=cut

sub get_databases {
  my $self = shift;
  return $self->get_databases_species($self->default_species, @_);
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
      $self->clean($dba);
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

 Description : Internal call that gets the database connections.
               Note - doesn't seem to be called by the webcode in e66,
               all the work is now done by E::m::B::E::Registry.pm and E::m::B::E::U::ConfigRegistry.pm
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
  foreach (qw(cdna otherfeatures rnaseq)) {
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

=head2 _get_compara_database

 Arg[1]      : none
 
 Example     : $self->_get_compara_database
 Description : Gets compara database connection
 Return type : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

=cut

sub _get_compara_database{
  my $self = shift;
  my $dba =  $reg->get_DBAdaptor('Multi','compara');
  $self->clean($dba);
  if(defined($dba)){
    return $dba;
  }
  my $db_info = $self->{'species_defs'}->multidb->{DATABASE_COMPARA} ||
     die( "No compara database for this species" );
  return  $self->_get_database( $db_info, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor' );
}

sub _get_help_database{
  my $self = shift;
  my $db_info = $self->{'species_defs'}->multidb->{DATABASE_WEBSITE} ||
     die( "No go database for this species" );
  return  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );
}

=head2 _get_go_database

 Arg[1]      : none
 
 Example     : $self->_get_go_database
 Description : Gets go database connection
 Return type : Bio::EnsEMBL::DBSQL::OntologyDBAdaptor

=cut

sub _get_go_database{
  my $self = shift;
  my $db_info = $self->{'species_defs'}->multidb->{DATABASE_GO} ||
     die( "No go database for this species" );
  use Bio::EnsEMBL::DBSQL::OntologyDBAdaptor;     
  return  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::OntologyDBAdaptor' );
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
  my $species  = shift;
  my $conf_key = shift || die( "Need a DB conf key" );
  my $conf = $self->{'species_defs'}->get_config( $species, 'databases' ) || return undef();
  return $conf->{$conf_key} || undef();
}

=head2 _get_database

 Arg[1]      : Hash 
                From '_get_database_info' method
                
 Arg[2]      : String
                Adaptor type
 
 Example     : $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );
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
  return 0 unless $SiteDefs::HTTP_PROXY;
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
