#!/usr/local/bin/perl -w

package EnsEMBL::Web::SpeciesDefs;

### SpeciesDefs - Ensembl web configuration accessor

### This module provides programatic access to the web site configuration
### data stored in the $ENSEMBL_SERVERROOT/conf/*.ini (INI) files. See
### $ENSEMBL_SERVERROOT/conf/ini.README for details.

### Owing to the overhead implicit in parsing the INI files, two levels of
### caching (memory, filesystem) have been implemented. To update changes
### made to an INI file, the running process (e.g. httpd) must be halted,
### and the $ENSEMBL_SERVERROOT/conf/config.packed file removed. In the
### absence of a cache, the INI files are automatically parsed parsed at
### object instantiation. In the case of the Ensembl web site, this occurs
### at server startup via the $ENSEMBL_SERVERROOT/conf/perl.startup
### script. The filesystem cache is not enabled by default; the
### SpeciesDefs::store method is used to do this explicitly.

### Example usage:

###  use SpeciesDefs;
###  my $speciesdefs  = SpeciesDefs->new;

###  # List all configured species
###  my @species = $speciesdefs->valid_species();

###  # Test to see whether a species is configured
###  if( scalar( $species_defs->valid_species('Homo_sapiens') ){ }

###  # Getting a setting (parameter value/section data) from the config
###  my $sp_name = $speciesdefs->get_config('Homo_sapiens','SPECIES_COMMON_NAME');

###  # Alternative setting getter - uses autoloader
###  my $sp_bio_name = $speciesdefs->SPECIE_%S_COMMON_NAME('Homo_sapiens');

###  # Can also use the ENSEMBL_SPECIES environment variable
###  ENV{'ENSEMBL_SPECIES'} = 'Homo_sapiens';
###  my $sp_bio_name = $speciesdefs->SPECIES_COMMON_NAME;

###  # Getting a parameter with multiple values
###  my( @chromosomes ) = @{$speciesdefs->ENSEMBL_CHROMOSOMES};


use strict;
use warnings;
no warnings "uninitialized";

use Carp qw( cluck );

use Storable qw(lock_nstore lock_retrieve thaw);
use Data::Dumper;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::ConfigRegistry;

use DBI;
use SiteDefs qw(:ALL);
our ( $AUTOLOAD, $CONF );

sub new {
  ### c
  my $class = shift;

  my $self = bless( {}, $class );
  my $conffile = $SiteDefs::ENSEMBL_CONF_DIRS[0].'/'.$ENSEMBL_CONFIG_FILENAME;
  $self->{'_filename'} = $conffile;

  $self->parse unless $CONF;

  ## Diagnostic - sets up back trace of point at which new was
  ## called - useful for trying to track down where the cacheing
  ## is taking place

  $self->{'_new_caller_array'} = [];
  if( 1 ) {
    my $C = 0;
    while( my @T = caller($C) ) {
      $self->{'_new_caller_array'}[$C] = \@T; $C++;
    }
  }
  $self->{'_multi'}   = $CONF->{'_multi'};
  $self->{'_storage'} = $CONF->{'_storage'};

  return $self;
}


sub name {
  ### a
  ### returns the name of the current species
  ## TO DO - rename method to 'species'
  return $ENV{'ENSEMBL_SPECIES'}|| $ENSEMBL_PRIMARY_SPECIES;
}


sub valid_species(){
  ### Filters the list of species to those configured in the object.
  ### If an empty list is passes, returns a list of all configured species
  ### Returns: array of configured species names
  my $self = shift;
  my %test_species = map{ $_=>1 } @_;

  #my $species_ref = $CONF->{'_storage'}; # This includes 'Multi'
  my %species       = map{ $_=>1 } values %{$SiteDefs::ENSEMBL_SPECIES_ALIASES};
  my @valid_species = keys %species;

  if( %test_species ){ # Test arg list if required
    @valid_species = grep{ $test_species{$_} } @valid_species;
  }
  return @valid_species;
}

sub AUTOLOAD {
  ### a
  my $self = shift;
  my $species = shift || $ENV{'ENSEMBL_SPECIES'} || $ENSEMBL_PRIMARY_SPECIES;
  my $var = our $AUTOLOAD;
  $var =~ s/.*:://;
  return $self->get_config( $species, $var );
}


sub configure_registry {
  ### Loads the adaptor into the registry from the CONF definitions
  ### Returns: none
  my $self = shift;
  my %adaptors = (
    'VARIATION' => 'Bio::EnsEMBL::Variation::DBSQL::DBAdaptor', 
    'FUNCGEN'   => 'Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor', 
    'SNP'       => 'Bio::EnsEMBL::ExternalData::SNPSQL::DBAdaptor',
    'LITE'      => 'Bio::EnsEMBL::Lite::DBAdaptor',
    'HAPLOTYPE' => 'Bio::EnsEMBL::ExternalData::Haplotype::DBAdaptor',
    'EST'       => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'OTHERFEATURES' => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'CDNA'      => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'VEGA'      => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'DB'        => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'COMPARA'   => 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor',
    'ENSEMBL_VEGA'  => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'HELP'      => undef,
    'DISEASE'   => undef,
    'BLAST'     => undef,
    'MART'      => undef,
    'GO'        => undef,
    'FASTA'     => undef,
  ); 
   
  for my $species ( keys %{$CONF->{_storage}} ) {
    (my $sp = $species ) =~ s/_/ /g;
    Bio::EnsEMBL::Registry->add_alias( $species, $sp );
    for my $type ( keys %{$CONF->{'_storage'}{$species}{databases}}){
## Grab the configuration information from the SpeciesDefs object
      my $TEMP = $CONF->{'_storage'}{$species}{databases}{$type};
## Skip if the name hasn't been set (mis-configured database)
      if(! $TEMP->{NAME}){warn((' 'x10)."[WARN] no NAME for $sp $type") && next}
      if(! $TEMP->{USER}){warn((' 'x10)."[WARN] no USER for $sp $type") && next}
      next unless $TEMP->{NAME};
      next unless $TEMP->{USER};
      my %arg = ( '-species' => $species, '-dbname' => $TEMP->{NAME} );
## Copy through the other parameters if defined
      foreach (qw(host pass port user driver)) {
        $arg{ "-$_" } = $TEMP->{uc($_)} if defined $TEMP->{uc($_)};
      }
## Check to see if the adaptor is in the known list above
      if( $type =~ /ENSEMBL_(\w+)/ && exists $adaptors{$1}  ) {
## If the value is defined then we will create the adaptor here...
        if( my $module = $adaptors{ my $key = $1 } ) {
## Hack because we map ENSEMBL_DB to 'core' not 'DB'....
          my $group = $key eq 'DB' ? 'core' : lc( $key );
          $group = 'otherfeatures' if $group eq 'est';
## Create a new "module" object... stores info - but doesn't create connection yet!
          if( $self->dynamic_use( $module ) ) {
            $module->new( %arg, '-group' => $group );
          }
## Add information to the registry...
          Bio::EnsEMBL::Registry->set_default_track( $species, $group );
        }
      } else {
        warn("unknown database type $type\n");
      }
    }
  }
  Bio::EnsEMBL::Registry->load_all($SiteDefs::ENSEMBL_REGISTRY);
  if ($SiteDefs::ENSEMBL_NOVERSIONCHECK) {
    Bio::EnsEMBL::Registry->no_version_check(1);
  }
}

sub dynamic_use {
  ### Dynamically includes a required module
  ### Argument: class name of the module to include
  ### Returns: boolean
  my( $self, $classname ) = @_;
  my( $parent_namespace, $module ) = $classname =~/^(.*::)(.*)$/ ? ($1,$2) : ('::',$classname);
  no strict 'refs';
  return 1 if $parent_namespace->{$module.'::'}; # return if already used
  eval "require $classname";
  if($@) {
    warn "EnsEMBL::Web::SpeciesDefs: failed to use $classname\nEnsEMBL::Web::SpeciesDefs: $@";
    return 0;
  }
  $classname->import();
  return 1;
}

sub get_config {
  ## Returns the config value for a given species and a given config key
  ### Arguments: species name(string), parameter name (string)
  ### Returns:  parameter value (any type), or undef on failure
  my $self = shift;
  my $species = shift;
  my $var     = shift || $species;

  if(defined $CONF->{'_storage'}) {
    return $CONF->{'_storage'}{$species}{$var} if exists $CONF->{'_storage'}{$species} &&
                                                  exists $CONF->{'_storage'}{$species}{$var};
    return $CONF->{'_storage'}{$var}           if exists $CONF->{'_storage'}{$var};
  }
  no strict 'refs';
  my $S = "SiteDefs::".$var;
  return ${$S} if defined ${$S};

  warn "UNDEF ON $var [$species]. Called from ", (caller(1))[1] , " line " , (caller(1))[2] , "\n" if $ENSEMBL_DEBUG_FLAGS & 4;
  return undef;
}

sub set_config {
  ### Overrides the config value for a given species and a given config key 
  ### (use with care!)
  ### Arguments: species name (string), parameter name (string), parameter value (any)
  ### Returns: boolean
  my $self = shift;
  my $species = shift;
  my $key = shift;
  my $value = shift || undef;
  $CONF->{'_storage'}{$species}{$key} = $value if defined $CONF->{'_storage'} &&
                                                   exists $CONF->{'_storage'}{$species};
  return 1;
}

sub retrieve {
  ### Retrieves stored configuration from disk
  ### Returns: boolean
  ### Exceptions: The filesystem-cache file cannot be opened
  my $self = shift;
  my $Q = lock_retrieve( $self->{'_filename'} ) or die( "Can't open $self->{'_filename'}: $!" ); 
  ( $CONF->{'_storage'}, $CONF->{'_multi'} ) = @$Q if ref($Q) eq 'ARRAY';
  return 1;
}

sub store {
  ### Creates filesystem-cache by storing config to disk. 
  ### Returns: boolean 
  ### Caller: perl.startup, on first (validation) pass of httpd.conf
  my $self = shift;
  die "[CONF]    [FATAL] Could not write to $self->{'_filename'}: $!" unless
    lock_nstore( [ $CONF->{'_storage'}, $CONF->{'_multi'} ], $self->{_filename} );
  return 1;
}


sub parse {
  ### Retrieves a stored configuration or creates a new one
  ### Returns: boolean
  ### Caller: $self->new when filesystem and memory caches are empty
  my  $self  = shift;
  if( ! $SiteDefs::ENSEMBL_CONFIG_BUILD and -e $self->{_filename} ){
    warn( ( '-' x 78 ) ."\n",
          "[CONF]    \033[0;32m[INFO] Retrieving conf from $self->{_filename}\033[0;39m\n",
          ( '-' x 78 ) ."\n" );
    $self->retrieve();
    $self->configure_registry();
    return 1;
  }
  $self->_parse();
  $self->configure_registry();
  $self->create_robots_txt();
  $self->{'_parse_caller_array'} = [];
  my $C = 0;
  while(my @T = caller($C) ) { $self->{'_parse_caller_array'}[$C] = \@T; $C++; }
}

sub _convert_date {
  ### Converts a date from a species database into a human-friendly format for web display 
  ### Argument: date in format YYYY-MM with optional -string attached
  ### Returns: hash ref {'date' => 'Mmm YYYY', 'string' => 'xxxxx'}
  my $date = shift;
  my %parsed;
  my @a = ($date =~ /(\d{4})-(\d{2})-?(.*)/);
  my @now = localtime();
  my $thisyear = $now[5] + 1900;
  my %months = ('01'=>'Jan', '02'=>'Feb', '03'=>'Mar', '04'=>'Apr',
                  '05'=>'May', '06'=>'Jun', '07'=>'July','08'=>'Aug',
                  '09'=>'Sep', '10'=>'Oct', '11'=>'Nov', '12'=>'Dec');

  my $year = $a[0];
  my $mon = $a[1];
  my $month;
  if ($mon && $mon < 13) {
    $month = $months{$mon};
  }

  if ($year > $thisyear || !$month) {
    print STDERR "\t  [WARN] DATE FORMAT MAY BE REVERSED - parses as $mon $year\n";
  }

  $parsed{'date'} = $month.' '.$year;
  $parsed{'string'} = $a[2]; 

  return \%parsed;
}

sub _parse {
  ### Does the actual parsing of .ini files and now also gets
  ### some information from the databases (assembly details, miniads)
  ### Returns: boolean
  my $self = shift; 
  warn '-' x 78 , "\n[CONF]    [INFO] Parsing .ini files\n" ;
  $CONF->{'_storage'} = {};
  my $BC = $self->bread_crumb_creator();
  my ($defaults, $common);

###### Loop for each species exported from SiteDefs
  
  foreach my $filename ( 'DEFAULTS', @$ENSEMBL_SPECIES, 'MULTI' ) {
    warn "-" x 78, "\n[SPECIES] [INFO] Starting $filename\n";
    my $tree            = {%$BC};
    
###### Read and parse the <species>.ini file
    my $inifile;
    foreach my $confdir( @SiteDefs::ENSEMBL_CONF_DIRS ){
      if( -e "$confdir/ini-files/$filename.ini" ){
        if( -r "$confdir/ini-files/$filename.ini" ){
          $inifile = "$confdir/ini-files/$filename.ini";
        } else {
          warn "$confdir/ini-files/$filename.ini is not readable\n" ;
          next;
        }
        #warn "OPENING $inifile\n";
        open FH, $inifile or die( "Problem with $inifile: $!" );
###### Loop for each line of <species>.ini
        my $current_section = undef;
        my $line_number     = 0;
        while(<FH>) {
          s/\s+[;].*$//;    # These two lines remove any comment strings
          s/^[#;].*$//;     # from the ini file - basically ; or #..
          if( /^\[\s*(\w+)\s*\]/ ) {          # New section - i.e. [ ... ]
            $current_section          = $1;
            $tree->{$current_section} ||= {}; # create new # element if required
            if(defined $defaults->{ $current_section }) { #add settings from default!!
              foreach( keys %{$defaults->{ $current_section }} ) {
                $tree->{$current_section}{$_} = $defaults->{$current_section}{$_};
              }
            }
          } elsif (/(\w\S*)\s*=\s*(.*)/ && defined $current_section) { # Config entry
            my ($key,$value) = ($1,$2); ## Add a config entry under the current 'top level'
            $value=~s/\s*$//;
            if($value=~/^\[\s*(.*?)\s*\]$/) { # [ - ] signifies an array
              my @array = split /\s+/, $1;
              $value = \@array;
            }
            $tree->{$current_section}{$key} = $value;
          } elsif (/([.\w]+)\s*=\s*(.*)/) { # precedes a [ ] section
            print STDERR "\t  [WARN] NO SECTION $filename.ini($line_number) -> $1 = $2;\n";
          }
          $line_number++;
        }
        close FH;
      }
    }
    if( ! $inifile ) {
      warn "could not find $filename.ini in @{[@SiteDefs::ENSEMBL_CONF_DIRS]}";
      next;
    }

######### Deal with DEFAULTS.ini -- store the information collected in a separate tree...
#########                           and skip the remainder of this code...
    if( $filename eq 'DEFAULTS' ) { 
      print STDERR ( "\t  [INFO] Defaults file successfully stored\n" );
      $defaults = $tree;
      next;
    }

############### <species>.ini read and parsed 
        
######### Prepare database config
######### Default database values, used if no [database] section included
    my $HOST   = $tree->{'general'}{'ENSEMBL_HOST'};      
    my $PORT   = $tree->{'general'}{'ENSEMBL_HOST_PORT'}; 
    my $USER   = $tree->{'general'}{'ENSEMBL_DBUSER'};    
    my $PASS   = $tree->{'general'}{'ENSEMBL_DBPASS'};    
    my $DRIVER = $tree->{'general'}{'ENSEMBL_DRIVER'} || 'mysql';    
    
## For each database look for non-default config..
    if( exists $tree->{'databases'} ) {
      foreach my $key ( keys %{$tree->{'databases'}} ) {
        my $DB_NAME = $tree->{'databases'}{$key};
      print "$key......$DB_NAME\n";
        if( $DB_NAME =~ /%_(\w+)_%/ ) {
          $DB_NAME = lc(sprintf( '%s_%s_%s_%s', $filename , $1, $SiteDefs::ENSEMBL_VERSION, $tree->{'general'}{'SPECIES_RELEASE_VERSION'} ));
        } elsif( $DB_NAME =~/%_(\w+)/ ) {
          $DB_NAME = lc(sprintf( '%s_%s_%s', $filename , $1, $SiteDefs::ENSEMBL_VERSION ));
        } elsif( $DB_NAME =~/(\w+)_%_/ ) {
          $DB_NAME = lc(sprintf( '%s_%s', $1, $SiteDefs::ENSEMBL_VERSION ));
        }
        if($tree->{'databases'}{$key} eq '') {
          delete $tree->{'databases'}{$key};
        } elsif(exists $tree->{$key} && exists $tree->{$key}{'HOST'}) {
          my %cnf = %{$tree->{$key}};
          $tree->{'databases'}{$key} = {
            'NAME'   => $DB_NAME,
            'HOST'   => exists( $cnf{'HOST'}  ) ? $cnf{'HOST'}   : $HOST,
            'USER'   => exists( $cnf{'USER'}  ) ? $cnf{'USER'}   : $USER,
            'PORT'   => exists( $cnf{'PORT'}  ) ? $cnf{'PORT'}   : $PORT,
            'PASS'   => exists( $cnf{'PASS'}  ) ? $cnf{'PASS'}   : $PASS,
            'DRIVER' => exists( $cnf{'DRIVER'}) ? $cnf{'DRIVER'} : $DRIVER,
          };
          delete $tree->{$key};
        } else {
          $tree->{'databases'}{$key} = {
            'NAME'   => $DB_NAME,
            'HOST'   => $HOST,
            'USER'   => $USER,
            'PORT'   => $PORT,
            'PASS'   => $PASS,
            'DRIVER' => $DRIVER
          };
        }
      }
    }

    $common = $tree;

    ## get some info from core meta table
    unless ($filename eq 'MULTI') {
      ## hash of keys (other than taxonomy) that we want to use
      my %meta_map = (
        'species.ensembl_alias_name'  => 'SPECIES_COMMON_NAME',
        'assembly.default'            => 'ENSEMBL_GOLDEN_PATH',
        'assembly.name'               => 'ASSEMBLY_ID',
      );

      my $dbh = $self->db_connect( $tree, 'ENSEMBL_DB' );
      my $sql = qq(SELECT * FROM meta WHERE meta_key != 'patch' ORDER BY meta_id);
      my $sth = $dbh->prepare( $sql );
      my $rst  = $sth->execute || die( $sth->errstr );
      my $results = $sth->fetchall_arrayref();
      print STDERR "\t  [WARN] NO METADATA!!\n" if !@$results;
      my @taxonomy = ();
      foreach my $row (@$results) {
        my $key   = $row->[1];
        my $value = $row->[2];
        if ($key eq 'species.classification') {
          push(@taxonomy, $value);
        }
        elsif ($key eq 'assembly.date') {
          my $assembly = _convert_date($value);
          $tree->{'general'}{'ASSEMBLY_DATE'} = $assembly->{'date'};
          print STDERR "\t  [WARN] NO ASSEMBLY DATE\n" if !$assembly->{'date'};
        }
        elsif ($key eq 'genebuild.version') {
          my $genebuild = _convert_date($value);
          $tree->{'general'}{'GENEBUILD_DATE'} = $genebuild->{'date'};
          $tree->{'general'}{'GENEBUILD_BY'} = $genebuild->{'string'};  
          print STDERR "\t  [WARN] NO GENEBUILD DATE \n" if !$genebuild->{'date'};
          print STDERR "\t  [WARN] NO GENEBUILD NAME \n" if !$genebuild->{'string'};
        }
        elsif (my $v = $meta_map{$key}) {
          $tree->{'general'}{$v} = $value;
          print STDERR "\t  [WARN] EMPTY VARIABLE $v\n" if !$value;
        }
      }
      $sth->finish();
      $dbh->disconnect();

      ## Do species name and group
      (my $ininame = $filename) =~ s/_/ /g;
      my $bioname = $taxonomy[1].' '.$taxonomy[0];
      $tree->{'general'}{'SPECIES_BIO_NAME'} = $ininame;
      print STDERR "\t  [WARN] SPECIES NAME MISMATCH!\n" if $ininame ne $bioname;
      $tree->{'general'}{'SPECIES_GROUP'} = 'Eukaryotes';
      foreach my $taxon (@taxonomy) {
        if ($taxon eq 'Mammalia') {
          $tree->{'general'}{'SPECIES_GROUP'} = 'Mammals';
          last;
        }
        if ($taxon eq 'Chordata') {
          $tree->{'general'}{'SPECIES_GROUP'} = 'Chordates';
          last;
        }
      }
      
      ## Also get archive assembly info for each species
      $dbh = $self->db_connect( $tree, 'ENSEMBL_WEBSITE' );
      $tree->{'archive'} = {};

      $sql = qq(SELECT r.release_id, r.assembly_name 
                    FROM release_species r, species s 
                    WHERE r.species_id = s.species_id
                      AND s.name = "$filename" 
                      AND r.assembly_name != ''
                    ORDER BY release_id);
      $sth = $dbh->prepare( $sql );
      $rst  = $sth->execute || die( $sth->errstr );
      $results = $sth->fetchall_arrayref();
      foreach my $row (@$results) {
        my $release_id  = $row->[0];
        my $assembly    = $row->[1];
        $tree->{'archive'}{$release_id} = $assembly;
      }
      $sth->finish();
      $dbh->disconnect();
    }

    ## Also cache miniad data
    my @miniads;
    my $dbh = $self->db_connect( $tree, 'ENSEMBL_WEBSITE' );
    my $sql = qq(SELECT image, alt, url 
              FROM miniad
              WHERE start_date < NOW() AND end_date > NOW()
    );
    my $sth = $dbh->prepare( $sql );
    my $rst  = $sth->execute || die( $sth->errstr );
    my $results = $sth->fetchall_arrayref();
    foreach my $r (@$results) {
      push @miniads, {
        'image' => $r->[0],
        'alt'   => $r->[1],
        'url'   => $r->[2],
      };
    }
    $tree->{'miniads'} = \@miniads;
    $sth->finish();
    $dbh->disconnect();

#### INI FILE BLAST DATABASES
# Creates default file name of format
# Anopheles_gambiae.AgamP3.39.dna_rm.seqlevel.fa if the value "%_" is in ini file

    foreach my $blast_type (keys %$tree) {
      next unless $blast_type =~ /_DATASOURCES/;
      foreach my $source ( keys %{$tree->{$blast_type}} ) {
	      my $file = $tree->{$blast_type}{$source};
	      next unless $file =~ /^%_/;
	      my $assembly = $tree->{'general'}{'ENSEMBL_GOLDEN_PATH'};
	      (my $type = lc($source)) =~ s/_/\./ ;
	      if ($type =~ /latestgp/) {
	        $type =~ s/latestgp(.*)/dna$1\.seqlevel/;
	        $type =~ s/.masked/_rm/;
	      }
	      $type = "ncrna" if $type eq 'rna.nc';
	      my $new_file = sprintf( '%s.%s.%s.%s', $filename, $assembly, $SiteDefs::ENSEMBL_VERSION, $type ).".fa";
	      #print "AUTOGENERATING $source......$new_file\t";
	      $tree->{$blast_type}{$source} = $new_file;
      }
    }


#### This is the bit of code which handles the "Multi-species" part of the hash....
#### It creates an entry "_multi" with the following structure:
####
#### databases => 
####     ENSEMBL_COMPARA =>
####         HOST => ecs1d
####         NAME => compara_mouse_4_2
####         PASS => 
####         PORT => 3306
####         USER => ensro
#### SYNTENY => 
####     Homo_sapiens => 
####         Mus_musculus  => 1 # Mouse is     running on server
####         Fugu_rubripes => 0 # Fugu  is NOT running on server
####     Fugu_rubripes => 
####         Homo_sapiens  => 1
####     Mus_musculus => 
####         Homo_sapiens  => 1
#### GENE    => 
####       ..................
#### DNA     => 
####       ..................
#### 

    foreach( keys %{$tree->{'general'}} ) {  
      $tree->{$_} = $tree->{'general'}{$_};
    }                      
    delete $tree->{'general'};
    if( $filename eq 'MULTI' ) { ## This is the multispecies hash...
      my $dbh;
  
      if( $tree->{'databases'}->{'ENSEMBL_COMPARA_MULTIPLE'} ){
        $dbh = $self->db_connect( $tree, 'ENSEMBL_COMPARA_MULTIPLE' );
      } elsif(  $tree->{'databases'}->{'ENSEMBL_COMPARA'} ) {
        $dbh = $self->db_connect( $tree, 'ENSEMBL_COMPARA' );
      }
      if($dbh) {
        my %sections = (
          'SYNTENY' => 'GENE_MULTIPLE',
        );
        ## We've done the DB hash...
        ## So lets get on with the multiple alignment hash;
	      my $q = qq{
	        SELECT ml.type, gd.name, mlss.name, mlss.method_link_species_set_id
	        FROM   method_link ml, method_link_species_set mlss, genome_db gd, species_set ss 
	        WHERE  mlss.method_link_id = ml.method_link_id 
          AND    mlss.species_set_id=ss.species_set_id 
          AND    ss.genome_db_id = gd.genome_db_id 
          AND    ml.type in ('MLAGAN','BLASTZ_NET','BLASTZ_RAW')};

          my $sth = $dbh->prepare( $q );
          my $rv  = $sth->execute || die( $sth->errstr );
          my $results = $sth->fetchall_arrayref();
          my $thash;

	        my $KEY = 'ALIGNMENTS';
          foreach my $row ( @$results ) {
            my ($type, $species, $name, $id) = (uc($row->[0]), $row->[1], $row->[2], $row->[3]);
            $species =~ tr/ /_/;
	          $tree->{$KEY}->{$id}->{'id'} = $id;
	          $tree->{$KEY}->{$id}->{'name'} = $name;
	          $tree->{$KEY}->{$id}->{'type'} = $type;
            $tree->{$KEY}->{$id}->{'species'}->{$species} = 1;
          }

#	warn("$KEY: ". Data::Dumper::Dumper($tree->{$KEY}));

          $sth->finish();
          $dbh->disconnect();
        }
    
        if( $tree->{'databases'}->{'ENSEMBL_COMPARA'} ){
          $dbh = $self->db_connect( $tree, 'ENSEMBL_COMPARA' );
        }

        if($dbh) {
          my %sections = (
            'ENSEMBL_ORTHOLOGUES' => 'GENE',
            'HOMOLOGOUS_GENE'     => 'GENE',
            'HOMOLOGOUS'          => 'GENE',
          );
        # We've done the DB hash...
        # So lets get on with the DNA, SYNTENY and GENE hashes;
	        my $q = qq{select ml.type, gd1.name, gd2.name from genome_db gd1, genome_db gd2, species_set ss1, species_set ss2 , method_link ml, method_link_species_set mls1, method_link_species_set mls2 where mls1.method_link_species_set_id = mls2.method_link_species_set_id and ml.method_link_id = mls1.method_link_id and ml.method_link_id = mls2.method_link_id and gd1.genome_db_id != gd2.genome_db_id and mls1.species_set_id = ss1.species_set_id and mls2.species_set_id = ss2.species_set_id and ss1.genome_db_id = gd1.genome_db_id and ss2.genome_db_id = gd2.genome_db_id};

        my $sth = $dbh->prepare( $q );
        my $rv  = $sth->execute || die( $sth->errstr );
        my $results = $sth->fetchall_arrayref();
    
        if( $SiteDefs::ENSEMBL_SITETYPE eq 'Vega' ) {
			my %config;

## add list of self compared species and genomic analyses for vega self compara.
			$q = "select ml.type, gd.name, gd.name, count(*) as count
                  from method_link_species_set as mls, method_link as ml, species_set as ss, genome_db as gd 
                 where mls.species_set_id = ss.species_set_id
                   and ss.genome_db_id = gd.genome_db_id 
                   and mls.method_link_id = ml.method_link_id
                 group by mls.method_link_species_set_id, mls.method_link_id
                having count = 1";
			$sth = $dbh->prepare( $q );
			$rv  = $sth->execute || die( $sth->errstr );
			my $v_results = $sth->fetchall_arrayref();
			foreach my $config (@$v_results) {
				pop @$config;
				push @$results,$config;
			}

			my $file_name = 'Multi.config';
			#get the stored data structure
			if (-e $file_name) {
				print "retrieving vega alignment data from $file_name";
				%config = %{lock_retrieve($file_name)};
			}
			else {
				print "parsing vega compara database for alignment details";
## get details of all genomic alignments in Vega self compara 
				$q = "select ga.genomic_align_block_id, ml.type,
                       ga.method_link_species_set_id, df.name as chr,
                       ga.dnafrag_start as start, ga.dnafrag_end as stop,
                       gdb.name as species
                  from genomic_align ga, dnafrag df, genome_db gdb,
                       method_link_species_set mlss, method_link ml
                 where ga.dnafrag_id = df.dnafrag_id and 
                       df.genome_db_id = gdb.genome_db_id and
                       ga.method_link_species_set_id = mlss.method_link_species_set_id and
                       mlss.method_link_id = ml.method_link_id
                 order by genomic_align_block_id";
				$sth = $dbh->prepare( $q );
				$rv  = $sth->execute || die( $sth->errstr );
				my ($gabid,$type,$mlssid,$chr,$start,$stop,$species);
				my ($old_gabid,$old_species,$old_chr,$old_start,$old_stop,@old_ids);
				## create data structure containing summary of all genomic analyses in a self-compara
				while( ($gabid,$type,$mlssid,$chr,$start,$stop,$species) = $sth->fetchrow_array ) {
					next unless $type eq 'BLASTZ_RAW';
					my $id = $gabid.$mlssid.$chr.$species;
					next if (grep {$id eq $_ } @old_ids);
					if( $old_gabid eq $gabid ) {
						$species =~ s/ /_/;
						push @{$config{$species}{$old_species}},[$chr,$old_chr]       unless grep {$_->[0] eq $chr && $_->[1] eq $old_chr} @{$config{$species}{$old_species}};
						push @{$config{$old_species}{$species}},[$old_chr,$chr]       unless grep {$_->[0] eq $old_chr && $_->[1] eq $chr} @{$config{$old_species}{$species}};          
						$config{$species}{'regions'}{$chr}{'last'}= $stop             unless $config{$species}{'regions'}{$chr}{'last'} > $stop;
						$config{$old_species}{'regions'}{$old_chr}{'last'}= $old_stop unless $config{$old_species}{'regions'}{$old_chr}{'last'} > $old_stop;
						if( defined $config{$species}{'regions'}{$chr}{'first'} ) { 
							$config{$species}{'regions'}{$chr}{'first'}= $start unless ($config{$species}{'regions'}{$chr}{'first'} < $start);
						} else {
							$config{$species}{'regions'}{$chr}{'first'}= $start;
						}
						if( defined $config{$old_species}{'regions'}{$old_chr}{'first'} ) {
							$config{$old_species}{'regions'}{$old_chr}{'first'}= $old_start unless ($config{$old_species}{'regions'}{$old_chr}{'first'} < $old_start);
						} else {
							$config{$old_species}{'regions'}{$old_chr}{'first'}= $old_start;
						}
						push @old_ids, $id;
					} else {
						@old_ids     = ();
						$species     =~ s/ /_/;
						$old_species = $species;
						$old_gabid   = $gabid;
						$old_chr     = $chr;
						$old_stop    = $stop;
						$old_start   = $start;
					}
					push @old_ids, $id;
				}
				lock_nstore(\%config,$file_name);
			}
			$tree->{'VEGA_BLASTZ_CONF'} = \%config;
		}
		
        foreach my $row ( @$results ) {
          my ( $species1, $species2 ) = ( $row->[1], $row->[2] );
          $species1 =~ tr/ /_/;
          $species2 =~ tr/ /_/;
          my $KEY = $sections{uc($row->[0])} || uc( $row->[0] );
          $tree->{$KEY}{$species1}{$species2} = exists( $CONF->{'_storage'}{$species1}) ? 1 : 0;
        }
        $sth->finish();
        $dbh->disconnect();
      }
      print STDERR "          [INFO]Writing MULTI\n";
      delete $tree->{'general'};
      $CONF->{'_multi'} = $tree;
      $CONF->{'_storage'}{'Multi'} = $tree;
#	  warn(Dumper($tree->{VEGA_BLASTZ_CONF}));
#      warn(Dumper($CONF->{_multi}->{'ALIGNMENTS'}));
      next;
  }
## Move anything in the general section over up to the top level
## For each trace database look for non-default config..
## For each das source get its contact information.
    my @das_keys = qw( ENSEMBL_INTERNAL_DAS_SOURCES ENSEMBL_TRACK_DAS_SOURCES );
    my $key_count = {};
    foreach my $das_key( @das_keys ){
      my $das_conf = $tree->{$das_key};
      next unless ref( $das_conf ) eq 'HASH';
      foreach my $das_source( keys %$das_conf ){
        if( ! $das_conf->{$das_source} ){ # Source explicitly disabled
          delete $das_conf->{$das_source};
          next;
        }

# Check if the source is based on the current assembly
	if (defined(my $assembly = $tree->{$das_source}->{assembly})) {
	    if ($assembly ne $tree->{ENSEMBL_GOLDEN_PATH}) {
		delete $das_conf->{$das_source};
		next;
	    }
	}

        my $das_source_conf = $tree->{$das_source};
        ref( $das_source_conf ) eq 'HASH' or $das_source_conf = {};
        if( ! exists($das_source_conf->{'assembly'}) || $das_source_conf->{'assembly'} eq $tree->{'ENSEMBL_GOLDEN_PATH'} ) {
          $das_source_conf->{'retrieve_features'} = 1;
          $das_source_conf->{'name'} = $das_source;
          $das_conf->{$das_source} = $das_source_conf; # Substitute conf
        } else {
          delete( $das_conf->{$das_source} );
        }
        delete $tree->{$das_source};
      }
    }
############### Database config prepared 
######### Store the table sizes for each database
    my @databases = keys( %{$tree->{'databases'}} );

####### Connect and store database sizes...
    foreach my $database( @databases ){
      my $dbh = $self->db_connect( $tree, $database );
      unless($dbh) {
        warn( "\t  [DB] Unable to connect to ",ref($database)eq'HASH' ? $database->{'NAME'} : $database);
        $tree->{'databases'}{$database} = undef;
        next;
      }
	  my $q = "show table status";
      my $sth = $dbh->prepare( $q ) || next;
      my $rv  = $sth->execute()     || next;
      my $data = $sth->fetchall_arrayref({'Name'=>1,'Rows'=>1});
      foreach( @{$data} ){
        my $table = $_->{'Name'};
        my $rows  = $_->{'Rows'};
        $tree->{TABLE_SIZE}->{$database}->{$table} = $rows;
      }
      $sth->finish();

      $dbh->disconnect();
    }
    ###### Additional implicit data #
    ## ENSEMBL WEBSITE
    if( $tree->{'databases'}->{'ENSEMBL_WEBSITE'} ){
      if( my $dbh = $self->db_connect( $tree, 'ENSEMBL_WEBSITE' ) ) {
	      my $sql = qq(
          SELECT
                r.release_id    as release_id,
                DATE_FORMAT(r.date, '%b %Y') as short_date
          FROM
                ens_release r order by r.release_id desc);

	      # Store in conf.packed
	      $tree->{RELEASE_INFO} = [];
	      my $query = $dbh->prepare($sql);
        $query->execute;
	      while (my $row = $query->fetchrow_hashref) {
	        push @{ $tree->{'RELEASE_INFO'} }, $row ;
	      }
      }
    }

    $common = $tree;

## CORE DATABASE....
    $tree->{'REPEAT_TYPES'} = {};
    if( $tree->{'databases'}->{'ENSEMBL_DB'} ){ 
      if( my $dbh = $self->db_connect( $tree, 'ENSEMBL_DB' ) ) {

## Query the analysis table to provide feature switches
        my $sql = qq(SELECT logic_name FROM analysis);
        my $query = $dbh->prepare($sql);
        $query->execute;
          while (my $row = $query->fetchrow_arrayref) {
            $tree->{'DB_FEATURES'}{uc($row->[0])}=1;
          }
## Compute the length of the maximum chromosome. 
## Used to scale figures

### STICKLEBACK BUG FIX... 'group' in ickleback is really 'chromosome' so
### we need a minor hack to the calculation of the longest 'chromosome'
### REMOVE THE (or cs.name = 'group') where stickleback is fixed.

          $sql   = qq(
          select sr.name, sr.length 
            from seq_region as sr, coord_system as cs 
           where ( cs.name = 'chromosome' or cs.name = 'group' ) and cs.coord_system_id = sr.coord_system_id 
           order by sr.length
            desc limit 1);
          $query = $dbh->prepare($sql);
          if($query->execute()>0) {
            my @T = $query->fetchrow_array;
            $tree->{'MAX_CHR_NAME'}   = $T[0];
            $tree->{'MAX_CHR_LENGTH'} = $T[1];
          } else {
            $tree->{'MAX_CHR_NAME'}   = undef;
            $tree->{'MAX_CHR_LENGTH'} = 0;
          }  
                    
## Misc feature sets....
          $sql   = qq(
            select distinct(ms.code)
              from misc_set as ms, misc_feature_misc_set as mfms 
             where ms.misc_set_id = mfms.misc_set_id    
          );
          $query = $dbh->prepare($sql);
          eval {
            $query->execute;
            while (my $row = $query->fetchrow_arrayref ){
              $tree->{'DB_FEATURES'}{"MAPSET_".uc($row->[0])}=1;
            }
          };
## Affy probe sets...
          $sql   = qq(
            select distinct(aa.name)
              from oligo_array as aa, oligo_probe as ap
             where aa.oligo_array_id = ap.oligo_array_id
          );
          $query = $dbh->prepare($sql);
          eval {
            $query->execute;
            while (my $row = $query->fetchrow_arrayref ){
              $tree->{'OLIGO'}{$row->[0]} = 1;
              ( my $key = uc("OLIGO_$row->[0]") ) =~ s/\W/_/;
              $tree->{'DB_FEATURES'}{$key} = 1;
            }
          };
## Regulatory features...

## Interpro switch
          $sql   = qq(SELECT id FROM interpro LIMIT 1);
          $query = $dbh->prepare($sql);
          $tree->{'DB_FEATURES'}{INTERPRO} = 1 if $query->execute() > 0;
          $query->finish();
## Marker features 
          $sql   = qq(SELECT * FROM marker_feature LIMIT 1);
          eval{
            $query = $dbh->prepare($sql);
            $tree->{'DB_FEATURES'}{MARKERS} = 1 if $query->execute() > 0;
            $query->finish();
          };
## Repeat classifications
          $sql   = qq(SELECT distinct repeat_type FROM repeat_consensus );
          eval {
            $query = $dbh->prepare($sql);
            if($query->execute()>0) {
              foreach(@{$query->fetchall_arrayref}) {
                $tree->{'REPEAT_TYPES'}{$_->[0]}=1;
              }
            } 
            $query->finish();
          };
## for annotated datasets (e.g. Vega)
          if( $tree->{'TABLE_SIZE'}->{'ENSEMBL_DB'}->{'author'} ) {
## authors by chromosome
            $sql = qq(
                SELECT distinct(a.logic_name)
                FROM gene g, analysis a
                WHERE g.analysis_id = a.analysis_id
            );
            $query = $dbh->prepare($sql);
            eval { 
              $query->execute;
              while( my $row = $query->fetchrow_arrayref) {
                $tree->{'DB_FEATURES'}->{uc("VEGA_GENES_$row->[0]")} = 1;
              }
            };
          }

          ## alternative assembly
          if ($tree->{'ALTERNATIVE_ASSEMBLY'}) {
            my $alt_ass = $tree->{'ALTERNATIVE_ASSEMBLY'};
            $sql   = qq(
                SELECT * FROM seq_region sr, coord_system cs
                WHERE sr.coord_system_id = cs.coord_system_id
                AND cs.name = 'chromosome'
                AND cs.version = '$alt_ass'
                LIMIT 1
            );
            eval{
              $query = $dbh->prepare($sql);
              $tree->{'DB_FEATURES'}->{'ALTERNATIVE_ASSEMBLY'} = 1 if $query->execute() > 0;
              $query->finish();
            };

            # if you can't find this in core, look in the Vega db
			unless ($tree->{'DB_FEATURES'}->{'ALTERNATIVE_ASSEMBLY'}) {
              if( my $vega_dbh = $self->db_connect($tree, 'ENSEMBL_VEGA')) {
                eval{
                  $query = $vega_dbh->prepare($sql);
                  $tree->{'DB_FEATURES'}->{'ALTERNATIVE_ASSEMBLY'} = 1 if $query->execute() > 0;
                  $query->finish();
                };
		      }
            }
			warn ("No alternative assembly found") unless ($tree->{'DB_FEATURES'}->{'ALTERNATIVE_ASSEMBLY'});
          }
          
          $dbh->disconnect();

          print STDERR ( "\t  [INFO] Species $filename OK\n" );
        }
      }

      foreach my $T_DB (qw(ENSEMBL_VEGA ENSEMBL_OTHERFEATURES)) {
        if( $tree->{'databases'}->{$T_DB} ) {
          if( my $dbh = $self->db_connect( $tree, $T_DB ) ) {
          my $sql = qq(select distinct(logic_name) from analysis);
          my $query = $dbh->prepare($sql);
          eval {
            $query->execute;
            while( my $row = $query->fetchrow_arrayref) {
              $tree->{'DB_FEATURES'}{uc("$T_DB.$row->[0]")} = 1;
            }
          };
        }
      }
    }
## VARIATION DATABASE 
    if( $tree->{'databases'}->{'ENSEMBL_VARIATION'} ){ # Then SNP is configured
      if( my $dbh = $self->db_connect( $tree, 'ENSEMBL_VARIATION' ) ){

	# Sources for TSV, SNPView, GSV
        my $sql = qq(SELECT name FROM source  );
        my $sth = $dbh->prepare( $sql );
	eval {
	  $sth->execute;
	  while( my $row = $sth->fetchrow_arrayref) {
	    $tree->{'VARIATION_SOURCES'}{"$row->[0]"} = 1;
	  }
	};
        $sth->finish();

	# For yellow menu bar link to TSV
 	$sth = $dbh->prepare(qq(
                     SELECT count(*) 
                     FROM meta 
                     WHERE meta_key = "individual.default_strain";
                  )
 			    );
 	eval {
 	  $sth->execute;
 	  my ($count) = $sth->fetchrow_array;
 	  if ( $count ) {
 	    $tree->{'VARIATION_STRAIN'} = $count;
 	  }
 	};

        # For LDview link
        $sth = $dbh->prepare(qq(
                     SELECT count(*)
                     FROM meta
                     WHERE meta_key = "pairwise_ld.default_population";
                  )
                            );
        eval {
          $sth->execute;
          my ($count) = $sth->fetchrow_array;
          if ( $count ) {
            $tree->{'VARIATION_LD'} = $count;
          }
        };


	$sth->finish();
	$dbh->disconnect();
      }
    }

############### Implicit data retrieved
###### Update object with species config
    $CONF->{'_storage'}{$filename} = $tree;
  }
  ## Tidy up 'Common'
  $common->{'SPECIES_BIO_NAME'} = '';
  $common->{'SPECIES_COMMON_NAME'} = '';
  $CONF->{'_storage'}{'common'} = $common;
  print STDERR "-" x 78, "\n";
  return 1;
}

sub DESTROY { }


sub anyother_species {
  ### DEPRECATED - use get_config instead
  my ($self, $var) = @_;
  my( $species ) = keys %{$CONF->{'_storage'}};
  return $self->get_config( $species, $var );
}
sub other_species {
  ### DEPRECATED - use get_config instead
  my ($self, $species, $var) = @_;
  return $self->get_config( $species, $var );
}

sub multidb {
  ### a
  my $self = shift;
  return $CONF->{'_multi'} && $CONF->{'_multi'}{'databases'};
}

sub multi {
  ### a
  ### Arguments: configuration type (string), species name (string)
  my( $self, $type, $species ) = @_;
  $species ||= $ENV{'ENSEMBL_SPECIES'};
  return $CONF->{'_multi'} && $CONF->{'_multi'}{$type} && $CONF->{'_multi'}{$type}{$species} ? %{$CONF->{'_multi'}{$type}{$species}} : ();
}

sub multiX {
  ### a
  ### Arguments: configuration type (string)
  my( $self, $type ) = @_;
  return $CONF->{'_multi'} && $CONF->{'_multi'}{$type} ? %{$CONF->{'_multi'}{$type}} : ();
}

sub db_connect {
  ### Connects to the specified database 
  ### Arguments: configuration tree (hash ref), database name (string)
  ### Returns: DBI database handle
  my $self    = shift;
  my $tree    = shift @_ || die( "Have no data! Can't continue!" );
  my $db_name = shift @_ || confess( "No database specified! Can't continue!" );

  my $dbname  = $tree->{'databases'}->{$db_name}{'NAME'};
  if($dbname eq '') {
    warn( "No database name supplied for $db_name." );
    return undef;
  }

  #warn "Connecting to $db_name";
  my $dbhost  = $tree->{'databases'}->{$db_name}{'HOST'};
  my $dbport  = $tree->{'databases'}->{$db_name}{'PORT'};
  my $dbuser  = $tree->{'databases'}->{$db_name}{'USER'};
  my $dbpass  = $tree->{'databases'}->{$db_name}{'PASS'};
  my $dbdriver= $tree->{'databases'}->{$db_name}{'DRIVER'};
  my ($dsn, $dbh);
  eval {
    if( $dbdriver eq "mysql" ) {
      $dsn = "DBI:$dbdriver:database=$dbname;host=$dbhost;port=$dbport";
      $dbh = DBI->connect(
        $dsn,$dbuser,$dbpass, { 'RaiseError' => 1, 'PrintError' => 0 }
      );
    } elsif ( $dbdriver eq "Oracle") {
      $dsn = "DBI:$dbdriver:";
      my  $userstring = $dbuser . "\@" . $dbname;
      $dbh = DBI->connect(
        $dsn,$userstring,$dbpass, { 'RaiseError' => 1, 'PrintError' => 0 }
      ); 
    } elsif ( $dbdriver eq "ODBC") {
      $dsn = "DBI:$dbdriver:$dbname";
      $dbh = DBI->connect(
        $dsn, $dbuser, $dbpass,
        {'LongTruncOk' => 1,
         'LongReadLen' => 2**16 - 8,
         'RaiseError' => 1,
         'PrintError' => 0,
         'odbc_cursortype' => 2}
      );
    } else {
      print STDERR "\t  [WARN] Can't connect using unsupported DBI driver type: $dbdriver\n";
    }
  };

  if( $@ ) {
    print STDERR "\t  [WARN] Can't connect to $db_name\n", "\t  [WARN] $@";
    return undef();
  } elsif( !$dbh ) {
    print STDERR ( "\t  [WARN] $db_name database handle undefined\n" );
    return undef();
  }
  return $dbh;
}

sub db_connect_multi_species {
  ### Wrapper for db_connect, for use with multispecies configurations
  ### Arguments: database name (string)
  ### Returns: DBI database handle
  my $db_name = shift || die( "No database specified! Can't continue!" );
  
  my $self = EnsEMBL::Web::SpeciesDefs->new();
  
  my $tree = $CONF->{_multi} || die( "No multispecies DB config found!" );
  warn "... $tree ... $db_name ...";
  return $self->db_connect( $tree, $db_name );
}


sub get_table_size{
### Accessor function for table size,
### Arguments: hashref: {-db => 'database' (e.g. 'ENSEMBL_DB'), 
###                      -table =>'table name' (e.g. 'feature' ) }
###            species name (string)
### Returns: Number of rows in the table

## Get/check args
  my $self    = shift;
  my $hashref = shift;
  my $species = shift;

  if( ref( $hashref ) ne 'HASH' ){
    warn( "Argument must be a hashref!" );
    return undef();
  }
  my $database = $hashref->{-db};
  unless( $database ){
    warn( "Usage: { -db=>'database', -table=>'table name' }" );
    return undef();
  }
  my $table = $hashref->{-table};
  unless( $table ){
    warn( "Usage: { -db=>'database', -table=>'table name' }" );
    return undef();    
  }

## Got the correct args, send back what we find in the configuration
  my $table_size = $self->other_species( $species||$ENV{'ENSEMBL_SPECIES'}, 'TABLE_SIZE' );

  return undef unless $table_size;
  return undef unless exists( $table_size->{$database} );
  return $table_size->{$database}->{$table};
} 

sub set_write_access {
  ### sets a given database adaptor to write access instead of read-only
  ### Arguments: database type (e.g. 'core'), species name (string)
  ### Returns: none
  my $self = shift;
  my $type = shift;
  my $species = shift || $ENV{'ENSEMBL_SPECIES'} || $ENSEMBL_PRIMARY_SPECIES;
  if( $type =~ /ENSEMBL_(\w+)/ ) {
## If the value is defined then we will create the adaptor here...
    my $key = $1;
## Hack because we map ENSEMBL_DB to 'core' not 'DB'....
    my $group = $key eq 'DB' ? 'core' : lc( $key );
    my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($species,$group)->dbc;
    my $db_ref = $self->databases;
    $db_ref->{$type}{'USER'} = $self->ENSEMBL_WRITE_USER;
    $db_ref->{$type}{'PASS'} = $self->ENSEMBL_WRITE_PASS;
    Bio::EnsEMBL::Registry->change_access(
      $dbc->host,$dbc->port,$dbc->username,$dbc->dbname,
      $db_ref->{$type}{'USER'},$db_ref->{$type}{'PASS'}
    );
  }
}

sub create_martRegistry {
  ### Creates mart registry (XML)
  ### Returns: registry content (string)
  my $self = shift;
  my $multi = $CONF->{'_multi'};
  warn "@{[keys %{$multi->{'databases'}}]}";
  my $reg = '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE MartRegistry>
<MartRegistry>';

  foreach my $mart ( sort keys %{$multi->{'marts'}} ) {
    my( $default, $visible, @name ) = @{$multi->{'marts'}->{$mart}};
    if( $multi->{'databases'}->{$mart} ) {
      my $T = $multi->{'databases'}->{$mart};
      $reg .= sprintf( '
<MartDBLocation
   databaseType = "%s"
       database = "%s"
           name = "%s"
         schema = "%s"
           host = "%s"
           port = "%s"
           user = "%s"
       password = "%s"
    displayName = "%s"
        visible = "%s"
        default = "%s"
       martUser = ""
includeDatasets = ""
/>',
        $T->{DRIVER}, $T->{NAME},   $mart,  $T->{NAME}, $T->{HOST}, $T->{PORT},
        $T->{USER},   $T->{PASS},   "@name", $visible?1:'', $default?1:''
      );
    }
  }
  $reg .= "\n</MartRegistry>\n";
#  warn $reg;
  return $reg;
}

sub dump {
  ## Diagnostic function!! 
  my ($self, $FH, $level, $Q) = @_;
  foreach (sort keys %$Q) {
    print $FH "    " x $level, $_;
    if( $Q->{$_} =~/HASH/ ) {
      print $FH "\n";
      $self->dump( $FH, $level+1, $Q->{$_} );    
    } elsif( $Q->{$_} =~/ARRAY/ ) {
      print $FH " = [ ", join( ', ',@{$Q->{$_}} )," ]\n";
    } else {
      print $FH " = $Q->{$_}\n";
    }
  }
}


sub translate {
  ### Dictionary functionality (not currently used)
  ### Arguments: word to be translated (string)
  ### Returns: translated word (string) or original word if not found
  my( $self, $word ) = @_;
  return $word unless $self->ENSEMBL_DICTIONARY;  
  return $self->ENSEMBL_DICTIONARY->{$word}||$word;
}


sub all_search_indexes {
  ### a
  my %A = map { $_, 1 } map { @{ $CONF->{_storage}{$_}{ENSEMBL_SEARCH_IDXS}||[] } } keys %{$CONF->{_storage}};
  return sort keys %A;
}

##############################################################################
## Additional parsing / creation codes...

sub create_robots_txt {
  ### This is to try and stop search engines killing e! - it gets created each
  ### time on server startup and gets placed in the first directory in the htdocs
  ### tree.
  ### Returns: none
  my $self = shift;
  my $root = $ENSEMBL_HTDOCS_DIRS[0];
  if( open FH, ">$root/robots.txt" ) { 
    print FH qq(
User-agent: *
Disallow: /Multi/
Disallow: /BioMart/
);
    foreach( @$ENSEMBL_SPECIES ) { 
      print FH qq(Disallow: /$_/\n);
      print FH qq(Allow: /$_/geneview\n);
      print FH qq(Allow: /$_/sitemap.xml.gz\n);
    }
print FH qq(

User-Agent: W3C-checklink
Disallow:
);
    close FH;
  } else {
    warn "Unable to creates robots.txt file in $root-robots";
  }
}

sub bread_crumb_creator {
  ### Create the breadcrumbs hash, which is used to autogenerate navigation in the static content.
  ### The hash is stored in the cached config to speed up rendering of bread-crumbs in web-pages.
  ###
  ### This method loops through all htdocs trees looking for index files to grab the "navigation"
  ### meta tag from...
  my $self = shift;
  my @dirs = ( '/' );
  my $ENSEMBL_BREADCRUMBS = {};
  local( $/ ) = undef;
  while( scalar(@dirs) ) {
    my %dirs2 = ();
    foreach my $dir ( @dirs ) {
      foreach my $root ( @ENSEMBL_HTDOCS_DIRS ) {
#       warn "$root - $dir - index.html";
        my $fn = $root.$dir.'index.html';
        if( -e $fn ) {
          open I, $fn;
          my $content = <I>;
          my($nav) = $content =~ /<meta\s+name\s*=\s*"navigation"\s+content\s*=\s*"([^"]+)"\s*\/?>/ism;
          $nav   ||= $content =~ /<meta\s+content\s*=\s*"([^"]+)"\s+name\s*=\s*"navigation"\s*\/?>/ism;
#          warn ">>> $dir -> $nav";
          if( !$nav && $dir =~ /\/(\w+)\/$/ ) {
            #$nav = join ' ', map ucfirst( $_ ), split /_/, $1;
            $nav = join ' ', split /_/, $1;
          }
          my($title) = $content =~ /<title>([^<]+)<\/title>/ism;
          if( $nav ) {
            $ENSEMBL_BREADCRUMBS->{ $dir } = [ $nav , $title ] if $nav;
            $dirs2{$dir} = 1;
			last;
          }
        }
      }
    }
    @dirs = sort keys %dirs2;
    %dirs2 = ();
    foreach my $root ( @ENSEMBL_HTDOCS_DIRS ) {
      foreach my $dir ( @dirs ) {
        next unless -d $root.$dir;
        opendir( DH, $root.$dir );
        while( my $d = readdir(DH) ) {
          next if $d eq '.' || $d eq '..' || $d eq 'CVS';
          next unless -d $root.$dir.$d;
          $dirs2{$dir.$d.'/'} =1;
        }
      }
    }
    @dirs = sort keys %dirs2;
  }
  my $ENSEMBL_PARENTS  = {};
  my $ENSEMBL_CHILDREN = {};
  foreach (sort keys %$ENSEMBL_BREADCRUMBS) {
    (my $P = $_ ) =~ s/\/[^\/]+\/$/\//;
    unless( $P eq $_ ) {
      push @{ $ENSEMBL_CHILDREN->{ $P } }, $_;
      $ENSEMBL_PARENTS->{$_} = $P;
    }
  }
  return( {
    'ENSEMBL_BREADCRUMBS' => $ENSEMBL_BREADCRUMBS,
    'ENSEMBL_PARENTS'     => $ENSEMBL_PARENTS, 
    'ENSEMBL_CHILDREN'    => $ENSEMBL_CHILDREN
  } );
}

sub _is_available_artefact{
  ### Checks to see if a given artefact is available (or not available)
  ### in the stored configuration for a particular species
  ### Arguments: species name (defaults to the current species), 
  ###   artefact to check for (string - artefact type and id, space separated)
  ### Returns: boolean
  my $self     = shift;
  my $def_species  = shift || $ENV{'ENSEMBL_SPECIES'};
  my $available = shift;

  my @test = split( ' ', $available );
  if( ! $test[0] ){ return 999; } # No test found - return pass.

  ## Is it a positive (IS) or a negative (IS NOT) check?
  my( $success, $fail ) = ($test[0] =~ s/^!//) ? ( 0, 1 ) : ( 1, 0 );

  if( $test[0] eq 'database_tables' ){ ## Then test using get_table_size
    my( $database, $table ) = split( '\.', $test[1] );
    return $self->get_table_size(
          { -db    => $database, -table => $table },
          $def_species
      ) ? $success : $fail;
  } elsif( $test[0] eq 'multi' ) { ## Is the traces database specified?
    my( $type,$species ) = split /\|/,$test[1],2;
    my %species = $self->multi($type, $def_species);
    return $success if exists( $species{$species} );
    return $fail;
  } elsif( $test[0] eq 'multialignment' ) { ## Is the traces database specified?
    my( $alignment_id ) = $test[1];
    my %alignment = $self->multi('ALIGNMENTS', $alignment_id);
    return $success if (scalar(keys %alignment));
    return $fail;
  } elsif( $test[0] eq 'database_features' ){ ## Is the given database specified?
    my $ft = $self->other_species($def_species,'DB_FEATURES') || {};
    my @T = split /\|/, $test[1];
    my $flag = 1;
    foreach( @T ) {
      $flag = 0 if $ft->{uc($_)};
    }
    return $fail if $flag;
    return $success;
  } elsif( $test[0] eq 'databases' ){ ## Is the given database specified?
    my $db = $self->other_species($def_species,'databases')  || {};
    return $fail unless $db->{$test[1]}       ;
    return $fail unless $db->{$test[1]}{NAME} ;
    return $success;
  } elsif( $test[0] eq 'features' ){ ## Is the given db feature specified?
    my $ft = $self->other_species($def_species,'DB_FEATURES') || {};
    my @T = split /\|/, $test[1];
    my $flag = 1;
    foreach( @T ) {
      $flag = 0 if $ft->{uc($_)};
    }
    return $fail if $flag;
    return $success;
  } elsif( $test[0] eq 'any_feature' ){ ## Are any of the given db features specified?
    my $ft = $self->other_species($def_species,'DB_FEATURES') || {};
    shift @test;
    foreach (@test) {
      return $success if $ft->{uc($_)};
    }
    return $fail;
  } elsif( $test[0] eq 'species_defs') {
    return $self->other_species($def_species,$test[1]) ? $success : $fail;
  } elsif( $test[0] eq 'species') {
    if(Bio::EnsEMBL::Registry->get_alias($def_species,"no throw") ne Bio::EnsEMBL::Registry->get_alias($test[1],"no throw")){
      return $fail;
    }
  } elsif( $test[0] eq 'das_source' ){ ## Is the given DAS source specified?
    my $source = $self->ENSEMBL_INTERNAL_DAS_SOURCES || {};
    return $fail unless $source->{$test[1]}   ;
    return $success;
  }

  return $success; ## Test not found - pass anyway to prevent borkage!
}

1;
