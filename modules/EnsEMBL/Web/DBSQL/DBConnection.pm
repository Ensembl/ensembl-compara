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
    #warn "$species - $database - $dba";

    # Glovar
    if(!defined($dba) || $database eq 'glovar'){
        $self->_get_databases_common($species, $database);
    }
    else{
        $self->{'_dbs'}->{$species}->{$database} = $dba;
    }

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
  ( $species ) = $self->{'species_defs'}->valid_species( $species );
  if( ! $species ){ die("Invalid species: $species") }
  $self->{'non_fatal_error'} =  '' ;
  my $default_species_db = $self->{'_dbs'}->{$species} ;
  my %databases = map {($_,1)} @_;

  # find out if core is an annotation DB (like in Vega)
  my $is_annot_db = $self->{'species_defs'}->get_table_size(
    { -db =>'ENSEMBL_DB', -table => 'gene_remark'}
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
    my @simple_dbs = grep { $databases{$_} } qw(go mart fasta family help);
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
        if ($@) { 
            $default_species_db->{$_}->{'error'} .= "\n$_ database: $@";
        } elsif (my $core_db = $default_species_db->{'core'}) {
            $core_db->add_db_adaptor($_, $default_species_db->{$_});
        }
        delete $databases{$_};
    }

    # Attach core to these DBs (if core is available)
    my @dbs_with_core = grep { $databases{$_} } qw(disease);
    foreach (@dbs_with_core) {
        my $getter = "_get_" . lc($_) . "_database";
        eval{ $default_species_db->{$_} = $self->$getter($species); };
        if ($@) { 
            $self->{'error'} .= "\n$_ database: $@";
        } elsif (my $core_db = $default_species_db->{'core'}) {
            $default_species_db->{$_}->add_db_adaptor($core_db);
        }
        delete $databases{$_};
    }

    ## Other DBs
    # cdna
    if($databases{'cdna'}) {
        $self->_get_db_with_dnadb('cdna', $species);
        delete $databases{'cdna'};
    }

    # glovar
    if($databases{'glovar'}) {
        eval{ $default_species_db->{'glovar'} = $self->_get_glovar_database($species); };
        if( $@ ){ 
            warn $@;
            $default_species_db->{'glovar'} = 0;
            $self->{'non_fatal_error'} .= "\nglovar database: $@";
        }
        elsif( my $core_db = $default_species_db->{'core'} ){
            ## Glovar can serve several track sources via 
            ## a subclassed version of the same DB adaptor
            ## which share the same DB connection
            my $glovar_db = $default_species_db->{'glovar'};
            my $glovar_snp_adaptor = $glovar_db->get_GlovarSNPAdaptor;
            $glovar_snp_adaptor->consequence_exp($self->{'species_defs'}->GLOVAR_SNP_CONSEQUENCE_EXP);
            $core_db->add_ExternalFeatureAdaptor($glovar_snp_adaptor);
            $core_db->add_ExternalFeatureAdaptor($glovar_db->get_GlovarSTSAdaptor);
            #$core_db->add_ExternalFeatureAdaptor($glovar_db->get_GlovarTraceAdaptor);
            $core_db->add_ExternalFeatureAdaptor($glovar_db->get_GlovarHaplotypeAdaptor);
            #$core_db->add_ExternalFeatureAdaptor($glovar_db->get_GlovarBaseCompAdaptor);
        } 
        delete $databases{'glovar'};
    }
    
    # vega
    if ($databases{'vega'}) {
        $self->_get_db_with_dnadb('vega', $species);
        delete $databases{'vega'};
    }
                                                                                
    if ($databases{'otherfeatures'}) {
  warn "CONNECTED otherfeatures db";
        $self->_get_db_with_dnadb('otherfeatures', $species);
        delete $databases{'otherfeatures'};
    }
                                                                                
    # compara
    if( $databases{'compara'} ) {
        eval{ $default_species_db->{'compara'} =  $self->_get_compara_database($species); };
        if( $@ ){ 
            $self->{'error'} .= "\ncompara database: $@";
        } elsif ( my $core_db = $default_species_db->{core}) {
            my $comp_db = $default_species_db->{compara};
            $core_db->add_db_adaptor( 'compara', $comp_db );
#            $comp_db->add_db_adaptor( $core_db );

            # connect all related species databases to compara
            my %multi = (
               $self->{'species_defs'}->multi('BLASTZ_NET'),
               $self->{'species_defs'}->multi('BLASTZ_GROUP'),
               $self->{'species_defs'}->multi('PHUSION_BLASTN'),
               $self->{'species_defs'}->multi('BLASTZ_RECIP_NET'),
               $self->{'species_defs'}->multi('TRANSLATED_BLAT'),
               $self->{'species_defs'}->multi('GENE')
            );
            foreach my $sp ( keys %multi ) {
                my $db;
                eval{ $db = $self->_get_core_database( $sp ) };
                if ($@) {
                    $self->{'non_fatal_error'} .= "\ncompara database: $@";
                }
 #               else {
 #                   $db && $default_species_db->{'compara'}->add_db_adaptor($db);
 #               }
            }
        } 
        delete $databases{'compara'};
    } 

    if( $databases{'compara_multiple'} ) {
        eval{ $default_species_db->{'compara_multiple'} =  $self->_get_compara_multiple_database($species); };
        if( $@ ){ 
            $self->{'error'} .= "\ncompara multiple database: $@";
        } elsif ( my $core_db = $default_species_db->{core}) {
            my $comp_db = $default_species_db->{compara_multiple};
            $core_db->add_db_adaptor( 'compara_multiple', $comp_db );
        } 
        delete $databases{'compara_multiple'};
    } 

  
    # Check all requested db's exist
    if (%databases) {
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
  my $db_info =  $self->_get_database_info( shift, 'ENSEMBL_DB' ) ||
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
  #warn "CORE2: $default_species_db->{'core'}";
  if( $@ ){
    $self->{'error'} = qq(Unable to connect to the Core database: $@);
  } else { 
    warn "$db attached to core $default_species_db->{$db}";
    $default_species_db->{$db}->dnadb( $default_species_db->{'core'} );
    $default_species_db->{'core'}->add_db_adaptor($db, $default_species_db->{$db} );
    $default_species_db->{$db}->add_db_adaptor('core', $default_species_db->{'core'} );
  }
}

=head2 _get_snp_database

 Arg[1]      : String  
                Species name
 
 Example     : $self->_get_snp_database($species)
 Description : Gets snp database connection
 Return type : Bio::EnsEMBL::ExternalData::SNPSQL::DBAdaptor

=cut

sub _get_snp_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'ENSEMBL_SNP' ) ||
        die( "No SNP database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::ExternalData::SNPSQL::DBAdaptor' );
}

=head2 _get_haplotype_database

 Arg[1]      : String  
                Species name
 
 Example     : $self->_get_haplotype_database($species)
 Description : Gets haplotype database connection
 Return type : Bio::EnsEMBL::ExternalData::Hapolotype::DBAdaptor

=cut

sub _get_haplotype_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'ENSEMBL_HAPLOTYPE' ) ||
        die( "No haplotype database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::ExternalData::Haplotype::DBAdaptor' );
}


=head2 _get_fasta_database

 Arg[1]      : String  
                Species name
 
 Example     : $self->g_et_fasta_database($species)
 Description : Gets fasta database connection
 Return type : Bio::EnsEMBL::ExternalData::FASTA::DBAdaptor

=cut

sub _get_fasta_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'ENSEMBL_FASTA' ) ||
        die( "No fasta database for this species" );
    my $adpt =  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );    $self->dynamic_use('Bio::EnsEMBL::ExternalData::FASTA::FASTAAdaptor');
    return Bio::EnsEMBL::ExternalData::FASTA::FASTAAdaptor->new($adpt);
}

=head2 _get_vega_database

 Arg[1]      : String  
                Species name
 
 Example     : $self->_get_vega_database($species)
 Description : Gets vega (enembl) database connection
 Return type : Bio::EnsEMBL::DBSQL::DBAdaptor

=cut

sub _get_vega_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'ENSEMBL_VEGA' ) ||
        die( "No vega database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' ); 
}

=head2 _get_cdna_database

 Arg[1]      : String  
                Species name
 
 Example     : $self->_get_cdna_database($species)
 Description : Gets cdna database connection
 Return type : Bio::EnsEMBL::DBSQL::DBAdaptor

=cut

sub _get_cdna_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'ENSEMBL_CDNA' ) ||
        die( "No cdna database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' ); 
}

=head2 _get_disease_database

 Arg[1]      : String  
                Species name
 
 Example     : $self->_get_disease_database($species)
 Description : Gets disease database connection. N.B. This database no longer exists - 
               Ensembl now uses xrefs to store MIM data
 Return type : DiseaseHandler

=cut

sub _get_disease_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'ENSEMBL_DISEASE' ) ||
        die( "No disease database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::ExternalData::Disease::DBHandler' );
}

=head2 _get_otherfeatures_database

 Arg[1]      : String  
                Species name
 
 Example     : $self->_get_est_database($species)
 Description : Gets est database connection
 Return type : Bio::EnsEMBL::DBSQL::DBAdaptor

=cut

sub _get_otherfeatures_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'ENSEMBL_OTHERFEATURES' ) ||
        die( "No est database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' ); 
}

=head2 _get_lite_database

 Arg[1]      : String  
                Species name
 
 Example     : $self->_get_lite_database($species)
 Description : Gets lite database connection
 Return type : Bio::EnsEMBL::Lite::DBAdaptor

=cut

sub _get_lite_database{
    my $self = shift;
    my $db_info =  $self->_get_database_info( shift, 'ENSEMBL_LITE' ) ||
        die( "No lite database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::Lite::DBAdaptor' ); 
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
    my $db_info = $self->{'species_defs'}->multidb->{ENSEMBL_COMPARA} ||
        die( "No compara database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor' );
}

sub _get_compara_multiple_database{
    my $self = shift;
    my $dba =  $reg->get_DBAdaptor('Multi','compara_multiple');
    if(defined($dba)){
      return $dba;
    }
    my $db_info = $self->{'species_defs'}->multidb->{ENSEMBL_COMPARA_MULTIPLE} ||
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
    my $db_info = $self->{'species_defs'}->multidb->{ENSEMBL_WEBSITE} ||
        die( "No go database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );
}

sub _get_go_database{
    my $self = shift;
    my $db_info = $self->{'species_defs'}->multidb->{ENSEMBL_GO} ||
        die( "No go database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::ExternalData::GO::GOAdaptor' );
}

=head2 _get_family_database

 Arg[1]      : none
 
 Example     : $self->_get_family_database
 Description : Gets family database connection
 Return type : Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor

=cut

sub _get_family_database{
    my $self = shift;
    my $db_info = $self->{'species_defs'}->multidb->{ENSEMBL_FAMILY} ||
     die( "No family database for this species" );
    return  $self->_get_database( $db_info, 'Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor' ); 
}

=head2 _get_mart_database

 Arg[1]      : none
 
 Example     : $self->_get_mart_database
 Description : Gets mart database connection
 Return type : a database handle directly

=cut

# this may change 
sub _get_mart_database{
    my $self = shift;
    my $db_info = $self->{'species_defs'}->multidb->{ENSEMBL_MART} ||
        die( "No mart database in MULTI" );
    my $dsn = ( "DBI:mysql:".
          join( ';',
            "database=".$db_info->{NAME},
            "host="    .$db_info->{HOST},
            "port="    .$db_info->{PORT} ) );

    my $dbh = DBI->connect($dsn,
            $db_info->{USER},
            $db_info->{PASS} ) || die( $DBI::errstr );
    return $dbh;
}

=head2 _get_blast_database

 Arg[1]      : none
 
 Example     : $self->_get_blast_database
 Description : Gets blast database connection
 Return type : Bio::EnsEMBL::External::BlastAdaptor

=cut

sub _get_blast_database{
    my $self = shift;
    my $db_info = $self->{'species_defs'}->multidb->{ENSEMBL_BLAST} ||
        die( "No blast database in MULTI" );
  # Write DB, so update user and pass
    $db_info->{USER} = $self->{'species_defs'}->get_config('Multi',
                           'ENSEMBL_WRITE_USER');
    $db_info->{PASS} = $self->{'species_defs'}->get_config('Multi',
                           'ENSEMBL_WRITE_PASS');
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

    if ($db_info->{DRIVER} eq "Oracle" && !$ENV{'ORACLE_HOME'}){
        my $ora_home = $self->{'species_defs'}->ENSEMBL_ORACLE_HOME;
        warn("Trying to initialize and Oracle DBI driver but no ORACLE_HOME environment found!\n") if ($ora_home eq ''); 
        $ENV{'ORACLE_HOME'} = $ora_home;
        $ENV{'LD_LIBRARY_PATH'} = $self->{'species_defs'}->LD_LIBRARY_PATH;
    }

    return $a_class->new(
               -dbname => $db_info->{NAME},
               -user   => $db_info->{USER},
               -pass   => $db_info->{PASS},
               -host   => $db_info->{HOST},
               -port   => $db_info->{PORT},
           -driver => $db_info->{DRIVER},
              );
}

#----------------------------------------------------------------------
sub get_track_das_confdata{
    my $self = shift;
    $self->_get_das_confdata( 'track', @_ );  
}
sub get_internal_das_confdata{
    my $self = shift;
    $self->_get_das_confdata( 'internal', @_ );  
}
sub get_gene_das_confdata{
    my $self = shift;
    $self->_get_das_confdata( 'gene', @_ );  
}

=head2 _get_das_confdata

  Arg [1]   : Source type (track|internal|gene)
  Arg [2]   : Source name (optional)
  Function  : Returns either: ini-file DAS config for a single source,
              or: ini-file DAS config for all sources if no arg[2]
  Returntype: hashref: config data
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _get_das_confdata {
   my $self = shift;
   my $source_type = shift;
   my $source      = shift;

   my %confkeymap = ( track   =>"ENSEMBL_TRACK_DAS_SOURCES",
              internal=>"ENSEMBL_INTERNAL_DAS_SOURCES",
              gene    =>"ENSEMBL_GENE_DAS_SOURCES" );
   my $confkey = $confkeymap{$source_type} || 
     ( warn("Source type $source_type unrecognised") && return{} );

   my $confdata = $self->{'species_defs'}->$confkey();
   ref( $confdata ) eq 'HASH' || 
     ( warn("No sources configured for $confkey" ) && return{} );

   $source || return $confdata;

   my $source_confdata = $confdata->{$source} || 
     ( warn( "$confkey source $source not configured" ) && return{} );
   ref( $source_confdata ) eq 'HASH' || 
     ( warn( "$confkey source $source badly configured" ) && return{} );

   return $source_confdata;
}
#----------------------------------------------------------------------
sub get_track_das_confkeys   { $_[0]->_get_das_confkeys( 'track' ) }
sub get_internal_das_confkeys{ $_[0]->_get_das_confkeys( 'internal' ) }
sub get_gene_das_confkeys    { $_[0]->_get_das_confkeys( 'gene' ) }

=head2 _get_das_confkeys

  Arg [1]   : Source type (track|internal|gene)
  Function  : Returns a list of identifiers for all das sources of specified
              type in config ini file.
  Returntype: List of conf keys
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _get_das_confkeys {
   my $self = shift;
   my $source_type = shift;
   return( keys %{$self->_get_das_confdata($source_type)} );
}


#----------------------------------------------------------------------

sub add_track_das_sources {
    my $self = shift;
    return $self->_add_internal_das_sources( 'track', @_ );
}
sub add_internal_das_sources {
    my $self = shift;
    return $self->_add_internal_das_sources( 'internal', @_ );
}
sub add_gene_das_sources{
    my $self = shift;
    return $self->_add_internal_das_sources( 'gene', @_ );
}

=head2 _add_internal_das_sources

  Arg [1]   : Source type (track|internal|gene)
  Arg [2..n]: List of named DAS sources
  Function  : Attaches a DAS adaptor to the core DBAdaptor for each
              source in the given list.
  Returntype: boolean
  Exceptions: Warns if named sources cannot be found, or the config is bad.
  Caller    : 
  Example   : 

=cut

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

sub _add_internal_das_sources {
   my $self        = shift;
   my $source_type = shift;
   my @sources     = @_;

   my $databases = $self->get_databases('core');
   $databases->{'core'} ||
     ( warn("Core database not found") && return );

   # Lazy-load required modules
   $self->dynamic_use('Bio::EnsEMBL::ExternalData::DAS::DASAdaptor');
   $self->dynamic_use('Bio::EnsEMBL::ExternalData::DAS::DAS');

   foreach my $source( @sources ){
      $source =~ s/^managed_//;

      my $dbname = $self->_get_das_confdata( $source_type, $source );
      next unless $dbname->{'retrieve_features'} == 1; # Put in by EnsEMBL::Web::SpeciesDefs
      my $adaptor = undef;
      eval {
      my $url = $dbname->{'url'} ||
        ( warn( "$source_type DAS source $source has no url" ) && next );
      $url = "http://$url" unless $url =~ /https?:\/\//i;
      my $stype = $dbname->{'type'} || 'ensembl_location_chromosome';
      $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new(
        -url     => $url,
        -name    => $dbname->{'name'},
        -type    => $stype,
        -mapping => $dbname->{'mapping'} || $stype,
        -dsn     => $dbname->{'dsn'},
        -ens     => $databases->{'core'},
        -types   => $dbname->{'types'} || [], 
        $self->proxy($url) ? ( '-proxy_url' => $self->{'species_defs'}->ENSEMBL_WWW_PROXY ) : ()
      );
      };
      if($@) {
          warn("DAS error: $@") 
      } else {
         $databases->{'core'}->add_DASFeatureFactory(
            Bio::EnsEMBL::ExternalData::DAS::DAS->new( $adaptor )
         );
     }
  }
}

#----------------------------------------------------------------------

=head2 add_DASFeatureFactory

  Arg [1]   : Bio::EnsEMBL::ExternalData::DAS::DAS object
  Function  : Thin wrapper for Bio::EnsEMBL::DBSQL::DBAdaptor method
              of same name
  Returntype: boolean; 1 on success
  Exceptions: 
  Caller    : 
  Example   : $db_connection->add_DASFeatureFactory( $das );

=cut

sub add_DASFeatureFactory {
   my $self = shift;
   my $das  = shift || die( "No Bio::EnsEMBL::ExternalData::DAS::DAS obj" );
   $self->get_DBAdaptor( 'core' )->add_DASFeatureFactory( $das );
}

=head2 remove_DASFeatureFactories{

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub remove_DASFeatureFactories{
  $_[0]->get_DBAdaptor( 'core' )->remove_all_DASFeatureFactories;
  return 1;
}

#----------------------------------------------------------------------

sub add_external_das_sources {
  my $self = shift;
  my $databases = shift;
  my $das_data  = shift;
  return unless $databases->{'core'};

  # Lazy-load required modules
  $self->dynamic_use('Bio::EnsEMBL::ExternalData::DAS::DASAdaptor');
  $self->dynamic_use('Bio::EnsEMBL::ExternalData::DAS::DAS');

  foreach (@_) {
    s/^managed_//;
    s/^extdas_//;
    my $dbname = $das_data->{$_};
    next unless $dbname;
    my $adaptor = undef;
    eval {
      my $URL = $dbname->{'URL'};
         $URL = "http://$URL" unless $URL =~ /https?:\/\//i;
      my $stype = $dbname->{'type'} || 'ensembl_location_chromosome';
      $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new(
        -url   => "$URL/das",
        -name       => $dbname->{'name'},
        -type    => $stype,
        -mapping => $dbname->{'mapping'} || $stype,
        -dsn   => $dbname->{'dsn'},
        -ens   => $databases->{'core'},
        $self->proxy($URL) ? ( '-proxy_url' => $self->{'species_defs'}->ENSEMBL_WWW_PROXY ) : ()
      );
    };
    if($@) {
      warn("DAS error >> $@ <<") 
    } else {
      $self->add_DASFeatureFactory( 
        Bio::EnsEMBL::ExternalData::DAS::DAS->new( $adaptor )
      );
    }
  }
}

########################

=head2 default_species

 Arg[1]      : String 
                a species name
                
 Example     : $self->default_species( 'Homo_sapiens' );
 Description : gets or sets the default species for the databases
 Return type : Sets the default species in the object and/or return the species name

=cut

sub default_species{
    my $self = shift ;
    $self->{'_default_species'} = shift if @_ ;
    return $self->{'_default_species'} 
}

=head2 has_non_fatal_error / has_fatal_error

 Example     : $self->has_non_fatal_error;
 Description : return a bool true if error or false if no error
 Return type : Bool

=cut

sub has_non_fatal_error {$_[0]->{'non_fatal_error'} ? 1 : 0 ;}
sub has_fatal_error     {$_[0]->{'error'} ? 1 : 0 ;}

=head2 non_fatal_error / error

 Arg[1]      : String 
                An error string to describe the database error
                
 Example     : $self->error( ' This is an error' );
                $self->non_fatal_error( ' This is an error' );
 Description : gets or sets the error state of the database object
 Return type : The Database error description as a string

=cut

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

=head2 dynamic_use

  Arg [1]    : string $classname
               The name of the class to "use"
  Example    : $myobject->dynamic_use( 'Sanger::Graphics::GlyphSet::das' );
  Description: Requires, and imports the methods for the classname provided,
               checks the symbol table so that it doesnot re-require modules
               that have already been required.
  Returntype : Integer - 1 if successful, 0 if failure
  Exceptions : Warns to standard error if module fails to compile
  Caller     : general

=cut

sub dynamic_use {
  my( $self, $classname ) = @_;
  my( $parent_namespace, $module ) = $classname =~/^(.*::)(.*)$/ ? ($1,$2) : (':
:',$classname);
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
