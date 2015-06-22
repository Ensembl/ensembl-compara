=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
### absence of a cache, the INI files are automatically parsed parsed at
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

use Carp qw(cluck);
use Data::Dumper;
use DBI;
use File::Spec;
use Hash::Merge qw(merge);
use Storable qw(lock_nstore lock_retrieve thaw);
use Time::HiRes qw(time);
use Fcntl qw(O_WRONLY O_CREAT);

use SiteDefs;# qw(:ALL);
use Sys::Hostname::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);
use Bio::EnsEMBL::Utils::Exception qw(verbose);
use Bio::EnsEMBL::DBSQL::DataFileAdaptor;

use EnsEMBL::Web::ConfigPacker;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Tools::WebTree;
use EnsEMBL::Web::Tools::RobotsTxt;
use EnsEMBL::Web::Tools::OpenSearchDescription;
use EnsEMBL::Web::Tools::Registry;
use EnsEMBL::Web::Tools::MartRegistry;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

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
    timer       => undef
  }, $class);

  my $conffile = "$SiteDefs::ENSEMBL_CONF_DIRS[0]/$SiteDefs::ENSEMBL_CONFIG_FILENAME";
  
  $self->{'_filename'} = $conffile;

  # TODO - these need to be pulled in dynamically from appropriate modules
  my @params = qw/ph g h r t v sv m db pt rf ex vf svf fdb lrg vdb gt/;
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
    'NAME'    => $db->{'NAME'},
    'HOST'    => $db->{'HOST'},
    'PORT'    => $db->{'PORT'},
    'DRIVER'  => $db->{'DRIVER'}  || 'mysql',
    'USER'    => $db->{'USER'}    || $self->DATABASE_WRITE_USER,
    'PASS'    => $db->{'PASS'}    || $self->DATABASE_WRITE_PASS
  };
}

sub core_params { return $_[0]->{'_core_params'}; }

sub get_all_das {
  my $self         = shift;
  my $species      = shift || $ENV{'ENSEMBL_SPECIES'};
  my $sources_hash = $self->get_config($species, 'ENSEMBL_INTERNAL_DAS_CONFIGS') || {};
  
  $species = '' if $species eq 'common';
  
  my (%by_name, %by_url);
  
  foreach (values %$sources_hash) {
    my $das = EnsEMBL::Web::DASConfig->new_from_hashref($_);
    
    $das->matches_species($species) || next;
    
    $by_name{$das->logic_name} = $das;
    $by_url {$das->full_url}   = $das;
  }
  
  return wantarray ? (\%by_name, \%by_url) : \%by_name;
}

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
  
  if (!@valid_species) {
    foreach my $sp (@$SiteDefs::ENSEMBL_DATASETS) {
      my $config = $self->get_config($sp, 'DB_SPECIES');
      
      if ($config->[0]) {
        push @valid_species, @{$config};
      } else {
        warn "Species $sp is misconfigured: please check generation of packed file";
      }
    }
    
    $self->{'_valid_species'} = [ @valid_species ]; # cache the result
  }

  @valid_species = grep $test_species{$_}, @valid_species if %test_species; # Test arg list if required

  return @valid_species;
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

sub get_config {
  ## Returns the config value for a given species and a given config key
  ### Arguments: species name(string), parameter name (string)
  ### Returns:  parameter value (any type), or undef on failure
  
  my $self    = shift;
  my $species = shift;
  $species    = $SiteDefs::ENSEMBL_PRIMARY_SPECIES if $species eq 'common';
  
  my $var = shift || $species;

  if (defined $CONF->{'_storage'}) {
    return $CONF->{'_storage'}{$species}{$species}{$var} if exists $CONF->{'_storage'}{$species} && 
                                                            exists $CONF->{'_storage'}{$species}{$species} && 
                                                            exists $CONF->{'_storage'}{$species}{$species}{$var};
                                                            
    return $CONF->{'_storage'}{$species}{$var} if exists $CONF->{'_storage'}{$species} &&
                                                  exists $CONF->{'_storage'}{$species}{$var};
                                                  
    return $CONF->{'_storage'}{$var} if exists $CONF->{'_storage'}{$var};
  }
  
  no strict 'refs';
  my $S = "SiteDefs::$var";
  
  return ${$S}  if defined ${$S};
  return \@{$S} if defined @{$S};
  
  warn "UNDEF ON $var [$species]. Called from ", (caller(1))[1] , " line " , (caller(1))[2] , "\n" if $SiteDefs::ENSEMBL_DEBUG_FLAGS & 4;
  
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

sub generator {
  Sys::Hostname::Long::hostname_long().":".$SiteDefs::ENSEMBL_SERVERROOT;
}

sub retrieve {
  ### Retrieves stored configuration from disk
  ### Returns: boolean
  ### Exceptions: The filesystem-cache file cannot be opened
  
  my $self = shift;
  my $Q    = lock_retrieve($self->{'_filename'}) or die "Can't open $self->{'_filename'}: $!"; 
  
  $CONF->{'_storage'} = $Q if ref $Q eq 'HASH';
  return $CONF->{'_storage'}{'GENERATOR'} eq generator();
}

sub store {
  ### Creates filesystem-cache by storing config to disk. 
  ### Returns: boolean 
  ### Caller: perl.startup, on first (validation) pass of httpd.conf
  
  my $self = shift;

  $CONF->{'_storage'}{'GENERATOR'} = generator();

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
    warn " Retrieving conf from $self->{'_filename'}\n";
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
  
  EnsEMBL::Web::Tools::RobotsTxt::create($self->ENSEMBL_DATASETS, $self);
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
  my $web_tree_packed = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0], 'packed', 'web_tree.packed');
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
  my $spp_tree_packed = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0], 'packed', 'spp_tree.packed');
  my $spp_tree        = { _path => '/' };
  
  if (-e $spp_tree_packed) {
    $spp_tree = lock_retrieve($spp_tree_packed);
  } else {
    EnsEMBL::Web::Tools::WebTree::read_species_dirs($spp_tree, $_, $SiteDefs::ENSEMBL_DATASETS) for reverse @SiteDefs::ENSEMBL_HTDOCS_DIRS;
    lock_nstore($spp_tree, $spp_tree_packed);
  }
  
  return $spp_tree;
}

sub _read_in_ini_file {
  my ($self, $filename, $defaults) = @_;
  my $inifile = undef;
  my $tree    = {};
  
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
      my $line_number     = 0;
      
      while (<FH>) {
        s/\s+[;].*$//; # These two lines remove any comment strings
        s/^[#;].*$//;  # from the ini file - basically ; or #..
        
        if (/^\[\s*(\w+)\s*\]/) { # New section - i.e. [ ... ]
          $current_section = $1;
          $tree->{$current_section} ||= {}; # create new element if required
          
          # add settings from default
          if (defined $defaults->{$current_section}) {
            my %hash = %{$defaults->{$current_section}};
            
            $tree->{$current_section}{$_} = $defaults->{$current_section}{$_} for keys %hash;
          }
        } elsif (/([\w*]\S*)\s*=\s*(.*)/ && defined $current_section) { # Config entry
          my ($key, $value) = ($1, $2); # Add a config entry under the current 'top level'
          $value =~ s/\s*$//;
          
          # [ - ] signifies an array
          if ($value =~ /^\[\s*(.*?)\s*\]$/) {
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

    # Check for existence of VCF JSON configuration file
    my $json_path = "$confdir/json/${filename}_vcf.json";
    if (-e $json_path) {
      $tree->{'ENSEMBL_VCF_COLLECTIONS'} = {'CONFIG' => $json_path, 'ENABLED' => 1} if $json_path;
    }
  }
  
  return $inifile ? $tree : undef;
}

sub _promote_general {
  my ($self, $tree) = @_;
  
  $tree->{$_} = $tree->{'general'}{$_} for keys %{$tree->{'general'}};
  
  delete $tree->{'general'};
}

sub _expand_database_templates {
  my ($self, $filename, $tree) = @_;
  
  my $HOST   = $tree->{'general'}{'DATABASE_HOST'};      
  my $PORT   = $tree->{'general'}{'DATABASE_HOST_PORT'}; 
  my $USER   = $tree->{'general'}{'DATABASE_DBUSER'};    
  my $PASS   = $tree->{'general'}{'DATABASE_DBPASS'};    
  my $DRIVER = $tree->{'general'}{'DATABASE_DRIVER'} || 'mysql'; 
  
  if (exists $tree->{'databases'}) {
    foreach my $key (keys %{$tree->{'databases'}}) {
      my $db_name = $tree->{'databases'}{$key};
      my $version = $tree->{'general'}{"${key}_VERSION"} || $SiteDefs::ENSEMBL_VERSION;
      
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
}

sub _merge_db_tree {
  my ($self, $tree, $db_tree, $key) = @_;
  return unless defined $db_tree;
  Hash::Merge::set_behavior('RIGHT_PRECEDENT');
  my $t = merge($tree->{$key}, $db_tree->{$key});
  $tree->{$key} = $t;
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
  my $das_tree      = {};
  my $config_packer = EnsEMBL::Web::ConfigPacker->new($tree, $db_tree, $das_tree);
  
  $self->_info_line('Parser', 'Child objects attached');

  # Parse the web tree to create the static content site map
  $tree->{'STATIC_INFO'}  = $self->_load_in_webtree;
  ## Parse species directories for static content
  $tree->{'SPECIES_INFO'} = $self->_load_in_species_pages;
  $self->_info_line('Filesystem', 'Trawled web tree');
  
  $self->_info_log('Parser', 'Parsing ini files and munging dbs');
  
  # Grab default settings first and store in defaults
  my $defaults = $self->_read_in_ini_file('DEFAULTS', {});
  $self->_info_line('Parsing', 'DEFAULTS ini file');
  
  # Loop for each species exported from SiteDefs
  # grab the contents of the ini file AND
  # IF  the DB/DAS packed files exist expand them
  # o/w attach the species databases/parse the DAS registry, 
  # load the data and store the DB/DAS packed files
  foreach my $species (@$SiteDefs::ENSEMBL_DATASETS, 'MULTI') {
    $config_packer->species($species);
    
    $self->process_ini_files($species, 'db', $config_packer, $defaults);
    $self->_merge_db_tree($tree, $db_tree, $species);
    
    if ($species ne 'MULTI') {
      $self->process_ini_files($species, 'das', $config_packer, $defaults);
      $self->_merge_db_tree($tree, $das_tree, $species);
    }
  }
  
  $self->_info_log('Parser', 'Post processing ini files');
  
  # Loop over each tree and make further manipulations
  foreach my $species (@$SiteDefs::ENSEMBL_DATASETS, 'MULTI') {
    $config_packer->species($species);
    $config_packer->munge('config_tree');
    $self->_info_line('munging', "$species config");
  }

  $CONF->{'_storage'} = $tree; # Store the tree
}

sub process_ini_files {
  my ($self, $species, $type, $config_packer, $defaults) = @_;
  
  my $msg  = "$species " . ($type eq 'das' ? 'DAS sources' : 'database');
  my $file = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0], 'packed', "$species.$type.packed");
  my $full_tree = $config_packer->full_tree;
  my $tree_type = "_${type}_tree";
  
  if (!$full_tree->{$species}) {
    $full_tree->{$species} = $self->_read_in_ini_file($species, $defaults);
    $full_tree->{'MULTI'}{'COLOURSETS'} = $self->_munge_colours($self->_read_in_ini_file('COLOUR', {})) if $species eq 'MULTI';
    
    $self->_info_line('Parsing', "$species ini file");
    $self->_expand_database_templates($species, $full_tree->{$species});
    $self->_promote_general($full_tree->{$species});
  }
  
  if (-e $file) {
    $config_packer->{$tree_type}->{$species} = lock_retrieve($file);
    $self->_info_line('Retrieve', $species eq 'MULTI' ? 'MULTI ini file' : $msg);
  } else {
    $config_packer->munge($type eq 'db' ? 'databases' : 'das');
    $self->_info_line(sprintf('** %s **', uc $type), $msg);
    
    lock_nstore($config_packer->{$tree_type}->{$species} || {}, $file);
  }
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

sub timer {
  ### Provides easy-access to the ENSEMBL_WEB_REGISTRY's timer
  my $self = shift;
  
  if (!$self->{'timer'}) {
    $self->dynamic_use('EnsEMBL::Web::RegObj');
    $self->{'timer'} = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->timer;
  }
  
  return $self->{'timer'};
}

sub timer_push {
  my $self = shift;
  return $self->timer->push(@_);
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
  } elsif ($test[0] eq 'das_source') { ## Is the given DAS source specified?
    my $source = $self->ENSEMBL_INTERNAL_DAS_CONFIGS || {};
    
    return $source->{$test[1]} ? $success : $fail;
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
  my ($self, $key, $no_formatting) = @_;

  if( my $sdhash          = $self->SPECIES_DISPLAY_NAME) {
      (my $lcspecies = lc $key) =~ s/ /_/g;
      return $sdhash->{$lcspecies} if $sdhash->{$lcspecies};
  }

  $key = ucfirst $key;
  
  return 'Ancestral sequence' unless $self->get_config($key, 'SPECIES_BIO_NAME');
  
  my $common = $self->get_config($key, 'SPECIES_COMMON_NAME');
  my $rtn    = $self->get_config($key, 'SPECIES_BIO_NAME');
  $rtn       =~ s/_/ /g;
  
  $rtn = sprintf '<i>%s</i>', $rtn unless $no_formatting;
  
  if ($common =~ /\./) {
    return $rtn;
  } else {
    return "$common ($rtn)";
  }  
}

sub assembly_lookup {
  my ($self, $old_assemblies) = @_;
  my $lookup = {};
  foreach ($self->valid_species) {
    my $assembly = $self->get_config($_, 'ASSEMBLY_VERSION');
    ## A bit clunky, but it makes code cleaner in use
    $lookup->{$assembly} = [$_, $assembly, 0];
    ## Now look up UCSC assembly names
    if ($self->get_config($_, 'UCSC_GOLDEN_PATH')) {
      $lookup->{$self->get_config($_, 'UCSC_GOLDEN_PATH')} = [$_, $assembly, 0];
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
  my @sorted_by_common = 
    sort { $a->{'common'} cmp $b->{'common'} }
    map  {{ name => $_, common => $self->get_config($_, 'SPECIES_COMMON_NAME') }}
    $self->valid_species;
  
  foreach my $sp (@sorted_by_common) {
    # Get the settings from ini files 
    my $name = $sp->{'name'};
    push @options, { value => $sp->{'name'}, name => $sp->{'common'} };
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
  ### This function will return the display name of all known (by Compara) species.
  ### Some species in genetree can be from other EG units, and some can be from external sources
  ### species_label function above will only work with species of the current site
  ### At the moment the mapping in DEFAULTs.ini
  ### But it really should come from compara db

  my ($self, $species, $no_formatting) = @_;
  
  if( my $sdhash          = $self->SPECIES_DISPLAY_NAME) {
      (my $ss = lc $species) =~ s/ /_/g;
      return $sdhash->{$ss} if $sdhash->{$ss};
  }

  return $self->species_label($species);
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
# then it has to appear in SPECIES_DISPLAY_NAME section of DEFAULTS ini
# check if it matches any key or any value in that section
    (my $nospaces  = $species) =~ s/ /_/g;

    if (my $sdhash = $self->SPECIES_DISPLAY_NAME) {
      return $species if exists $sdhash->{lc($species)};

      return $nospaces if exists $sdhash->{lc($nospaces)};
      my %sdrhash = map { $sdhash->{$_} => $_ } keys %{$sdhash || {}};

      (my $with_spaces  = $species) =~ s/_/ /g;
      my $sname = $sdrhash{$species} || $sdrhash{$with_spaces};
      return $sname if $sname;
    }

    return $nospaces;
}

sub DESTROY {
  ## Deliberately empty method - prevents call to AUTOLOAD when object is destroyed
}

1;
