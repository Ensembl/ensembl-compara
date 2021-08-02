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

package EnsEMBL::Web::SpeciesDefs;

### SpeciesDefs - Ensembl web configuration accessor

### This module provides programatic access to the web site configuration
### data stored in the $ENSEMBL_WEBROOT/conf/*.ini (INI) files. See
### $ENSEMBL_WEBROOT/conf/ini.README for details.

### Owing to the overhead implicit in parsing the INI files, two levels of
### caching (memory, filesystem) have been implemented. To update changes
### made to an INI file, the running process (e.g. httpd) must be halted,
### and the $ENSEMBL_WEBROOT/conf/config.packed file removed. In the
### absence of a cache, the INI files are automatically parsed at
### object instantiation. In the case of the Ensembl web site, this occurs
### at server startup via the $ENSEMBL_WEBROOT/conf/perl.startup
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
###  my $sp_name = $speciesdefs->get_config('Homo_sapiens','SPECIES_DISPLAY_NAME');

###  # Alternative setting getter - uses autoloader
###  my $sp_bio_name = $speciesdefs->SPECIE_%S_SCIENTIFIC_NAME('Homo_sapiens');

###  # Can also use the ENSEMBL_SPECIES environment variable
###  ENV{'ENSEMBL_SPECIES'} = 'Homo_sapiens';
###  my $sp_bio_name = $speciesdefs->SPECIES_SCIENTIFIC_NAME;

###  # Getting a parameter with multiple values
###  my( @chromosomes ) = @{$speciesdefs->ENSEMBL_CHROMOSOMES};

use strict;
use warnings;
no warnings "uninitialized";

use SiteDefs;

use Carp qw(cluck);
use Data::Dumper;
use DBI;
use File::Spec;
use Hash::Merge qw(merge);
use Storable qw(lock_nstore lock_retrieve thaw);
use Time::HiRes qw(time);
use Fcntl qw(O_WRONLY O_CREAT);
use JSON;
use Try::Tiny;

use Sys::Hostname::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);
use Bio::EnsEMBL::Utils::Exception qw(verbose);
use Bio::EnsEMBL::DBSQL::DataFileAdaptor;

use EnsEMBL::Web::ConfigPacker;
use EnsEMBL::Web::Tools::WebTree;
use EnsEMBL::Web::Tools::RobotsTxt;
use EnsEMBL::Web::Tools::OpenSearchDescription;
use EnsEMBL::Web::Tools::Registry;
use EnsEMBL::Web::Tools::MartRegistry;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

our $CONFIG_QUIET = 0; # Set to 1 by scripts to remove natter

use base qw(EnsEMBL::Web::Root);

our $AUTOLOAD;
our $CONF;

sub new {
  ### c
  my $class = shift;

  verbose($SiteDefs::ENSEMBL_API_VERBOSITY);

  my $self = bless({
    _start_time => undef,
    _last_time  => undef,
  }, $class);

  my $write_dir = $SiteDefs::ENSEMBL_SYS_DIR.'/conf';
  my $conffile = "$write_dir/$SiteDefs::ENSEMBL_CONFIG_FILENAME";
  
  $self->{'_conf_dir'} = $write_dir;
  $self->{'_filename'}  = $conffile;

  my @params = qw/ph g h r t v sv m db pt rf ex vf svf fdb lrg vdb gt mr/;
  $self->{'_core_params'} = \@params;
  
  $self->parse unless $CONF;

  ## Diagnostic - sets up back trace of point at which new was
  ## called - useful for trying to track down where the cacheing
  ## is taking place
  $self->{'_new_caller_array'} = [];

  if (1) {
    my $C = 0;

    while (my @T = caller($C)) {
      $self->{'_new_caller_array'}[$C] = \@T;
      $C++;
    }
  }

  $self->{'_storage'} = $CONF->{'_storage'};

  return $self;
}

sub register_orm_databases {
  ## Registers ORM data sources (as present in ENSEMBL_ORM_DATABASES config) to be used with ensembl-orm API
  my $self  = shift;
  my $dbs   = {};

  if (dynamic_require('ORM::EnsEMBL::Rose::DbConnection', 1)) { # ignore if ensembl-orm doesn't exist

    $self->ENSEMBL_ORM_DATABASES->{'session'} = $self->session_db; # add session db to ORM

    while (my ($key, $value) = each %{$self->ENSEMBL_ORM_DATABASES}) {

      my $params = $value;
      if (!ref $params) {

        $params = $self->multidb->{$value} or warn "Database connection properties for '$value' could not be found in SiteDefs" and next;
        $params = {
          'database'  => $params->{'NAME'},
          'host'      => $params->{'HOST'} || $self->DATABASE_HOST,
          'port'      => $params->{'PORT'} || $self->DATABASE_HOST_PORT,
          'username'  => $params->{'USER'} || $self->DATABASE_WRITE_USER,
          'password'  => $params->{'PASS'} || $self->DATABASE_WRITE_PASS
        };
      }

      $params->{'type'} = $key;
      $dbs->{$key}      = ORM::EnsEMBL::Rose::DbConnection->register_database($params);
    }
  }

  return $dbs;
}

sub session_db {
  my $self = shift;
  my $db   = $self->multidb->{'DATABASE_SESSION'};

  return {
    'database'  => $db->{'NAME'},
    'host'      => $db->{'HOST'},
    'port'      => $db->{'PORT'},
    'username'  => $db->{'USER'} || $self->DATABASE_WRITE_USER,
    'password'  => $db->{'PASS'} || $self->DATABASE_WRITE_PASS
  };
}

sub core_params { return $_[0]->{'_core_params'}; }

sub name {
  ### a
  ### returns the name of the current species
  ## TO DO - rename method to 'species'

  return $ENV{'ENSEMBL_SPECIES'} || $SiteDefs::ENSEMBL_PRIMARY_SPECIES;
}

sub valid_species {
  ### Filters the list of species to those configured in the object.
  ### If an empty list is passes, returns a list of all configured species
  ### Returns: array of configured species names

  my $self          = shift;
  my %test_species  = map { $_ => 1 } @_;
  my @valid_species = @{$self->{'_valid_species'} || []};
  my %uniq_valid_species;

   if (!@valid_species) {
    foreach my $sp (@{$self->multi_hash->{'ENSEMBL_DATASETS'}}) { 
      my $config = $self->get_config($sp, 'DB_SPECIES');

      if ($config->[0]) {
        $uniq_valid_species{$_} = 1 foreach @{$config};
      } else {
        warn "Species $sp is misconfigured: please check generation of packed file";
      }
    }
    @valid_species = keys %uniq_valid_species;    
    $self->{'_valid_species'} = [ @valid_species ]; # cache the result
  }

  @valid_species = grep $test_species{$_}, @valid_species if %test_species; # Test arg list if required

  return @valid_species;
}


sub reference_species {
  ### Filters the list of species to reference only, i.e. no secondary strains 
  ### Returns: array of species names
  my $self          = shift;
  my %test_species  = map { $_ => 1 } @_;
  my @ref_species   = @{$self->{'_ref_species'} || []};

  if (!@ref_species) {
    my @valid_species = $self->valid_species;

    for (@valid_species) {
      my $strain = $self->get_config($_, 'SPECIES_STRAIN');
      if (!$strain || ($strain =~ /reference/) || !$self->get_config($_, 'STRAIN_GROUP')) {
        push @ref_species, $_;
      }
    }
  }

  @ref_species = grep $test_species{$_}, @ref_species if %test_species;

  return @ref_species;
}


sub species_full_name {
  ### a
  ### returns full species name from the short name
  
  my $self = shift;
  my $sp   = shift;
  
  return $SiteDefs::ENSEMBL_SPECIES_ALIASES->{$sp};
}

sub AUTOLOAD {
  ### a
  
  my $self    = shift;
  my $species = shift || $ENV{'ENSEMBL_SPECIES'} || $SiteDefs::ENSEMBL_PRIMARY_SPECIES;
  $species    = $SiteDefs::ENSEMBL_PRIMARY_SPECIES if $species eq 'Multi';
  
  my $var = our $AUTOLOAD;
  $var =~ s/.*:://;
  
  return $self->get_config($species, $var);
}

sub colour {
  ### a
  ### return the colour associated with the $key of $set colour set (or the whole hash associated reference);
  
  my ($self, $set, $key, $part) = @_;
  $part ||= 'default';
  
  return defined $key ? $self->{'_storage'}{'MULTI'}{'COLOURSETS'}{$set}{$key}{$part} : $self->{'_storage'}{'MULTI'}{'COLOURSETS'}{$set};
}

sub all_colours {
  my ($self,$set) = @_;
  return $self->{'_storage'}{'MULTI'}{'COLOURSETS'}{$set};
}

sub get_font_path {
  my $self = shift;
  my $path = $SiteDefs::GRAPHIC_TTF_PATH || ($self->ENSEMBL_STYLE || {})->{'GRAPHIC_TTF_PATH'};
  $path = $path ? $path =~ /^\// ? $path : $SiteDefs::ENSEMBL_SERVERROOT."/$path" : "/usr/local/share/fonts/ttfonts/";

  return $path =~ s/\/+/\//gr;
}

sub get_config {
  ## Returns the config value for a given species and a given config key
  ### Arguments: species name(string), parameter name (string)
  ### Returns:  parameter value (any type), or undef on failure
  
  my $self    = shift;
  my $species = shift;
  $species    = $SiteDefs::ENSEMBL_PRIMARY_SPECIES if $species eq 'common';
  
  my $var = shift || $species;

  if (defined $CONF->{'_storage'}) {
    return $CONF->{'_storage'}{$species}{$var} if exists $CONF->{'_storage'}{$species} &&
                                                  exists $CONF->{'_storage'}{$species}{$var};
    
    ## Try production name
    $species = $CONF->{'_storage'}{$species}{'SPECIES_PRODUCTION_NAME'} if exists $CONF->{'_storage'}{$species};

    if ($species) {
      return $CONF->{'_storage'}{$species}{$var} if exists $CONF->{'_storage'}{$species} &&
                                                    exists $CONF->{'_storage'}{$species}{$var};
    }
   
    return $CONF->{'_storage'}{$var} if exists $CONF->{'_storage'}{$var};
  }

  no strict 'refs';

  # undeclared param
  return undef unless grep { $_ eq $var } keys %{'SiteDefs::'};

  my $sym_name = "SiteDefs::$var";

  return ${$sym_name}  if defined ${$sym_name};
  return \@{$sym_name} if @{$sym_name};
  return undef;
}

sub set_config {
  ## Overrides the config value for a given config key
  ## @param Key name (string)
  ## @param Value (any)
  my ($self, $key, $value) = @_;

  $CONF->{'_storage'}{$key} = $value || undef if defined $CONF->{'_storage'};
}

sub set_species_config {
  ## Overrides the config value for a given species and a given config key
  ## @param species name (string)
  ## @param Key name (string)
  ## @param Value (any)
  my ($self, $species, $key, $value) = @_;
  $value ||= undef;
  
  $CONF->{'_storage'}{$species}{$key} = $value if defined $CONF->{'_storage'} && exists $CONF->{'_storage'}{$species};
}

sub retrieve {
  ### Retrieves stored configuration from disk
  ### Returns: boolean
  ### Exceptions: The filesystem-cache file cannot be opened
  
  my $self = shift;
  my $Q    = lock_retrieve($self->{'_filename'}) or die "Can't open $self->{'_filename'}: $!"; 
  
  $CONF->{'_storage'} = $Q if ref $Q eq 'HASH';
  return $CONF->{'_storage'}{'GENERATOR'} eq $SiteDefs::ENSEMBL_SERVER_SIGNATURE;
}

sub store {
  ### Creates filesystem-cache by storing config to disk. 
  ### Returns: boolean 
  ### Caller: perl.startup, on first (validation) pass of httpd.conf
  
  my $self = shift;

  $CONF->{'_storage'}{'GENERATOR'} = $SiteDefs::ENSEMBL_SERVER_SIGNATURE;

  die "[FATAL] Could not write to $self->{'_filename'}: $!" unless lock_nstore($CONF->{'_storage'}, $self->{'_filename'});
  return 1;
}

sub parse {
  ### Retrieves a stored configuration or creates a new one
  ### Returns: boolean
  ### Caller: $self->new when filesystem and memory caches are empty
  
  my $self = shift;
  
  $CONF = {};
  
  my $reg_conf = EnsEMBL::Web::Tools::Registry->new($CONF);

  $self->{'_start_time'} = time;
  $self->{'_last_time'}  = $self->{'_start_time'};
  
  if (!$SiteDefs::ENSEMBL_CONFIG_BUILD && -e $self->{'_filename'}) {
    warn " Retrieving conf from $self->{'_filename'}\n" unless $CONFIG_QUIET;
    if($self->retrieve) {
      $reg_conf->configure;
      return 1;
    }
    warn " conf was not generated here, regenerating\n";
  }
 
#  $self->_get_valid_urls; # under development
  $self->_parse;
  $self->store;
  $reg_conf->configure;

  EnsEMBL::Web::Tools::RobotsTxt::create($self->multi_hash->{'ENSEMBL_DATASETS'}, $self);
  EnsEMBL::Web::Tools::OpenSearchDescription::create($self);
  
  ## Set location for file-based data
  Bio::EnsEMBL::DBSQL::DataFileAdaptor->global_base_path($self->DATAFILE_BASE_PATH);
  
  $self->{'_parse_caller_array'} = [];
  
  my $C = 0;
  
  while (my @T = caller($C)) {
    $self->{'_parse_caller_array'}[$C] = \@T;
    $C++;
  }
}

sub _convert_date {
  ### Converts a date from a species database into a human-friendly format for web display 
  ### Argument: date in format YYYY-MM with optional -string attached
  ### Returns: hash ref {'date' => 'Mmm YYYY', 'string' => 'xxxxx'}
  
  my $date = shift;
  
  my %parsed;
  my @a        = ($date =~ /(\d{4})-(\d{2})-?(.*)/);
  my @now      = localtime;
  my $thisyear = $now[5] + 1900;
  my %months   = (
    '01' =>'Jan', '02' =>'Feb', '03' =>'Mar', '04' =>'Apr',
    '05' =>'May', '06' =>'Jun', '07' =>'July','08' =>'Aug',
    '09' =>'Sep', '10' =>'Oct', '11' =>'Nov', '12' =>'Dec'
  );
  
  my $year  = $a[0];
  my $mon   = $a[1];
  my $month = $mon && $mon < 13 ? $months{$mon} : undef;
  
  print STDERR "\t  [WARN] DATE FORMAT MAY BE REVERSED - parses as $mon $year\n" if $year > $thisyear || !$month;
  
  $parsed{'date'}   = "$month $year";
  $parsed{'string'} = $a[2];
  
  return \%parsed;
}


sub _load_in_webtree {
  ### Load in the contents of the web tree
  ### Check for cached value first
  
  my $self            = shift;
  my $web_tree_packed = File::Spec->catfile($self->{'_conf_dir'}, 'packed', 'web_tree.packed');
  my $web_tree        = { _path => '/info/' };
  
  if (-e $web_tree_packed) {
    $web_tree = lock_retrieve($web_tree_packed);
  } else {
    EnsEMBL::Web::Tools::WebTree::read_tree($web_tree, $_) for reverse @SiteDefs::ENSEMBL_HTDOCS_DIRS;
    
    lock_nstore($web_tree, $web_tree_packed);
  }
  
  return $web_tree;
}

sub _load_in_species_pages {
  ### Load in the static pages for each species 
  ### Check for cached value first
  my $self = shift;
  my $spp_tree_packed = File::Spec->catfile($self->{'_conf_dir'}, 'packed', 'spp_tree.packed');
  my $spp_tree        = { _path => '/' };
  
  if (-e $spp_tree_packed) {
    $spp_tree = lock_retrieve($spp_tree_packed);
  } else {
    EnsEMBL::Web::Tools::WebTree::read_species_dirs($spp_tree, $_, $SiteDefs::PRODUCTION_NAMES) for reverse @SiteDefs::ENSEMBL_HTDOCS_DIRS;
    lock_nstore($spp_tree, $spp_tree_packed);
  }
  
  return $spp_tree;
}

sub _load_in_taxonomy_division {
  my ($self) = @_;
  my $filename = $SiteDefs::ENSEMBL_TAXONOMY_DIVISION_FILE;
  my $json_text = do {
    open(my $json_fh, "<", $filename)
      or die("Can't open $filename: $!\n");
    local $/;
    <$json_fh>
  };
  my $json = JSON->new;
  my $data;
  try{
    $data = $json->decode($json_text);
  }
  catch {
    die "JSON decode error: $filename \n $_";
  };
  return $data;
}

sub _read_species_list_file {
  my ($self, $filename) = @_;
  my $spp_file;
  my $spp_list = [];

  foreach my $confdir (@SiteDefs::ENSEMBL_CONF_DIRS) {
    if (-e "$confdir/$filename.txt") {
      if (-r "$confdir/$filename.txt") {
        $spp_file = "$confdir/$filename.txt";
      } else {
        warn "$confdir/$filename.txt is not readable\n" ;
        next;
      }
      
      open FH, $spp_file or die "Problem with $spp_file: $!";
      
      while (<FH>) {
        chomp;
        next if $_ =~ /^#/; 
        push @$spp_list, $_;
      }

      ## We only need one file - ignore the rest
      last;
    }
  }

  return $spp_list;
}

sub _get_cow_defaults {
## Copy-on-write hash (only used by NV)
## Note: use method instead of an 'our' variable, as the latter can be a pain
## when shared across plugins
  return {};
}

sub _read_in_ini_file {
  my ($self, $filename, $defaults) = @_;
  my $inifile = undef;
  my $tree    = {};
  
  ## Avoid deep-copying in NV divisions, to reduce size of packed files
  ## See https://github.com/EnsemblGenomes/eg-web-common/commit/f702ab75235e66d7e9a979864b858fe0f88485f7
  my $cow_from_defaults = $self->get_cow_defaults;
  
  foreach my $confdir (@SiteDefs::ENSEMBL_CONF_DIRS) {
    if (-e "$confdir/ini-files/$filename.ini") {
      if (-r "$confdir/ini-files/$filename.ini") {
        $inifile = "$confdir/ini-files/$filename.ini";
      } else {
        warn "$confdir/ini-files/$filename.ini is not readable\n" ;
        next;
      }
      
      open FH, $inifile or die "Problem with $inifile: $!";
      
      my $current_section = undef;
      my $defaults_used   = 0;
      my $line_number     = 0;
      
      while (<FH>) {

        # parse any inline perl <% perl code %>
        s/<%(.+?(?=%>))%>/eval($1)/ge;

        s/\s+[;].*$//; # These two lines remove any comment strings
        s/^[#;].*$//;  # from the ini file - basically ; or #..
        
        if (/^\[\s*(\w+)\s*\]/) { # New section - i.e. [ ... ]
          $current_section = $1;

          if ( defined $defaults->{$current_section} && exists $cow_from_defaults->{$current_section} ) {
            $tree->{$current_section} = $defaults->{$current_section};
            $defaults_used = 1;
          }
          else { 
            $tree->{$current_section} ||= {}; # create new element if required
            $defaults_used = 0;
          
            # add settings from default
            if (defined $defaults->{$current_section}) {
              my %hash = %{$defaults->{$current_section}};
              $tree->{$current_section}{$_} = $defaults->{$current_section}{$_} for keys %hash;
            }
          }
        } elsif (/([\w*]\S*)\s*=\s*(.*)/ && defined $current_section) { # Config entry
          my ($key, $value) = ($1, $2); # Add a config entry under the current 'top level'
          $value =~ s/\s*$//;
          
          # [ - ] signifies an array
          if ($value =~ /^\[\s*(.*?)\s*\]$/) {
            my @array = split /\s+/, $1;
            $value = \@array;
          }
        
          if ( $defaults_used && defined $defaults->{$current_section} ) {
            my %hash = %{$defaults->{$current_section}};
            $tree->{$current_section}{$_} = $defaults->{$current_section}{$_} for keys %hash;
            $defaults_used = 0;
          }

          $tree->{$current_section}{$key} = $value;
        } elsif (/([.\w]+)\s*=\s*(.*)/) { # precedes a [ ] section
          print STDERR "\t  [WARN] NO SECTION $filename.ini($line_number) -> $1 = $2;\n";
        }
        
        $line_number++;
      }
      
      close FH;
    }

    # Check for existence of VCF JSON configuration file
    my $json_path = "$confdir/json/${filename}_vcf.json";
    if (-e $json_path) {
      $tree->{'ENSEMBL_VCF_COLLECTIONS'} = {'CONFIG' => $json_path, 'ENABLED' => 1} if $json_path;
    }
  }
  
  ## Automatic database configuration
  unless ($filename eq 'COLOUR' || $filename eq 'MULTI') {
    $tree->{'SPECIES_RELEASE_VERSION'} ||= 1;
  }

  return $inifile ? $tree : undef;
}

sub _promote_general {
  my ($self, $tree) = @_;
  
  $tree->{$_} = $tree->{'general'}{$_} for keys %{$tree->{'general'}};
  
  delete $tree->{'general'};
}

sub _expand_database_templates {
  my ($self, $filename, $tree, $config_packer) = @_;
 
  my $HOST   = $tree->{'general'}{'DATABASE_HOST'};      
  my $PORT   = $tree->{'general'}{'DATABASE_HOST_PORT'}; 
  my $USER   = $tree->{'general'}{'DATABASE_DBUSER'};    
  my $PASS   = $tree->{'general'}{'DATABASE_DBPASS'};    
  my $DRIVER = $tree->{'general'}{'DATABASE_DRIVER'} || 'mysql'; 
  
  ## Autoconfigure databases
  unless (exists $tree->{'databases'} && exists $tree->{'databases'}{'DATABASE_CORE'}) {
    my @db_types = qw(CORE CDNA OTHERFEATURES RNASEQ FUNCGEN VARIATION);
    my $db_details = {
                      'HOST'    => $HOST,
                      'PORT'    => $PORT,
                      'USER'    => $USER,
                      'PASS'    => $PASS,
                      'DRIVER'  => $DRIVER,
                      };
    $self->_info_line('DBserver', sprintf 'DBs at %s:%s', $db_details->{'HOST'}, $db_details->{'PORT'} ) if $SiteDefs::ENSEMBL_WARN_DATABASES;
    foreach (@db_types) {
      my $species_version = $tree->{'general'}{'SPECIES_RELEASE_VERSION'} || 1;
      my $db_name = $tree->{'databases'}{'DATABASE_'.$_};
      unless ($db_name) {
        my $non_vert_version = $SiteDefs::SITE_RELEASE_VERSION;
        $db_name = sprintf('%s_%s', $filename, lc($_));
        $db_name .= '_'.$non_vert_version if $non_vert_version;                                 
        $db_name .= sprintf('_%s_%s', $SiteDefs::ENSEMBL_VERSION, $species_version);
      }
      ## Does this database exist?
      $db_details->{'NAME'} = $db_name;
      my $db_exists = $config_packer->db_connect($_, $db_details, 1);
      if ($db_exists) {
        $self->_info_line('Databases', "$_: $db_name - autoconfigured") if $SiteDefs::ENSEMBL_WARN_DATABASES;
        $tree->{'databases'}{'DATABASE_'.$_} = $db_name;
      }
      else {
        ## Ignore this step for MULTI, as it may not have a core db
        unless ($filename eq 'MULTI') {
          my $db_string = $db_name.'@'.$db_details->{'HOST'};
          print STDERR "\t  [WARN] CORE DATABASE NOT FOUND - looking for '$db_string'\n" if $_ eq 'CORE';
          $self->_info_line('Databases', "-- database $db_name not available") if $SiteDefs::ENSEMBL_WARN_DATABASES;
        }
      }
    }
  }

  foreach my $key (keys %{$tree->{'databases'}}) {
    my $db_name = $tree->{'databases'}{$key};
    my $version = $tree->{'general'}{"${key}_VERSION"} || $SiteDefs::ENSEMBL_VERSION;
   
    ## Expand name if it is a template, e.g. %_core_%   
    if ($db_name =~ /^%_(\w+)_%_%$/) {
      $db_name = lc(sprintf '%s_%s_%s_%s_%s', $filename , $1, $SiteDefs::SITE_RELEASE_VERSION, $version, $tree->{'general'}{'SPECIES_RELEASE_VERSION'});
    } elsif ($db_name =~ /^%_(\w+)_%$/) {
      $db_name = lc(sprintf '%s_%s_%s_%s', $filename , $1, $version, $tree->{'general'}{'SPECIES_RELEASE_VERSION'});
    } elsif ($db_name =~/^%_(\w+)$/) {
      $db_name = lc(sprintf '%s_%s_%s', $filename , $1, $version);
    } elsif ($db_name =~/^(\w+)_%$/) {
      $db_name = lc(sprintf '%s_%s', $1, $version);
    }
    
    if ($tree->{'databases'}{$key} eq '') {
      delete $tree->{'databases'}{$key};
    } else {
      if (exists $tree->{$key} && exists $tree->{$key}{'HOST'}) {
        my %cnf = %{$tree->{$key}};
         
        $tree->{'databases'}{$key} = {
            NAME   => $db_name,
            HOST   => exists $cnf{'HOST'}   ? $cnf{'HOST'}   : $HOST,
            USER   => exists $cnf{'USER'}   ? $cnf{'USER'}   : $USER,
            PORT   => exists $cnf{'PORT'}   ? $cnf{'PORT'}   : $PORT,
            PASS   => exists $cnf{'PASS'}   ? $cnf{'PASS'}   : $PASS,
            DRIVER => exists $cnf{'DRIVER'} ? $cnf{'DRIVER'} : $DRIVER,
        };
          
        delete $tree->{$key};
      } else {
        $tree->{'databases'}{$key} = {
            NAME   => $db_name,
            HOST   => $HOST,
            USER   => $USER,
            PORT   => $PORT,
            PASS   => $PASS,
            DRIVER => $DRIVER
        };
      }
        
      $tree->{'databases'}{$key}{$_} = $tree->{'general'}{"${key}_$_"} for grep $tree->{'general'}{"${key}_$_"}, qw(HOST PORT);
    }
  }
}

sub _merge_db_tree {
  my ($self, $tree, $db_tree, $key) = @_;
  return unless defined $db_tree;
  Hash::Merge::set_behavior('RIGHT_PRECEDENT');
  my $t = merge($tree->{$key}, $db_tree->{$key});
  $tree->{$key} = $t;
}

sub _merge_species_tree {
  my ($self, $a, $b, $species_lookup) = @_;

  foreach my $key (keys %$b) {
    next if $species_lookup->{$key};
    $a->{$key} = $b->{$key} unless exists $a->{$key};
  }
}

sub _get_valid_urls {
  ### Searches plugins for children of Command
  ### N.B. Not currently used - under development
  
  my $self   = shift;
  my %plugin = @{$self->ENSEMBL_PLUGINS};
  my @order  = @{$self->ENSEMBL_PLUGIN_ROOTS};
  my (@subdirs, %children);

  foreach my $namespace (reverse @{$self->ENSEMBL_PLUGIN_ROOTS}) {
    my $plug_dir = $plugin{$namespace};
    (my $ns_dir  = $namespace) =~ s#::#/#g;
    @subdirs = ("$plug_dir/modules/EnsEMBL/Web", "$plug_dir/modules/$ns_dir"); 
    
    ## Loop through the plugin directories to find all Command paths
    foreach my $dir (@subdirs) {
      opendir(DIR, $dir) || next;
      
      my $cmd_dir = grep { $_ eq 'Command' } readdir(DIR);
      
      if ($cmd_dir) {
        opendir(CMD, $cmd_dir) || die "Can't open $cmd_dir";
        my @subdirs = grep { /^[\.]/ && $_ ne 'CVS' } readdir(CMD);
        
        # warn "@@@ FOUND DIRS @subdirs";
        foreach my $subdir (@subdirs) {
          my $sub = "$dir/Command/$subdir";
          # warn "... subdir $sub";
          
          opendir(SUB, $sub) || die "Can't open $sub";
          
          my @modules = grep { /\.pm$/ } readdir(SUB);
          
          foreach my $module (@modules) {
            # warn "!!! COMMAND $module";
          }
          
          closedir(SUB);
        }
        
        closedir(CMD);
      }
      
      closedir(DIR);
    }
  }
}

sub _parse {
  ### Does the actual parsing of .ini files
  ### (1) Open up the DEFAULTS.ini file(s)
  ### Foreach species open up all {species}.ini file(s)
  ###  merge in content of defaults
  ###  load data from db.packed file
  ###  make other manipulations as required
  ### Repeat for MULTI.ini
  ### Returns: boolean

  my $self = shift; 
  $CONF->{'_storage'} = {};

  $self->_info_log('Parser', 'Starting to parse tree');

  my $tree          = {};
  my $db_tree       = {};
  my $config_packer = EnsEMBL::Web::ConfigPacker->new($tree, $db_tree);
  
  $self->_info_line('Parser', 'Child objects attached');

  # Parse the web tree to create the static content site map
  $tree->{'STATIC_INFO'}  = $self->_load_in_webtree;
  $self->_info_line('Filesystem', 'Trawled web tree');
  # Load taxonomy division json for species selector
  $self->_info_log('Loading', 'Loading taxonomy division json file');
  $tree->{'ENSEMBL_TAXONOMY_DIVISION'} = $self->_load_in_taxonomy_division;
  
  # Load species lists, if not present in SiteDefs
  unless (scalar @{$SiteDefs::PRODUCTION_NAMES||[]}) {
    $self->_info_log('Loading', 'Loading species list');
    $SiteDefs::PRODUCTION_NAMES = $self->_read_species_list_file('ALL_SPECIES');
  }

  $self->_info_log('Parser', 'Parsing ini files and munging dbs');
  
  # Grab default settings first and store in defaults
  my $defaults = $self->_read_in_ini_file('DEFAULTS', {});
  $self->_info_line('Parsing', 'DEFAULTS ini file');
  
  # Loop for each database exported from SiteDefs
  # grab the contents of the ini file AND
  # IF the DB packed files exist, expand them
  # o/w attach the species databases

  # Note that because the code was developed for vertebrates first,
  # the variable PRODUCTION_NAMES actually comprises the names of ini files
  # and their corresponding databases, not necessarily individual species 
  # (e.g. in the case of collections)

  # load the data and store the packed files
  foreach my $species (@$SiteDefs::PRODUCTION_NAMES, 'MULTI') {
    $config_packer->species($species);
    $self->process_ini_files($species, $config_packer, $defaults);
    $self->_merge_db_tree($tree, $db_tree, $species);
  }
  
  $self->_info_log('Parser', 'Post processing ini files');

  # Prepare to process strain information
  my $species_to_strains = {};
  my $species_to_assembly = {};

  # Loop over each tree and make further manipulations
  foreach my $species (@$SiteDefs::PRODUCTION_NAMES, 'MULTI') {
    $config_packer->species($species);
    $config_packer->munge('config_tree');
    $self->_info_line('munging', "$species config");

    ## Configure favourites if not in DEFAULTS.ini (rapid release)
    unless ($config_packer->tree->{'DEFAULT_FAVOURITES'}) {
      my $favourites = $self->_read_species_list_file('FAVOURITES'); 
      warn "!!! NO FAVOURITES CONFIGURED" unless scalar @{$favourites||[]};
      $config_packer->tree->{'DEFAULT_FAVOURITES'} = $favourites;
      $config_packer->tree->{'ENSEMBL_PRIMARY_SPECIES'} = $favourites->[0];
      $config_packer->tree->{'ENSEMBL_SECONDARY_SPECIES'} = $favourites->[1];
    }

    # Replace any placeholder text in sample data
    my $sample = $config_packer->tree->{'SAMPLE_DATA'};
    while (my($k, $v) = each(%$sample)) {
      if ($k =~ /TEXT/ && ($v eq 'ensembl_gene' || $v eq 'ensembl_transcript')) {
        (my $link_type = $k) =~ s/_TEXT//;
        $sample->{$k} = $sample->{$link_type.'_PARAM'};
      }
    }
    $config_packer->tree->{'SAMPLE_DATA'} = $sample;

    ## Need to gather strain info for all species
    $config_packer->tree->{'IS_REFERENCE'} = 1;
    my $strain_group = $config_packer->tree->{'STRAIN_GROUP'};
    if ($strain_group && !$SiteDefs::NO_STRAIN_GROUPS) {
      $config_packer->tree->{'IS_REFERENCE'} = 0 if ($strain_group ne $species);
      if (!$config_packer->tree->{'IS_REFERENCE'}) {
        push @{$species_to_strains->{$strain_group}}, $config_packer->tree->{'SPECIES_URL'}; ## Key on actual URL, not production name
      }
    }
  }

  ## Compile strain info into a single structure
  while (my($k, $v) = each (%$species_to_strains)) {
    $tree->{$k}{'ALL_STRAINS'} = $v;
  } 

  #$Data::Dumper::Maxdepth = 2;
  #$Data::Dumper::Sortkeys = 1;
  #warn ">>> ORIGINAL KEYS: ".Dumper($tree);

  ## Final munging
  my $datasets = [];
  my $aliases  = $tree->{'MULTI'}{'ENSEMBL_SPECIES_URL_MAP'};
  my $labels    = $tree->{'MULTI'}{'TAXON_LABEL'};  

  ## Loop through all keys, not just PRODUCTION_NAMES (need for collection dbs)
  foreach my $key (sort keys %$tree) {
    next unless (defined $tree->{$key}{'SPECIES_PRODUCTION_NAME'}); # skip if not a species key
    my $prodname = $key;

    my $url = $tree->{$prodname}{'SPECIES_URL'};
    if ($url) {
    
      ## Add in aliases to production names
      $aliases->{$prodname} = $url;
    
      ## Rename the tree keys for easy data access via URLs
      ## (and backwards compatibility!)
      if ($url ne $prodname) {
        $tree->{$url} = $tree->{$prodname};
        delete $tree->{$prodname};
      }
      push @$datasets, $url;
    }
    else {
      warn "!!! SPECIES $prodname has no URL defined";
    }
  }

  ## Merge collection info into the species hash
  foreach my $prodname (@$SiteDefs::PRODUCTION_NAMES) {
    next unless $tree->{$prodname};
    my @db_species = @{$tree->{$prodname}->{DB_SPECIES}};
    my $species_lookup = { map {$_ => 1} @db_species };
    foreach my $sp (@db_species) {
      $self->_merge_species_tree( $tree->{$sp}, $tree->{$prodname}, $species_lookup);
    }
  }

  ## Continue with munging
  foreach my $sp (@$datasets) {
    my $url = $tree->{$sp}{'SPECIES_URL'};

    ## Assign an image to this species
    my $image_dir = $SiteDefs::SPECIES_IMAGE_DIR;
    my $no_image  = 1;
    if ($image_dir) {
      ## This site has individual species images for all/most species
      ## So check if it exists
      my $image_path = $image_dir.'/'.$url.'.png';
      if (-e $image_path) {
        $tree->{$url}{'SPECIES_IMAGE'} = $url;
        $no_image = 0;
      }
      elsif ($tree->{$url}{'SPECIES_STRAIN'}) {
        ## Look for a strain image (needed for pig)
        my $parent_image = ucfirst($tree->{$url}{'STRAIN_GROUP'});
        my $strain_image = $parent_image.'_'.$tree->{$url}{'STRAIN_TYPE'};
        $image_path =  $image_dir.'/'.$strain_image.'.png';
        if (-e $image_path) {
          $tree->{$url}{'SPECIES_IMAGE'} = $strain_image;
          $no_image = 0;
        }
        else {
          ## Use the parent image for this strain
          $image_path = $image_dir.'/'.$parent_image.'.png';
          if (-e $image_path) {
            $tree->{$url}{'SPECIES_IMAGE'} = $parent_image;
            $no_image = 0;
          }
        }
      }
    }
    if ($no_image) {
      my $clade = $tree->{$url}{'SPECIES_GROUP'};
      $tree->{$url}{'SPECIES_IMAGE'} = $labels->{$clade};
    }

    ## Species-specific munging
    if ($url ne "MULTI" && $url ne "databases") {
                                     
      my $display_name = $tree->{$url}{'SPECIES_DISPLAY_NAME'};
      push @{$species_to_assembly->{$display_name}}, $tree->{$url}->{'ASSEMBLY_VERSION'};
             
      $self->_populate_taxonomy_division($tree, $url) if $tree->{'ENSEMBL_TAXONOMY_DIVISION'};
    }
  }

  # Used for grouping same species with different assemblies in species selector
  $tree->{'SPECIES_ASSEMBLY_MAP'} = $species_to_assembly;

  $tree->{'MULTI'}{'ENSEMBL_DATASETS'} = $datasets;
  #warn ">>> NEW KEYS: ".Dumper($tree);

  ## New species list - currently only used by rapid release
  $tree->{'MULTI'}{'NEW_SPECIES'} = $self->_read_species_list_file('NEW_SPECIES');

  ## File format info
  my $format_info = $self->_get_file_format_info($tree);;
  $tree->{'MULTI'}{'UPLOAD_FILE_FORMATS'} = $format_info->{'upload'};
  $tree->{'MULTI'}{'REMOTE_FILE_FORMATS'} = $format_info->{'remote'};
  $tree->{'MULTI'}{'DATA_FORMAT_INFO'} = $format_info->{'formats'};

  ## Parse species directories for static content
  $tree->{'SPECIES_INFO'} = $self->_load_in_species_pages;
  $CONF->{'_storage'} = $tree; # Store the tree
  $self->_info_line('Filesystem', 'Trawled species static content');
}

sub process_ini_files {
  my ($self, $species, $config_packer, $defaults) = @_;
  my $type = 'db';
  
  my $msg  = "$species databases";
  my $file = File::Spec->catfile($self->{'_conf_dir'}, 'packed', "$species.$type.packed");
  my $full_tree = $config_packer->full_tree;
  my $tree_type = "_${type}_tree";
  
  if (!$full_tree->{$species}) {
    $full_tree->{$species} = $self->_read_in_ini_file($species, $defaults);
    $full_tree->{'MULTI'}{'COLOURSETS'} = $self->_munge_colours($self->_read_in_ini_file('COLOUR', {})) if $species eq 'MULTI';
    
    $self->_info_line('Parsing', "$species ini file");
    $self->_expand_database_templates($species, $full_tree->{$species}, $config_packer);
    $self->_promote_general($full_tree->{$species});
  }
  
  if (-e $file) {
    $config_packer->{$tree_type}->{$species} = lock_retrieve($file);
    $self->_info_line('Retrieve', $species eq 'MULTI' ? 'MULTI ini file' : $msg);
  } else {
    $config_packer->munge('rest');
    $config_packer->munge('databases');
    $self->_info_line(sprintf('** %s **', uc $type), $msg);
    
    lock_nstore($config_packer->{$tree_type}->{$species} || {}, $file);
  }
}


sub _populate_taxonomy_division {
# Populate taxonomy division using e_divisions.json template
  my ($self, $tree, $url) = @_;

  my $taxonomy = $tree->{$url}{'TAXONOMY'};
  my $children = [];
  my $other_species_children = [];

  my @other_species = grep { $_->{key} =~ m/other_species/ } @{$tree->{'ENSEMBL_TAXONOMY_DIVISION'}->{child_nodes}};
  $other_species[0]->{child_nodes} = [] if ($other_species[0] && !$other_species[0]->{child_nodes});

  my $strain_name = $tree->{$url}{'SPECIES_STRAIN'};
  my $strain_group = $tree->{$url}{'STRAIN_GROUP'};
  my $group_name   = $tree->{$url}{'SPECIES_COMMON_NAME'};
  my $species_key = $tree->{$url}{'SPECIES_URL'}; ## Key on actual URL, not production name

  foreach my $node (@{$tree->{'ENSEMBL_TAXONOMY_DIVISION'}->{child_nodes}}) {
    my $child = {
                  key             => $species_key,
                  scientific_name => $tree->{$url}{'SPECIES_SCIENTIFIC_NAME'},
                  common_name     => $tree->{$url}{'SPECIES_COMMON_NAME'},
                  display_name    => $tree->{$url}{'GROUP_DISPLAY_NAME'},
                  image           => $tree->{$url}{'SPECIES_IMAGE'},
                  is_leaf         => 'true'
                };

    if ($strain_group && $strain_name !~ /reference/) {
      $child->{type} = $group_name . ' ' . $tree->{$url}{'STRAIN_TYPE'}. 's';
    }
    elsif($strain_group && $strain_name =~ /reference/) {
      # Create display name for Reference species
      my $ref_name = $tree->{$url}{'SPECIES_DISPLAY_NAME'} . ' '. $strain_name;
      $child->{display_name} = $ref_name;
    }

    if (!$node->{taxa}) {
      push @{$other_species[0]->{child_nodes}}, $child;
    }
    else {
      my %taxa = map {$_ => 1} @{ $node->{taxa} };
      my @matched_groups = grep { $taxa{$_} } @$taxonomy;
      if ($#matched_groups >= 0) {
        if ($node->{child_nodes}) {
          my $cnode_match = {};
          foreach my $cnode ( @{$node->{child_nodes}}) {
            my @match = grep { /$matched_groups[0]/ }  @{$cnode->{taxa}};
            if ($#match >=0 ) {
              $cnode_match = $cnode;
              last;
            }
          }

          if (keys %$cnode_match) {
            if (!$cnode_match->{child_nodes}) {
              $cnode_match->{child_nodes} = [];
            }
            push @{$cnode_match->{child_nodes}}, $child;
            last;
          }
          else {
            if (!$node->{child_nodes}) {
              $node->{child_nodes} = [];
            }
            push @{$node->{child_nodes}}, $child;
            last;
          }
        }
        else {
          $node->{child_nodes} = [];
          push @{$node->{child_nodes}}, $child;
          last;
        }
      }
    }
  }
}

sub _get_file_format_info {
  my ($self, $tree) = @_;

  my %unsupported = map {uc($_) => 1} @{$tree->{'MULTI'}{'UNSUPPORTED_FILE_FORMATS'}||[]};
  my (@upload, @remote);

  ## Get info on all formats
  my %formats = (
    'bed'       => {'ext' => 'bed', 'label' => 'BED',       'display' => 'feature'},
    'bedgraph'  => {'ext' => 'bed', 'label' => 'bedGraph',  'display' => 'graph'},
    'gff'       => {'ext' => 'gff', 'label' => 'GFF',       'display' => 'feature'},
    'gtf'       => {'ext' => 'gtf', 'label' => 'GTF',       'display' => 'feature'},
    'psl'       => {'ext' => 'psl', 'label' => 'PSL',       'display' => 'feature'},
    'vcf'       => {'ext' => 'vcf', 'label' => 'VCF',       'display' => 'graph'},
    'vep_input' => {'ext' => 'txt', 'label' => 'VEP',       'display' => 'feature'},
    'wig'       => {'ext' => 'wig', 'label' => 'WIG',       'display' => 'graph'},
    ## Remote only - cannot be uploaded
    'bam'       => {'ext' => 'bam', 'label' => 'BAM',       'display' => 'graph', 'remote' => 1},
    'bcf'       => {'ext' => 'bcf', 'label' => 'BCF',       'display' => 'graph', 'remote' => 1},
    'bigwig'    => {'ext' => 'bw',  'label' => 'BigWig',    'display' => 'graph', 'remote' => 1},
    'bigbed'    => {'ext' => 'bb',  'label' => 'BigBed',    'display' => 'graph', 'remote' => 1},
    'bigpsl'    => {'ext' => 'bb',  'label' => 'BigPsl',    'display' => 'graph', 'remote' => 1},
    'bigint'    => {'ext' => 'bb',  'label' => 'BigInteract',    'display' => 'graph', 'remote' => 1},
    'cram'      => {'ext' => 'cram','label' => 'CRAM',      'display' => 'graph', 'remote' => 1},
    'trackhub'  => {'ext' => 'txt', 'label' => 'Track Hub', 'display' => 'graph', 'remote' => 1},
    ## Export only
    'fasta'     => {'ext' => 'fa',   'label' => 'FASTA'},
    'clustalw'  => {'ext' => 'aln',  'label' => 'CLUSTALW'},
    'msf'       => {'ext' => 'msf',  'label' => 'MSF'},
    'mega'      => {'ext' => 'meg',  'label' => 'Mega'},
    'newick'    => {'ext' => 'nh',   'label' => 'Newick'},
    'nexus'     => {'ext' => 'nex',  'label' => 'Nexus'},
    'nhx'       => {'ext' => 'nhx',  'label' => 'NHX'},
    'orthoxml'  => {'ext' => 'xml',  'label' => 'OrthoXML'},
    'phylip'    => {'ext' => 'phy',  'label' => 'Phylip'},
    'phyloxml'  => {'ext' => 'xml',  'label' => 'PhyloXML'},
    'pfam'      => {'ext' => 'pfam', 'label' => 'Pfam'},
    'psi'       => {'ext' => 'psi',  'label' => 'PSI'},
    'rtf'       => {'ext' => 'rtf',  'label' => 'RTF'},
    'stockholm' => {'ext' => 'stk',  'label' => 'Stockholm'},
    'text'      => {'ext' => 'txt',  'label' => 'Text'},
    'emboss'    => {'ext' => 'txt',  'label' => 'EMBOSS'},
    ## WashU formats
    'pairwise'  => {'ext' => 'txt', 'label' => 'Pairwise interactions', 'display' => 'feature'},
    'pairwise_tabix' => {'ext' => 'txt', 'label' => 'Pairwise interactions (indexed)', 'display' => 'feature', 'indexed' => 1},
  );

  ## Munge into something useful to this website
  while (my ($format, $details) = each (%formats)) {
    my $uc_name = uc($format);
    if ($unsupported{$uc_name}) {
      delete $formats{$format};
      next;
    }
    if ($details->{'remote'}) {
      push @remote, $format;
    }
    elsif ($details->{'display'}) {
      push @upload, $format;
    }
  }

  return {
          'upload' => \@upload,
          'remote' => \@remote,
          'formats' => \%formats
          };
}

sub _munge_colours {
  my $self = shift;
  my $in   = shift;
  my $out  = {};
  
  my $proc = 1;
  # Handle inheritance
  while($proc) {
    $proc = 0;
    foreach my $set (keys %$in) {
      my $base = $in->{$set}{'_inherit'};
      next unless $base and $in->{$base} and !$in->{$base}{'_inherit'};
      $in->{$set}{$_} ||= $in->{$base}{$_} for keys %{$in->{$base}};
      delete $in->{$set}{'_inherit'};
      $proc = 1;
    }
  }
  foreach my $set (keys %$in) {
    foreach my $key (keys %{$in->{$set}}) {
      my ($c, $n) = split /\s+/, $in->{$set}{$key}, 2;
      
      $out->{$set}{$key} = {
        text => $n, 
        map { /:/ ? (split /:/, $_, 2) : ('default', $_) } split /;/, $c
      };
      $out->{$set}{$key}{'section'} ||= '';
    }
  }
  return $out;
}

sub img_url { return $_[0]->ENSEMBL_STATIC_SERVER . ($_[0]->ENSEMBL_IMAGE_ROOT || '/i/'); }

sub marts {
  my $self = shift;
  return exists( $CONF->{'_storage'}{'MULTI'}{'marts'} ) ? $CONF->{'_storage'}{'MULTI'}{'marts'} : undef;
}

sub multidb {
  ### a
  my $self = shift;
  return exists( $CONF->{'_storage'}{'MULTI'}{'databases'} ) ? $CONF->{'_storage'}{'MULTI'}{'databases'} : undef;
}

sub multi_hash {
  my $self = shift;
  return $CONF->{'_storage'}{'MULTI'};
}

sub multi {
  ### a
  ### Arguments: configuration type (string), species name (string)
  
  my ($self, $type, $species) = @_;
  $species ||= $ENV{'ENSEMBL_SPECIES'};
  
  return 
    exists $CONF->{'_storage'} && 
    exists $CONF->{'_storage'}{'MULTI'} && 
    exists $CONF->{'_storage'}{'MULTI'}{$type} &&
    exists $CONF->{'_storage'}{'MULTI'}{$type}{$species} ? %{$CONF->{'_storage'}{'MULTI'}{$type}{$species}} : ();
}

sub compara_like_databases {
  my $self = shift;
  return $self->multi_val('compara_like_databases');
}

sub multi_val {
  my ($self, $type, $species) = @_;
  
  if (defined $species) {
    return 
      exists $CONF->{'_storage'} && 
      exists $CONF->{'_storage'}{'MULTI'} && 
      exists $CONF->{'_storage'}{'MULTI'}{$type} &&
      exists $CONF->{'_storage'}{'MULTI'}{$type}{$species} ? $CONF->{'_storage'}{'MULTI'}{$type}{$species} : undef;
  } else {
    return 
      exists $CONF->{'_storage'} && 
      exists $CONF->{'_storage'}{'MULTI'} && 
      exists $CONF->{'_storage'}{'MULTI'}{$type} ? $CONF->{'_storage'}{'MULTI'}{$type} : undef;
  }
}

sub multiX {
  ### a
  ### Arguments: configuration type (string)
  
  my ($self, $type) = @_;
  
  return () unless $CONF;
  return
      exists $CONF->{'_storage'} && 
      exists $CONF->{'_storage'}{'MULTI'} && 
      exists $CONF->{'_storage'}{'MULTI'}{$type} ? %{$CONF->{'_storage'}{'MULTI'}{$type}||{}} : ();
}

sub get_table_size {
  ### Accessor function for table size,
  ### Arguments: hashref: {-db => 'database' (e.g. 'DATABASE_CORE'), 
  ###                      -table =>'table name' (e.g. 'feature' ) }
  ###            species name (string)
  ### Returns: Number of rows in the table
  cluck "DEPRECATED............. use table_info_other ";
  return undef;
} 

sub set_write_access {
  ### sets a given database adaptor to write access instead of read-only
  ### Arguments: database type (e.g. 'core'), species name (string)
  ### Returns: none
  
  my $self = shift;
  my $type = shift;
  my $species = shift || $ENV{'ENSEMBL_SPECIES'} || $SiteDefs::ENSEMBL_PRIMARY_SPECIES;
  
  if ($type =~ /DATABASE_(\w+)/) {
    my $key    = $1;      # If the value is defined then we will create the adaptor here
    my $group  = lc $key; # Hack because we map DATABASE_CORE to 'core' not 'DB'
    my $dbc    = Bio::EnsEMBL::Registry->get_DBAdaptor($species,$group)->dbc;
    my $db_ref = $self->databases;
    
    $db_ref->{$type}{'USER'} = $self->DATABASE_WRITE_USER;
    $db_ref->{$type}{'PASS'} = $self->DATABASE_WRITE_PASS;
    
    Bio::EnsEMBL::Registry->change_access(
      $dbc->host, $dbc->port, $dbc->username, $dbc->dbname,
      $db_ref->{$type}{'USER'}, $db_ref->{$type}{'PASS'}
    );
  }
}

sub dump {
  ### Diagnostic function
  
  my ($self, $FH, $level, $Q) = @_;
  
  foreach (sort keys %$Q) {
    print $FH '    ' x $level, $_;
    
    if($Q->{$_} =~ /HASH/) {
      print $FH "\n";
      $self->dump($FH, $level+1, $Q->{$_});    
    } elsif ($Q->{$_} =~ /ARRAY/) {
      print $FH ' = [ ', join(', ', @{$Q->{$_}}), " ]\n";
    } else {
      print $FH " = $Q->{$_}\n";
    }
  }
}


sub translate {
  ### Dictionary functionality (not currently used)
  ### Arguments: word to be translated (string)
  ### Returns: translated word (string) or original word if not found
  my ($self, $word) = @_;
  return $word unless $self->ENSEMBL_DICTIONARY;  
  return $self->ENSEMBL_DICTIONARY->{$word}||$word;
}


sub all_search_indexes {
  ### a
  my %A = map { $_, 1 } map { @{$CONF->{'_storage'}{$_}{'ENSEMBL_SEARCH_IDXS'}||[]} } keys %{$CONF->{'_storage'}};
  return sort keys %A;
}

##############################################################################
## Additional parsing / creation codes...

##====================================================================##
##                                                                    ##
## write diagnostic errors to log file on...                          ##
##                                                                    ##
##====================================================================##

sub _info_log {
  my $self = shift;
  warn "------------------------------------------------------------------------------\n";
  $self->_info_line(@_);
  warn "------------------------------------------------------------------------------\n";
}

sub _info_line {
  my ($self, $title, $note, $level) = @_;
  my $T = time;
  $level ||='INFO';
  
  warn sprintf(
    "-%6.6s : %8.3f : %8.3f : %-10.10s >> %s\n",
    $level, $T-$self->{'_start_time'}, $T-$self->{'_last_time'}, $title, $note
  );
  
  $self->{'_last_time'} = $T;
}

##====================================================================##
##                                                                    ##
## _is_available_artefact - code to check the configuration hash in a ##
##  simple manner                                                     ##
##                                                                    ##
##====================================================================##


sub _is_available_artefact {
  ### Checks to see if a given artefact is available (or not available)
  ### in the stored configuration for a particular species
  ### Arguments: species name (defaults to the current species), 
  ###   artefact to check for (string - artefact type and id, space separated)
  ### Returns: boolean
  
  my $self        = shift;
  my $def_species = shift || $ENV{'ENSEMBL_SPECIES'};
  my $available   = shift;

  my @test = split ' ', $available;
  
  return 999 unless $test[0]; # No test found - return pass.

  ## Is it a positive (IS) or a negative (IS NOT) check?
  my ($success, $fail) = $test[0] =~ s/^!// ? (0, 1) : (1, 0);

  if ($test[0] eq 'database_tables') { ## Then test using get_table_size
    my ($database, $table) = split '\.', $test[1];
    
    return $self->get_table_size({ -db => $database, -table => $table }, $def_species) ? $success : $fail;
  } elsif ($test[0] eq 'multi') { ## Is the traces database specified?
    my ($type, $species) = split /\|/, $test[1], 2;
    my %sp = $self->multi($type, $def_species);
    
    return exists $sp{$species} ? $success : $fail;
  } elsif ($test[0] eq 'multialignment') { ## Is the traces database specified?
    my ($alignment_id) = $test[1];
    my %alignment      = $self->multi('ALIGNMENTS', $alignment_id);
    
    return scalar keys %alignment ? $success : $fail;
  } elsif ($test[0] eq 'constrained_element') {
    my ($alignment_id) = $test[1];
    my %alignment      = $self->multi('CONSTRAINED_ELEMENTS', $alignment_id);
    
    return scalar keys %alignment ? $success : $fail;
  } elsif ($test[0] eq 'database_features') { ## Is the given database specified?
    my $ft   = $self->get_config($def_species,'DB_FEATURES') || {};
    my @T    = split /\|/, $test[1];
    my $flag = 1;
    
    #  warn Dumper($ft);
    
    foreach (@T) {
      $flag = 0 if $ft->{uc $_};
      # warn "looking for $_";
      # warn "flag is $flag";
    }
    
    return $flag ? $fail : $success;
  } elsif ($test[0] eq 'databases') { ## Is the given database specified?
    my $db = $self->get_config($def_species, 'databases') || {};
    
    return $fail unless $db->{$test[1]};
    return $fail unless $db->{$test[1]}{'NAME'};
    return $success;
  } elsif ($test[0] eq 'features') { ## Is the given db feature specified?
    my $ft   = $self->get_config($def_species, 'DB_FEATURES') || {};
    my @T    = split /\|/, $test[1];
    my $flag = 1;
    
    foreach (@T) {
      $flag = 0 if $ft->{uc $_};
    }
    
    return $flag ? $fail : $success;
  } elsif ($test[0] eq 'any_feature'){ ## Are any of the given db features specified?
    my $ft = $self->get_config($def_species, 'DB_FEATURES') || {};
    shift @test;
    
    foreach (@test) {
      return $success if $ft->{uc $_};
    }
    
    return $fail;
  } elsif ($test[0] eq 'species_defs') {
    return $self->get_config($def_species, $test[1]) ? $success : $fail;
  } elsif ($test[0] eq 'species') {
     return $fail if Bio::EnsEMBL::Registry->get_alias($def_species, 'no throw') ne Bio::EnsEMBL::Registry->get_alias($test[1], 'no throw');
  }

  return $success; ## Test not found - pass anyway to prevent borkage!
}

sub table_info {
  my ($self, $db, $table) = @_;
  
  $db = 'DATABASE_' . uc $db unless $db =~ /^DATABASE_/;
  
  return {} unless $self->databases->{$db};
  return $self->databases->{$db}{'tables'}{$table} || {};
}

sub table_info_other {
  my ($self, $sp, $db, $table) = @_;
  $db = 'DATABASE_' . uc $db unless $db =~ /^DATABASE_/;
  
  my $db_hash = $self->get_config($sp, 'databases');
  
  return {} unless $db_hash && exists $db_hash->{$db} && exists $db_hash->{$db}{'tables'};
  return $db_hash->{$db}{'tables'}{$table} || {};
}


sub species_label {
  ### This function will return the display name of all known (by Compara) species.
  ### Some species in genetree can be from other EG units, and some can be from external sources
  ### Arguments:
  ###     key             String: species production name or URL
  ###     no_formating    Boolean: omit italics from scientific name  
  my ($self, $key, $no_formatting) = @_;

  my $url = ucfirst $key;
  my $display = $self->get_config($url, 'SPECIES_DISPLAY_NAME');
  my $label = '';

  if ($self->USE_COMMON_NAMES) {
    ## Basically vertebrates only - no pan_compara to check
    if ($self->get_config($url, 'SPECIES_URL')) {
      ## Known species, so create label accordingly
      my $sci    = $self->get_config($url, 'SPECIES_SCIENTIFIC_NAME');
      $sci = sprintf '<i>%s</i>', $sci unless $no_formatting;
      if ($display =~ /\./) {
        $label = $sci;
      }
      else {
        $label = "$display ($sci)";
      }
    }
    else {
      $label = 'Ancestral sequence';
    }
  }
  else {
    if ($display) {
      $label = $display;
    }
    else {
      ## Pan-compara species - get label from metadata db
      my $info = $self->get_config('MULTI', 'PAN_COMPARA_LOOKUP');
      if ($info) {
        if ($info->{$key}) {
          $label = $info->{$key}{'display_name'}
        }
        else {
          $label = $info->{lc $key}{'display_name'}
        }
      }
    }
    $label = 'Ancestral sequence' unless $label;
  }
  
  return $label;
}

sub production_name_lookup {
## Maps all species to their production name
  my $self = shift;
  my $names = {};
  
  foreach ($self->valid_species) {
    $names->{$self->get_config($_, 'SPECIES_PRODUCTION_NAME')} = $_;
  }
  return $names;
}

sub production_name_mapping {
### As the name said, the function maps the production name with the species URL, 
### @param production_name - species production name
### Return string = the corresponding species.url name which is the name web uses for URL and other code
### Fall back to production name if not found - mostly for pan-compara
  my ($self, $production_name) = @_;
  my $mapping_name = $production_name;
  
  foreach ($self->valid_species) {
    if ($self->get_config($_, 'SPECIES_PRODUCTION_NAME') eq lc($production_name)) {
    $mapping_name = $self->get_config($_, 'SPECIES_URL');
    last;
  }

  return $mapping_name;
}

sub assembly_lookup {
### Hash used to check if a given file or trackhub contains usable data
### @param old_assemblies - flag to indicate that older assemblies should be included
### @return lookup Hashref
###   The keys of this hashref are of the following two types:
###       - species_assembly    - used for attaching remote indexed files
###       - UCSC identifier     - used for checking trackhubs
  my ($self, $old_assemblies) = @_;
  my $lookup = {};
  foreach ($self->valid_species) {
    my $assembly        = $self->get_config($_, 'ASSEMBLY_VERSION');
    my $assembly_name   = $self->get_config($_, 'ASSEMBLY_NAME');
    my @assemblies      = ($assembly);
    push @assemblies, $assembly_name if $assembly_name ne $assembly;

    ## REMOTE INDEXED FILES
    ## Unique keys, needed for attaching URL data to correct species
    ## even when assembly name is not unique
    $lookup->{$_.'_'.$assembly} = [$_, $assembly, 0];

    ## TRACKHUBS
    ## Add UCSC assembly name if available
    if ($self->get_config($_, 'UCSC_GOLDEN_PATH')) {
      $lookup->{$self->get_config($_, 'UCSC_GOLDEN_PATH')} = [$_, $assembly, 0];
    }
    else {
      ## Otherwise assembly-only keys for species with no UCSC id configured
      foreach my $a (@assemblies) {
        $lookup->{$a} = [$_, $a, 0];
      }
    }
    if ($old_assemblies) {
      ## Include past UCSC assemblies
      if ($self->get_config($_, 'UCSC_ASSEMBLIES')) {
        my %ucsc = @{$self->get_config($_, 'UCSC_ASSEMBLIES')||[]};
        while (my($k, $v) = each(%ucsc)) {
          $lookup->{$k} = [$_, $v, 1];
        }
      }
    }
  }
  return $lookup;
}

sub species_dropdown {
  my ($self, $group) = @_;
  
  ## TODO - implement grouping by taxon
  my @options;
  my @sorted = 
    sort { $a->{'display'} cmp $b->{'display'} }
    map  {{ name => $_, display => $self->get_config($_, 'SPECIES_DISPLAY_NAME') }}
    $self->valid_species;
  
  foreach my $sp (@sorted) {
    my $name = $sp->{'name'};
    push @options, { value => $sp->{'name'}, name => $sp->{'display'} };
  }

  return @options;
}

sub species_path {
  ### This function will return the path including URL to all known ( by Core & Compara) species.
  ### Some species in genetree can be from other EG units, and some can be from external sources
  ### URLs returned in the format /species_url (for species local to this installation) or
  ### http://www.externaldomain.org/species_url (for external species, e.g. in pan-compara)
  
  my ($self, $species) = @_;
  $species ||= $ENV{'ENSEMBL_SPECIES'};

  return unless $species;
  
  my $url = $self->{'_species_paths'}->{$species};
  return $url if $url;
  
  ## Is this species found on this site?
  if ($self->valid_species($species)) {
    $url = "/$species";
  } else { 
    ## At the moment the mapping between species name and its source (full url) is stored in DEFAULTs.ini
    ## But it really should come from somewhere else ( compara db ? another registry service ? )
      
    my $current_species = $self->production_name;
    $current_species    = $self->ENSEMBL_PRIMARY_SPECIES if $current_species eq 'common';
    my $site_hash       = $self->ENSEMBL_SPECIES_SITE($current_species)  || $self->ENSEMBL_SPECIES_SITE;
    my $url_hash        = $self->ENSEMBL_EXTERNAL_URLS($current_species) || $self->ENSEMBL_EXTERNAL_URLS;
    my $nospaces        = $self->production_name($species);
    my $spsite          = uc $site_hash->{lc $nospaces};        # Get the location of the requested species
    my $cssite          = uc $site_hash->{lc $current_species}; # Get the location of the current site species
    
    $url = $url_hash->{$spsite} || '';        # Get the URL for the location
    $url =~ s/\#\#\#SPECIES\#\#\#/$nospaces/; # Replace ###SPECIES### with the species name

    # To deal with clades in bacteria
    # If we had to do the substitution let's check the species are not on the same site
    # as the current species - in that case we don't need the host name bit
    $url =~ s/^http\:\/\/[^\/]+\//\// if $url_hash->{$spsite} =~ /\#\#\#SPECIES\#\#\#/ && substr($spsite, 0, 5) eq substr($cssite, 0, 5);
    $url =~ s/\/$//;
    $url ||= "/$species"; # in case species have not made to the SPECIES_SITE there is a good chance the species name as it is will do  
  }
  
  $self->{'_species_paths'}->{$species} = $url; # cache the path

  return $url;
}

sub species_display_label {
  my $self = shift;
  return $self->species_label(@_);
}

sub production_name {
    my ($self, $species) = @_;

    $species ||= $ENV{'ENSEMBL_SPECIES'};
    return unless $species;

    return $species if ($species eq 'common');

# Try simple thing first
    if (my $sp_name = $self->get_config($species, 'SPECIES_PRODUCTION_NAME')) {
      return $sp_name;
    }

# species name is either has not been registered as an alias, or it comes from a different website, e.g in pan compara
    my %pan_lookup = $self->multiX('PAN_COMPARA_LOOKUP');
    my $prod_name  = $pan_lookup{$species} ? $pan_lookup{$species}{'production_name'} : '';
}

sub verbose_params {
  my $self    = shift;
  my $multidb = $self->multidb;

  warn "SpeciesDefs->multidb:\n";
  for (sort keys %$multidb) {
    warn sprintf "%50s: %s on %s%s@%s:%s\n",
      $_,
      $multidb->{$_}{'NAME'},
      $multidb->{$_}{'USER'},
      $multidb->{$_}{'PASS'} ? ':<PASS>' : '',
      $multidb->{$_}{'HOST'},
      $multidb->{$_}{'PORT'};
  }

  warn "SpeciesDefs species database:\n";
  foreach my $sp (sort @{$self->multi_hash->{'ENSEMBL_DATASETS'}}) {
    warn sprintf "%65s\n", "====== $sp ======";
    my $db = $self->get_config($sp, 'databases');
    for (sort keys %$db) {
      warn sprintf "%50s: %s on %s%s@%s:%s\n",
        $_,
        $db->{$_}{'NAME'} || '-- missing --',
        $db->{$_}{'USER'} || '-- missing --',
        $db->{$_}{'PASS'} ? ':<PASS>' : '',
        $db->{$_}{'HOST'} || '-- missing --',
        $db->{$_}{'PORT'} || '-- missing --';
    }
  }
}

sub DESTROY {
  ## Deliberately empty method - prevents call to AUTOLOAD when object is destroyed
}

1;
