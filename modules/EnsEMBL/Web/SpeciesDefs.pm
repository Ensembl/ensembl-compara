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
use File::Spec;

use Storable qw(lock_nstore lock_retrieve thaw);
use Data::Dumper;

use EnsEMBL::Web::Root;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::ConfigRegistry;

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use EnsEMBL::Web::Tools::PluginLocator;
use EnsEMBL::Web::Tools::WebTree;
use EnsEMBL::Web::Tools::RobotsTxt;
use EnsEMBL::Web::Tools::Registry;
use EnsEMBL::Web::Tools::MartRegistry;

use DBI;
use SiteDefs qw(:ALL);
use Hash::Merge qw( merge );
use Time::HiRes qw(time);

our @ISA = qw(EnsEMBL::Web::Root);
our $AUTOLOAD;
our $CONF;

sub new {
  ### c
  my $class = shift;

  my $self = bless( {'_start_time' => undef , '_last_time' => undef }, $class );
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

sub species_full_name {
  ### a
  ### returns full species name from the short name
  my $self = shift;
  my $sp   = shift;
  return $SiteDefs::ENSEMBL_SPECIES_ALIASES->{$sp};
}

sub AUTOLOAD {
  ### a
  my $self = shift;
  my $species = shift || $ENV{'ENSEMBL_SPECIES'} || $ENSEMBL_PRIMARY_SPECIES;
  my $var = our $AUTOLOAD;
  $var =~ s/.*:://;
  return $self->get_config( $species, $var );
}

sub colour {
### a
### return the colour associated with the $key of $set colour set (or the whole hash associated reference);
  my( $self, $set, $key, $part ) = @_;
  $part ||= 'default';
  return defined( $key ) ? $self->{_storage}{MULTI}{COLOURSETS}{$set} : $self->{_storage}{MULTI}{COLOURSETS}{$set}{$key}{'default'};
}

sub get_config {
  ## Returns the config value for a given species and a given config key
  ### Arguments: species name(string), parameter name (string)
  ### Returns:  parameter value (any type), or undef on failure
  my $self = shift;
  my $species = shift;
  if ($species eq 'common') {
    $species = $ENSEMBL_PRIMARY_SPECIES;
  }
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
  $CONF->{'_storage'} = $Q if ref($Q) eq 'HASH';
  return 1;
}

sub store {
  ### Creates filesystem-cache by storing config to disk. 
  ### Returns: boolean 
  ### Caller: perl.startup, on first (validation) pass of httpd.conf
  my $self = shift;
  die "[CONF]    [FATAL] Could not write to $self->{'_filename'}: $!" unless
    lock_nstore( $CONF->{'_storage'}, $self->{_filename} );
  return 1;
}


sub parse {
  ### Retrieves a stored configuration or creates a new one
  ### Returns: boolean
  ### Caller: $self->new when filesystem and memory caches are empty
  my $self  = shift;
  $CONF = {};
  my $reg_conf = EnsEMBL::Web::Tools::Registry->new( $CONF );

  $self->{_start_time} = time;
  $self->{_last_time } = $self->{_start_time};
  if( ! $SiteDefs::ENSEMBL_CONFIG_BUILD && -e $self->{_filename} ){
    warn( ( '-' x 78 ) ."\n",
          "[CONF]    \033[0;32m[INFO] Retrieving conf from $self->{_filename}\033[0;39m\n",
          ( '-' x 78 ) ."\n" );
    $self->retrieve();
    warn "$self->{_filename}";
    warn "XXXXXXXXXX - @{[ keys %{$CONF->{_storage}} ]}";
    $reg_conf->configure();
    return 1;
  }
  $self->_parse();
  $self->store();
  $reg_conf->configure();
  EnsEMBL::Web::Tools::RobotsTxt::create();
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


sub _load_in_webtree {
### Load in the contents of the web tree....
### Check for cached value first....
  my $self = shift;
  my $web_tree_packed = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0],'packed','web_tree.packed');
  my $web_tree = { _path => '/info/' };
  if( -e $web_tree_packed ) {
    $web_tree = lock_retrieve( $web_tree_packed );
  } else {
    for my $root (reverse @ENSEMBL_HTDOCS_DIRS) {
      EnsEMBL::Web::Tools::WebTree::read_tree( $web_tree, $root );
    }
    lock_nstore( $web_tree, $web_tree_packed );
  }
  return $web_tree;
}

sub _merge_in_dhtml {
  my( $self, $tree ) = @_;
  my $inifile = $SiteDefs::ENSEMBL_CONF_DIRS[0].'/packed/dhtml.ini';
  return unless( -e $inifile && open I, $inifile );
  while(<I>) {
    next unless /^(\w+)\s*=\s*(\w+)/;
    if( $1 eq 'css' ) {
      $tree->{'ENSEMBL_CSS_NAME'} = $2;
    } elsif( $1 eq 'js' ) {
      $tree->{'ENSEMBL_JS_NAME'} = $2;
    } elsif( $1 eq 'type' ) {
      $tree->{'ENSEMBL_JSCSS_TYPE'} = $2;
    }
  }
  close I;
}

sub _read_in_ini_file {
  my $tree = {};
  my( $self, $filename, $defaults ) = @_;
  my $inifile  = undef;
  foreach my $confdir( @SiteDefs::ENSEMBL_CONF_DIRS ){
    if( -e "$confdir/ini-files/$filename.ini" ){
      if( -r "$confdir/ini-files/$filename.ini" ){
        $inifile = "$confdir/ini-files/$filename.ini";
      } else {
        warn "$confdir/ini-files/$filename.ini is not readable\n" ;
        next;
      }
      open FH, $inifile or die( "Problem with $inifile: $!" );
      my $current_section = undef;
      my $line_number     = 0;
      while(<FH>) {
        s/\s+[;].*$//;    # These two lines remove any comment strings
        s/^[#;].*$//;     # from the ini file - basically ; or #..
        if( /^\[\s*(\w+)\s*\]/ ) {          # New section - i.e. [ ... ]
          $current_section          = $1;
          $tree->{$current_section} ||= {}; # create new element if required
          if(defined $defaults->{ $current_section }) { # add settings from default!!
            my %hash = %{$defaults->{ $current_section }};
            foreach( keys %hash ) {
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
  return $inifile ? $tree : undef;
}

sub _promote_general {
  my( $self, $tree ) = @_;
  foreach( keys %{$tree->{'general'}} ) {
    $tree->{$_} = $tree->{'general'}{$_};
  }
  delete $tree->{'general'};
}

sub _expand_database_templates {
  my( $self, $filename, $tree ) = @_;
  my $HOST   = $tree->{'general'}{'ENSEMBL_HOST'};      
  my $PORT   = $tree->{'general'}{'ENSEMBL_HOST_PORT'}; 
  my $USER   = $tree->{'general'}{'ENSEMBL_DBUSER'};    
  my $PASS   = $tree->{'general'}{'ENSEMBL_DBPASS'};    
  my $DRIVER = $tree->{'general'}{'ENSEMBL_DRIVER'} || 'mysql'; 
  if( exists $tree->{'databases'} ) {
    foreach my $key ( keys %{$tree->{'databases'}} ) {
      my $DB_NAME = $tree->{'databases'}{$key};
      if( $DB_NAME =~ /^%_(\w+)_%$/ ) {
        $DB_NAME = lc(sprintf( '%s_%s_%s_%s', $filename , $1, $SiteDefs::ENSEMBL_VERSION, $tree->{'general'}{'SPECIES_RELEASE_VERSION'} ));
      } elsif( $DB_NAME =~/^%_(\w+)$/ ) {
        $DB_NAME = lc(sprintf( '%s_%s_%s', $filename , $1, $SiteDefs::ENSEMBL_VERSION ));
      } elsif( $DB_NAME =~/^(\w+)_%$/ ) {
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
}

sub _merge_db_tree {
  my( $self, $tree, $db_tree, $key ) = @_;
  Hash::Merge::set_behavior( 'RIGHT_PRECEDENT' );
  my $t = merge( $tree->{$key}, $db_tree->{$key} );
  $tree->{$key} = $t;
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
  $CONF->{'_storage'} = {};                                                                $self->_info_log( 'Parser', "Starting to parse tree" );

  my $tree     = {};
  my $db_tree  = {};
  my $das_tree = {};
#------------ Initialize plugin locator - and create array of ConfigPacker objects...
  my $plugin_locator = EnsEMBL::Web::Tools::PluginLocator->new( (
    locations  => [ 'EnsEMBL::Web', reverse @{ $self->ENSEMBL_PLUGIN_ROOTS } ], 
    suffix     => "ConfigPacker"
  ));
  $plugin_locator->include();
# Create all the child objects with the $tree and $db_tree hashrefs attahed...
  $plugin_locator->create_all( $tree, $db_tree, $das_tree );
# not sure why I have to do this - but copy the results back as children (what does mw4's code do?)
  $plugin_locator->children( [ values %{$plugin_locator->results} ] );                     $self->_info_line( 'Parser', 'Child objects attached' );

#------------ Parse the web tree to create the static content site map
  $tree->{'STATIC_INFO'} = $self->_load_in_webtree();                                                $self->_info_line( 'Filesystem', "Trawled web tree" );

#------------ Grab default settings first and store in defaults...
                                                                                           $self->_info_log(  'Parser', "Parsing ini files and munging dbs" );

  my $defaults = $self->_read_in_ini_file( 'DEFAULTS', {} );                               $self->_info_line( 'Parsing', "DEFAULTS ini file" );
  $self->_merge_in_css_ini( $defaults );
  
#------------ Loop for each species exported from SiteDefs
#             grab the contents of the ini file AND
#             IF  the DB/DAS packed files exist expand them
#             o/w attach the species databases/parse the DAS registry, load the
#                 data and store the DB/DAS packed files...
  foreach my $species ( @$ENSEMBL_SPECIES ) {
    $tree->{$species} = $self->_read_in_ini_file( $species, $defaults );                   $self->_info_line( 'Parsing', "$species ini file" );
    $self->_expand_database_templates( $species, $tree->{$species} );
    $self->_promote_general(           $tree->{$species} );
    my $species_packed = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0],'packed',"$species.db.packed");
    my $das_packed     = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0],'packed',"$species.das.packed");

    if( -e $species_packed ) {
      $db_tree->{ $species } = lock_retrieve( $species_packed );                           $self->_info_line( 'Retrieve', "$species databases" );
    } else {
# Set species on each of the child objects..
      $plugin_locator->parameters( [$species] );
      $plugin_locator->call( 'species' );
      $plugin_locator->call( '_munge_databases' );                                         $self->_info_line( '** DB **', "$species databases" );
      lock_nstore( $db_tree->{ $species } || {}, $species_packed );
    }
    $self->_merge_db_tree( $tree, $db_tree, $species );
    
#if(0){
    if( -e $das_packed ) {
      $das_tree->{ $species } = lock_retrieve( $das_packed );                              $self->_info_line( 'Retrieve', "$species DAS sources" );
    } else {
# Set species on each of the child objects..
      $plugin_locator->parameters( [$species] );
      $plugin_locator->call( 'species' );
      $plugin_locator->call( '_munge_das' );                                               $self->_info_line( '** DAS **', "$species DAS sources" );
      lock_nstore( $das_tree->{ $species }||{}, $das_packed );
    }
    $self->_merge_db_tree( $tree, $das_tree, $species );
#  }
}
#------------ Do the same for the multi-species file...
  $tree->{'MULTI'} = $self->_read_in_ini_file( 'MULTI', $defaults );                       $self->_info_line( 'Parsing', "MULTI ini file" );
  $tree->{'MULTI'}{'COLOURSETS'} = $self->_munge_colours( $self->_read_in_ini_file( 'COLOUR', {} ) );

  $self->_expand_database_templates( 'MULTI', $tree->{'MULTI'} );
  $self->_promote_general(           $tree->{'MULTI'} );
  my $multi_packed = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0],'packed','MULTI.db.packed');
  if( -e $multi_packed ) {
    $db_tree->{'MULTI'} = lock_retrieve( $multi_packed );                                  $self->_info_line( 'Retrieve', "MULTI ini file" );
  } else {
    $plugin_locator->parameters( ['MULTI'] );
    $plugin_locator->call( 'species' );
    $plugin_locator->call( '_munge_databases_multi');                                      $self->_info_line( '** DB **', "MULTI database" );
    lock_nstore( $db_tree->{'MULTI'}, $multi_packed );
  }
  $self->_merge_db_tree( $tree, $db_tree, 'MULTI' );

#------------ Loop over each tree and make further manipulations
                                                                                           $self->_info_log(  'Parser', "Post processing ini files" );
  $self->_merge_in_dhtml( $tree );
  foreach my $species ( @$ENSEMBL_SPECIES ) {
    $plugin_locator->parameters( [$species] );
    $plugin_locator->call( 'species' );
    $plugin_locator->call( '_munge_config_tree' );                                         $self->_info_line( 'munging', "$species config" );
  }
  $plugin_locator->parameters( ['MULTI'] );
  $plugin_locator->call( 'species' );
  $plugin_locator->call( '_munge_config_tree_multi' );                                     $self->_info_line( 'munging',   "MULTI config" );

#------------ Store the tree...
  $CONF->{'_storage'} = $tree;
}

sub _munge_colours {
  my $self = shift;
  my $in   = shift;
  my $out  = {};
  foreach my $set ( keys %$in) {
    foreach my $key ( keys %{$in->{$set}} ) {
      my($c,$n) = split /\s+/,$in->{$set}{$key},2;
      $out->{$set}{$key} = { 'text' => $n, map { /:/ ? (split /:/,$_,2) : ('default',$_) } split /;/,$c };
    }
  }
  return $out;
}

sub DESTROY { }

sub timer{
### Provides easy-access to the ENSEMBL_WEB_REGISTRY's timer
  my $self = shift;
  $self->dynamic_use('EnsEMBL::Web::RegObj');
  return $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->timer;
}

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
  my( $self, $type, $species ) = @_;
  $species ||= $ENV{'ENSEMBL_SPECIES'};
  return exists( $CONF->{'_storage'}{'MULTI'}{$type}{$species} ) ? %{$CONF->{'_storage'}{'MULTI'}{$type}{$species}} : ();
}

sub multiX {
  ### a
  ### Arguments: configuration type (string)
  my( $self, $type ) = @_;
  return () unless $CONF;
  return
      exists $CONF->{'_storage'} && 
      exists $CONF->{'_storage'}{'MULTI'} && 
      exists $CONF->{'_storage'}{'MULTI'}{$type} 
    ? %{$CONF->{'_storage'}{'MULTI'}{$type}||{}}
    : ();
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

##====================================================================##
##                                                                    ##
## write diagnostic errors to log file on...                          ##
##                                                                    ##
##====================================================================##

our $warn_template = "-%6.6s : %8.3f : %-10.10s >> %s\n";

sub _info_log {
  my $self = shift;
  warn "------------------------------------------------------------------------------\n";
  $self->_info_line( @_ );
  warn "------------------------------------------------------------------------------\n";
}

sub _info_line {
  my( $self, $title, $note, $level ) = @_;
  my $T = time;
  $level||='INFO';
  warn sprintf  "-%6.6s : %8.3f : %8.3f : %-10.10s >> %s\n",
    $level, $T-$self->{_start_time}, $T-$self->{_last_time}, $title, $note;
  $self->{_last_time} = $T;
}

##====================================================================##
##                                                                    ##
## _is_available_artefact - code to check the configuration hash in a ##
##  simple manner                                                     ##
##                                                                    ##
##====================================================================##


sub _is_available_artefact{
  ### Checks to see if a given artefact is available (or not available)
  ### in the stored configuration for a particular species
  ### Arguments: species name (defaults to the current species), 
  ###   artefact to check for (string - artefact type and id, space separated)
  ### Returns: boolean
  my $self     = shift;
  my $def_species  = shift || $ENV{'ENSEMBL_SPECIES'};
  my $available = shift;

#warn "**$available**";

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
  } elsif( $test[0] eq 'constrained_element' ) {
    my( $alignment_id ) = $test[1];
    my %alignment = $self->multi('CONSTRAINED_ELEMENTS', $alignment_id);
    return $success if (scalar(keys %alignment));
    return $fail;
  } elsif( $test[0] eq 'database_features' ){ ## Is the given database specified?
    my $ft = $self->other_species($def_species,'DB_FEATURES') || {};
#  use Data::Dumper;
#  warn Dumper($ft);
    my @T = split /\|/, $test[1];
    my $flag = 1;
    foreach( @T ) {
#    warn "looking for $_";
      $flag = 0 if $ft->{uc($_)};
#    warn "flag is $flag";
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
