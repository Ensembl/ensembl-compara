# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package SiteDefs;

### Description
### Declares all config parameters required by the Ensembl website (or other scripts)
### Loads the main SiteDefs (this file) first and then adds configs from plugin's SiteDefs

### Usage
### use SiteDefs;             # Standard mode
### use SiteDefs qw(verbose); # Same as above but extra debug verbosity

use strict;
use warnings;

use Config;
use ConfigDeferrer qw(:all);
use File::Spec;
use Sys::Hostname::Long;


###############################################################################
## Ensembl Version and release dates (these get updated every release)
our $ENSEMBL_VERSION        = 88;            # Ensembl release number
our $ARCHIVE_VERSION        = 'Mar2017';     # Archive site for this version
our $ENSEMBL_RELEASE_DATE   = 'Mar 2017';    # As it would appear in the copyright/footer
###############################################################################


###############################################################################
## Default folder locations
our $ENSEMBL_SERVERROOT   = _get_serverroot(__FILE__);              # Root dir that contains all Ensembl checkouts
our $ENSEMBL_WEBROOT      = "$ENSEMBL_SERVERROOT/ensembl-webcode";  # webcode checkout
our $ENSEMBL_DOCROOT      = "$ENSEMBL_WEBROOT/htdocs";              # htdocs default path
###############################################################################


###############################################################################
## Apache configs
our $APACHE_DIR                   = "$ENSEMBL_SERVERROOT/apache2";                        # Apache serverroot for command line `httpd -d $APACHE_DIR ... `
our $APACHE_BIN                   = defer { "$APACHE_DIR/bin/httpd" };                    # Location of Apache bin file to run server
our $APACHE_DEFINE                = undef;                                                # Extra command line arguments for httpd command
our $ENSEMBL_HTTPD_CONFIG_FILE    = "$ENSEMBL_WEBROOT/conf/httpd.conf";                   # Apache config file location
our $ENSEMBL_MIN_SPARE_SERVERS    = 20;                                                   # For Apache MinSpareServers directive
our $ENSEMBL_MAX_SPARE_SERVERS    = 50;                                                   # For Apache MaxSpareServers directive
our $ENSEMBL_START_SERVERS        =  7;                                                   # For Apache StartServers directive
our $ENSEMBL_DB_IDLE_LIMIT     = 12;
              # Maximum number of connections to "carry through" to next
              # connection
our $ENSEMBL_DB_TIDY_DEBUG     = 0;
              # Debug conneciton management.
our $ENSEMBL_PORT                 = 80;                                                   # Port to run Apache (for Listen directive)
our $ENSEMBL_SERVERNAME           = 'www.mydomain.org';                                   # For Apache ServerName directive (External domain name for the web server)
our $ENSEMBL_SERVERADMIN          = 'webmaster&#064;mydomain.org';                        # For Apache ServerAdmin directive
###############################################################################


###############################################################################
## Other server settings
our $ENSEMBL_SERVER               = Sys::Hostname::Long::hostname_long; # Local machine name
our $ENSEMBL_PROTOCOL             = 'http';                             # Used for proxies and self-referential URLs
our $ENSEMBL_PROXY_PORT           = undef;                              # Port used for self-referential URLs. Set to undef if not using proxy-forwarding
our $ENSEMBL_LONGPROCESS_MINTIME  = 10;                                 # Warn extra info to logs if a process takes more than given time in seconds to serve request
our $ENSEMBL_MAX_PROCESS_SIZE     = 1024 * 1024;                        # Value for Apache2::SizeLimit::MAX_PROCESS_SIZE
our $ENSEMBL_MAIL_SERVER          = 'mail.mydomain.org';                # Mail server to be used for sending emails from the web server
###############################################################################


###############################################################################
## More server settings

our $SITE_LOGO = '';
our $SITE_LOGO_WIDTH = '';
our $SITE_LOGO_HEIGHT = '';
our $SITE_LOGO_ALT = '';
our $SITE_LOGO_HREF = '';

our $ENSEMBL_CONFIG_FILENAME_SUFFIX   = 'config.packed';
our $ENSEMBL_CONFIG_BUILD             = 0; # Build config on server startup? Setting to 0 will try to recover from $ENSEMBL_CONFIG_FILENAME on startup
our $ENSEMBL_SITETYPE                 = 'Ensembl';
our $ENSEMBL_HELPDESK_EMAIL           = defer { $ENSEMBL_SERVERADMIN };   # Email address for contact form and help pages
our $ENSEMBL_REST_URL                 = 'http://rest.mydomain.org';       # url to your REST service
our $CGI_POST_MAX                     = 20 * 1024 * 1024; # 20MB file upload max limit
our $UPLOAD_SIZELIMIT_WITHOUT_INDEX   = 10 * 1024 * 1024; # 10MB max allowed for url uploads that don't have index files in the same path
our $TRACKHUB_TIMEOUT                 = 60 * 60 * 24;     # Timeout for outgoing trackhub requests
our $ENSEMBL_ORM_DATABASES            = {};               # Hash to contain DB settings for databases connected via ensembl-orm (Used in SpeciesDefs::register_orm_databases)
our $ENSEMBL_API_VERBOSITY            = 'WARNING';        # OFF, EXCEPTION, WARNING, DEPRECATE, INFO, ALL
our $ENSEMBL_SPECIES_SELECT_DIVISION  = defer { "$ENSEMBL_DOCROOT/e_species_divisions.json" }; # JSON file used by Species Selector on multiple views
our $ENSEMBL_SKIP_RSS                 = 0;      # set to 1 in sandboxes to avoid overloading blog
our $ENSEMBL_EXTERNAL_SEARCHABLE      = 0;      # No external bots allowed by default
our $PACED_MULTI                      = 6;      # Max simultaneous connections
our $HTTP_PROXY                       = undef;  # Web proxy for outgoing http/https requests
our $ENSEMBL_REGISTRY                 = undef;  # Set this to a valid config file for Bio::EnsEMBL::Registry::load_all() or leave undef
our $ENSEMBL_SITE_DIR                 = '';     # URL Path if site is served from a sub path i.e www.example.org/$ENSEMBL_SITE_DIR/
our $ENSEMBL_STATIC_SERVER            = '';     # Static server address - if static content (js/css/images) is served from a different server
our $SYSLOG_COMMAND                   = sub { warn "$_[0]\n"; };  # command/subroutine called by `syslog` - check EnsEMBL::Web::Utils::Syslog
our $TIDY_USERDB_CONNECTIONS          = 1;      # Clear user/session db connections after request is finished
our $SERVER_ERRORS_TO_LOGS            = 1;      # Send all server exception stack traces to logs and send a unique error Id on the browser
###############################################################################


###############################################################################
## Minification settings - check EnsEMBL::Web::Tools::DHTMLMerge
our $ENSEMBL_DEBUG_JS             = 0; # change these to 1 to prevent js minification
our $ENSEMBL_DEBUG_CSS            = 0; # change these to 1 to prevent css minification
our $ENSEMBL_DEBUG_IMAGES         = 0; # change these to 1 to prevent css minification
###############################################################################


###############################################################################
## Other DEBUG flags
our $ENSEMBL_DEBUG_HANDLER_ERRORS   = 1; # Shows messages from EnsEMBL::Web::Apache::*
our $ENSEMBL_DEBUG_CACHE            = 0; # Turns debug messages on for EnsEMBL::Web::Cache
###############################################################################


###############################################################################
## Cookies and cookie encryption
our $ENSEMBL_USER_COOKIE          = 'ENSEMBL_WWW_USER';     # Cookie name for User cookie (if user plugin is enabled)
our $ENSEMBL_USER_COOKIEHOST      = '';                     # Cookie host for User cookie
our $ENSEMBL_SESSION_COOKIE       = 'ENSEMBL_WWW_SESSION';  # Cookie name for session cookie
our $ENSEMBL_SESSION_COOKIEHOST   = '';                     # Cookie host for session cookie
our $ENSEMBL_COOKIEHOST           = '';                     # Cookie host for all cookies
our $ENSEMBL_ENCRYPT_0            = 0x16a3b3;               # Encryption keys for session/user cookie. Please overwrite in your plugins.
our $ENSEMBL_ENCRYPT_1            = 'a9';                   # Encryption keys for session/user cookie. Please overwrite in your plugins.
our $ENSEMBL_ENCRYPT_2            = 'xX';                   # Encryption keys for session/user cookie. Please overwrite in your plugins.
our $ENSEMBL_ENCRYPT_3            = '2Q';                   # Encryption keys for session/user cookie. Please overwrite in your plugins.
our $ENSEMBL_ENCRYPT_EXPIRY       = 60;                     # Cookies last 60 days
our $ENSEMBL_ENCRYPT_REFRESH      = 30;                     # Refresh cookies with less than 30 days to go
###############################################################################


###############################################################################
## Temporary directories
our $ENSEMBL_TMP_ROOT             = "$ENSEMBL_SERVERROOT/tmp";                                                # Base directory for server-generated files
our $ENSEMBL_TMP_DIR              = defer { $ENSEMBL_TMP_ROOT };                                              # Extra level of subdirectories if required
our $ENSEMBL_TMP_DIR_IMG          = defer { "$ENSEMBL_TMP_DIR/img/tmp" };                                     # r/w path for temporary images generated by GD etc
our $ENSEMBL_TMP_TMP              = defer { "$ENSEMBL_TMP_DIR/tmp" };                                         # general purpose folder for volatile files
our $ENSEMBL_SYS_DIR              = defer { $ENSEMBL_SERVERROOT };                                           # Path for saving files generated by server (startup or run time)
our $ENSEMBL_CBUILD_DIR           = defer { "$ENSEMBL_WEBROOT/cbuild" };                                      # Path for building Inline C
our $ENSEMBL_LOGDIR               = defer { "$ENSEMBL_SYS_DIR/logs/$ENSEMBL_SERVER" };                        # Path for log files
our $ENSEMBL_PIDFILE              = defer { "$ENSEMBL_LOGDIR/httpd.pid" };                                    # httpd process id
our $ENSEMBL_ERRORLOG             = defer { "$ENSEMBL_LOGDIR/error_log" };                                    # Error log file
our $ENSEMBL_CUSTOMLOG            = defer { "$ENSEMBL_LOGDIR/access_log ensembl_extended" };                  # Access log file
our $ENSEMBL_FAILUREDIR           = defer { "$ENSEMBL_TMP_DIR/failure_dir" };                                 # Folder to save status of external resources (Check EnsEMBL::Web::Tools::FailOver)
our $ENSEMBL_ROBOTS_TXT_DIR       = defer { $ENSEMBL_WEBROOT };                                               # Directory for saving robots.txt file
our $ENSEMBL_MINIFIED_FILES_PATH  = defer { "$ENSEMBL_WEBROOT/minified" };                                    # Path for saving minified files
our $ENSEMBL_OPENSEARCH_PATH      = defer { "$ENSEMBL_WEBROOT/opensearch" };                                  # Path for saving opensearch files
our $GOOGLE_SITEMAPS_PATH         = defer { "$ENSEMBL_WEBROOT/sitemaps" };                                  # Path for saving Google Sitemap files
our $UDC_CACHEDIR                 = defer { "$ENSEMBL_TMP_DIR/udcCache" };                                    # Directory to cache outgoing UDC requests (required for BAM files)
our $ENSEMBL_TMP_MESSAGE_FILE     = defer { "$ENSEMBL_TMP_DIR/ensembl_tmp_message" };                         # File location for the temporary message for the website

## Temporary-ish files
our $ENSEMBL_USERDATA_ROOT        = defer { $ENSEMBL_TMP_DIR };                                               # Base r/w path for files uploaded by user 
our $ENSEMBL_USERDATA_DIR         = defer { $ENSEMBL_USERDATA_ROOT };                                         # Extra level of subdirectories if required

## URLs for temporary files that need to be accessed via website
our $ENSEMBL_TMP_URL              = '/tmp';                                                                   # URL path to reach files inside ENSEMBL_TMP_DIR
our $ENSEMBL_TMP_URL_IMG          = '/img-tmp';                                                               # URL path to reach files inside ENSEMBL_TMP_DIR_IMG
our $ENSEMBL_USERDATA_URL         = '/tmp';                                                                   # URL path to reach files inside ENSEMBL_USERDATA_DIR
our $ENSEMBL_MINIFIED_URL         = '/minified';                                                              # where the server can find the minified JS, CSS, etc
our $ENSEMBL_OPENSEARCH_URL       = '/opensearch';                                                            # where the server can find opensearch xml files
our $GOOGLE_SITEMAPS_URL          = '/sitemaps';                                                              # where the Google spider can find the sitemap XML
###############################################################################


###############################################################################
## Content dirs
our @ENSEMBL_LIB_DIRS;                                                                      # locates perl library modules. Array order is maintained in @INC
our @ENSEMBL_CONF_DIRS    = ("$ENSEMBL_WEBROOT/conf");                                      # locates <species>.ini files
our @ENSEMBL_PERL_DIRS    = ("$ENSEMBL_WEBROOT/perl");                                      # locates mod-perl scripts
our @ENSEMBL_HTDOCS_DIRS  = ($ENSEMBL_DOCROOT, "$ENSEMBL_SERVERROOT/biomart-perl/htdocs");  # locates static content
###############################################################################


###############################################################################
## Genomic data served from files
our $DATAFILE_ROOT        = defer { $ENSEMBL_SERVERROOT };                                  ## Base path for ro data files
our $DATAFILE_BASE_PATH   = defer { "$DATAFILE_ROOT/data_files" };                          ## Path to ro data files
our $COMPARA_HAL_DIR      = defer { "$DATAFILE_BASE_PATH/multi/" };                         ## Path for Compara HAL files
###############################################################################


###############################################################################
## External dependencies path
our $HTSLIB_DIR           = "$ENSEMBL_SERVERROOT/htslib";
our $BIOPERL_DIR          = "$ENSEMBL_SERVERROOT/bioperl-live";
our $VCFTOOLS_PERL_LIB    = "$ENSEMBL_SERVERROOT/vcftools/lib/perl5/site_perl";
our $R2R_BIN              = "$ENSEMBL_SERVERROOT/r2r";
our $HUBCHECK_BIN         = "$ENSEMBL_SERVERROOT/hubCheck";
our $ENSEMBL_EMBOSS_PATH  = "$ENSEMBL_SERVERROOT/emboss";
our $ENSEMBL_WISE2_PATH   = "$ENSEMBL_SERVERROOT/genewise";
our $GRAPHIC_TTF_PATH     = "/etc/fonts";
our $GEOCITY_DAT          = "$ENSEMBL_SERVERROOT/geocity/GeoLiteCity.dat";
our $ENSEMBL_JAVA         = "java"; # For js/css minification
###############################################################################


###############################################################################
## See Memoize.pm for meaning of these
our $MEMOIZE_ENABLED      = 1;
our $MEMOIZE_DEBUG        = 0;
our $MEMOIZE_SIZE         = [14,32,4*1024*1024];
###############################################################################


###############################################################################
## Precache settings
our $ENSEMBL_PRECACHE_DIR     = defer { "$ENSEMBL_SYS_DIR/precache" };
our $ENSEMBL_PRECACHE_DISABLE = 0;
our $ENSEMBL_PRECACHE_DEBUG   = 0;      # change this to 1, 2 or 3 to get required level of EnsEMBL::Web::Query debug info
###############################################################################


###############################################################################
## Mart configs - just keeping flags off by default
our $ENSEMBL_MART_ENABLED         = 0;  # Setting it to non zero will make the mart links appear on the site (the server itself may not be mart)
our $ENSEMBL_MART_PLUGIN_ENABLED  = 0;  # Is set true by the mart plugin itself. No need to override it.
our $ENSEMBL_MART_SERVER          = ''; # Server address if mart server is running on another server (biomart requests get proxied to ENSEMBL_MART_SERVER)
###############################################################################


###############################################################################
## Memcached specific configs
our $ENSEMBL_MEMCACHED  = {}; # Keys 'server' [list of server:port], 'debug' [0|1] and 'default_exptime'. See EnsEMBL::Web::Cache in public-plugins for details.
###############################################################################


###############################################################################
## Page specific configurations
our $FLANK5_PERC                  = 0.02; # % 5' flanking region for images (used for region comparison and location view)
our $FLANK3_PERC                  = 0.02; # % 3' flanking region for images (used for region comparison and location view)
our $ENSEMBL_ALIGNMENTS_HIERARCHY = ['LASTZ', 'CACTUS_HAL_PW', 'TBLAT', 'LPATCH'];  # Hierarchy of alignment methods
###############################################################################


###############################################################################
## Species
###############################################################################
our $ENSEMBL_DATASETS             = [];
our $ENSEMBL_PRIMARY_SPECIES      = 'Homo_sapiens'; # Default species
our $ENSEMBL_SECONDARY_SPECIES    = undef;
our $ENSEMBL_SPECIES_ALIASES      = {};    # gets populated later by _set_species_aliases()
our %__species_aliases;
## This hash is used to configure the species available in this
## copy of EnsEMBL - comment out any lines which are not relevant
## If you add a new species MAKE sure that one of the values of the
## array is the "SPECIES_CODE" defined in the species.ini file
###############################################################################


###############################################################################
# Variables exported for ENV for apache processes
our $ENSEMBL_SETENV                   = {}; # Map of ENV variables nams to SiteDefs variable names for setting ENV (check _set_env method)
$ENSEMBL_SETENV->{'http_proxy'}       = 'HTTP_PROXY';
$ENSEMBL_SETENV->{'https_proxy'}      = 'HTTP_PROXY';
$ENSEMBL_SETENV->{'COMPARA_HAL_DIR'}  = 'COMPARA_HAL_DIR';
$ENSEMBL_SETENV->{'UDC_CACHEDIR'}     = 'UDC_CACHEDIR';
###############################################################################


###############################################################################
## Configurations to map URLs to appropriate Controllers and data Objects - DO NOT CHANGE THESE
our $OBJECT_TO_CONTROLLER_MAP = {
  Gene                => 'Page',
  Transcript          => 'Page',
  Location            => 'Page',
  Variation           => 'Page',
  StructuralVariation => 'Page',
  Regulation          => 'Page',
  Marker              => 'Page',
  GeneTree            => 'Page',
  Family              => 'Page',
  LRG                 => 'Page',
  Phenotype           => 'Page',
  Experiment          => 'Page',
  Info                => 'Page',
  Search              => 'Page',
  UserConfig          => 'Modal',
  UserData            => 'Modal',
  Help                => 'Modal',
};
our $ALLOWED_URL_CONTROLLERS = [qw(Ajax Component ComponentAjax Config CSS DataExport Download Export ImageExport Json MultiSelector Psychic Share ZMenu)];
our $OBJECT_PARAMS = [
  [ 'Phenotype'           => 'ph'  ],
  [ 'Location'            => 'r'   ],
  [ 'Gene'                => 'g'   ],
  [ 'Transcript'          => 't'   ],
  [ 'Variation'           => 'v'   ],
  [ 'StructuralVariation' => 'sv'  ],
  [ 'Regulation'          => 'rf'  ],
  [ 'Experiment'          => 'ex'  ],
  [ 'Marker'              => 'm'   ],
  [ 'LRG'                 => 'lrg' ],
  [ 'GeneTree'            => 'gt'  ],
  [ 'Family'              => 'fm'  ],
];
###############################################################################


#### END OF VARIABLE DEFINITION ####


###############################################################################
# You should not change anything below here
###############################################################################

our $ENSEMBL_PLUGINS      = []; # List of all plugins enabled - populated by _populate_plugins_list()
our $ENSEMBL_IDS_USED     = {}; # All plugins with extra info for perl.startup output - populated by _populate_plugins_list()
our $ENSEMBL_PLUGINS_USED = {}; # Identities being used for plugins - needed by perl.startup - populated by _populate_plugins_list()
our $ENSEMBL_PLUGIN_ROOTS = []; # Populated by _update_conf()
our $ENSEMBL_COHORT       = ''; # Populated by import
our $ENSEMBL_BASE_URL;          # Populated by import
our $ENSEMBL_SITE_URL;          # Populated by import
our $ENSEMBL_CONFIG_FILENAME;   # Populated by import
our $ENSEMBL_STATIC_SERVERNAME; # Populated by import
our $ENSEMBL_STATIC_BASE_URL;   # Populated by import
our $ENSEMBL_TEMPLATE_ROOT;     # Populated by import
our $ENSEMBL_MART_SERVERNAME;   # Populated by _set_dedicated_mart()

my $_VERBOSE;
my $_IMPORTED;

sub import {

  if ($_IMPORTED) {
    return;
  }

  $_IMPORTED = 1;
  $_VERBOSE = grep $_ eq 'verbose', @_;

  # Populate $ENSEMBL_PLUGINS (Not loading all plugins' SiteDefs yet)
  _populate_plugins_list($ENSEMBL_SERVERROOT, $ENSEMBL_WEBROOT, $ENV{'ENSEMBL_PLUGINS_ROOTS'});
  die "ERROR: ENSEMBL_PLUGINS not populated\n" unless scalar @$ENSEMBL_PLUGINS;

  # Load all plugins SiteDefs
  _update_conf();

  # Populate species aliases
  _set_species_aliases();

  # Set Mart servername
  _set_dedicated_mart();

  # Set ENV variables as specified in ENSEMBL_SETENV
  _set_env();

  # Finalise other configs that depends upon plugins SiteDefs.
  $ENSEMBL_PROXY_PORT   = $ENSEMBL_PORT unless $ENSEMBL_PROXY_PORT && $ENSEMBL_PROXY_PORT ne '';
  $ENSEMBL_SERVERNAME ||= $ENSEMBL_SERVER;

  $ENSEMBL_BASE_URL = "$ENSEMBL_PROTOCOL://$ENSEMBL_SERVERNAME" . (
    $ENSEMBL_PROXY_PORT == 80  && $ENSEMBL_PROTOCOL eq 'http' ||
    $ENSEMBL_PROXY_PORT == 443 && $ENSEMBL_PROTOCOL eq 'https' ? '' : ":$ENSEMBL_PROXY_PORT"
  );

  $ENSEMBL_SITE_URL          = join '/', $ENSEMBL_BASE_URL, $ENSEMBL_SITE_DIR || (), '';
  $ENSEMBL_STATIC_SERVERNAME = $ENSEMBL_STATIC_SERVER || $ENSEMBL_SERVERNAME;
  $ENSEMBL_STATIC_SERVER     = "$ENSEMBL_PROTOCOL://$ENSEMBL_STATIC_SERVER" if $ENSEMBL_STATIC_SERVER;
  $ENSEMBL_STATIC_BASE_URL   = $ENSEMBL_STATIC_SERVER || $ENSEMBL_BASE_URL;
  $ENSEMBL_COHORT            = [ grep $ENSEMBL_IDS_USED->{$_}, sort keys %$ENSEMBL_IDS_USED ]->[0] || $ENSEMBL_SERVERROOT;

  ### Quick hack to add machine name to config.packed
  $ENSEMBL_COHORT = $ENSEMBL_COHORT =~ /^cluster:/ ? "$ENSEMBL_SERVERNAME-$ENSEMBL_COHORT" : $ENSEMBL_COHORT;

  $ENSEMBL_CONFIG_FILENAME   = sprintf "%s.%s", $ENSEMBL_COHORT =~ s/\W+/-/gr, $ENSEMBL_CONFIG_FILENAME_SUFFIX;
  $ENSEMBL_TEMPLATE_ROOT     = "$ENSEMBL_SERVERROOT/biomart-perl/conf";

  _verbose_params() if $_VERBOSE;
}

sub _verbose_params {
  ## Prints a list of all the parameters and their values
  my $params = {};

  no strict qw(refs);

  warn "SiteDefs configurations:\n";

  for (sort keys %{'SiteDefs::'}) {

    next if $_ eq lc $_;

    my $sym_name  = "SiteDefs::$_";
    my $sym       = *$sym_name;

    next unless ref(\$sym) eq 'GLOB';

    warn sprintf "%50s: %s\n", $_, ref *{$sym}{'CODE'} ? 'SUBROUTINE' : ref $$sym || $$sym // 'undef';
  }
}

sub _update_conf {
  ## @private
  ## Updates configs acording to plugins SiteDefs
  my @plugins = reverse @{$ENSEMBL_PLUGINS || []}; # Go on in reverse order so that the first plugin is the most important

  my (%order_validation, $count);

  while (my ($dir, $name) = splice @plugins, 0, 2) {
    my $plugin_conf = "${name}::SiteDefs";

    if (!-d $dir) {
      die "[ERROR] Plugin $name could not be loaded: $dir not found.\n";
    }

    eval qq{ package $plugin_conf; use ConfigDeferrer qw(defer required); };  # export 'defer' and 'required' to the plugin SiteDefs
    eval qq{ require '$dir/conf/SiteDefs.pm' };                               # load the actual plugin SiteDefs

    if ($@) {
      my $message = "Can't locate $dir/conf/SiteDefs.pm in";
      warn "Error requiring $plugin_conf:\n$@" unless $@ =~ m:$message:;
    } else {

      # create datastructures for validating the rules in the end
      my $validation = $plugin_conf->can('validation');
      $order_validation{$name} = $validation ? $validation->() : {};

      # Update config according to the plugin
      my $update_conf = $plugin_conf->can('update_conf');

      if ($update_conf) {
        $update_conf->();
        warn "Updating SiteDefs with $name plugin\n" if $_VERBOSE;
      } else {
        warn "Not updating SiteDefs with $plugin_conf: Function update_conf not defined in $dir/conf/SiteDefs.pm\n" if $_VERBOSE;
      }

      register_deferred_configs();
    }

    $order_validation{$name}{'order'} = ++$count;

    unshift @ENSEMBL_PERL_DIRS,     "$dir/perl";
    unshift @ENSEMBL_HTDOCS_DIRS,   "$dir/htdocs";
    unshift @$ENSEMBL_PLUGIN_ROOTS, $name;
    push    @ENSEMBL_CONF_DIRS,     "$dir/conf";
  }
  build_deferred_configs();
  validate_required_configs();

  my $current_plugin_type = 'functionality';

  # plugin order validation
  foreach my $plugin (sort { $order_validation{$a}{'order'} <=> $order_validation{$b}{'order'} } keys %order_validation) {

    # requires, before, after keys could be strings or arrayrefs
    for (qw(requires before after)) {
      $order_validation{$plugin}{$_} = $order_validation{$plugin}{$_} && !ref $order_validation{$plugin}{$_}
        ? [$order_validation{$plugin}{$_}]
        : $order_validation{$plugin}{$_} || [];
    }

    # requires
    foreach my $required (@{$order_validation{$plugin}{'requires'}}) {
      if (!exists $order_validation{$required}) {
        warn "Plugin Validation Error: Plugin $plugin needs plugin $required to be present.\n";
      }
    }

    # after
    foreach my $after (@{$order_validation{$plugin}{'after'}}) {
      if (exists $order_validation{$after} && $order_validation{$after}{'order'} >= $order_validation{$plugin}{'order'}) {
        warn "Plugin Validation Error: Plugin $plugin needs to be loaded after plugin $after.\n";
      }
    }

    # before
    foreach my $before (@{$order_validation{$plugin}{'before'}}) {
      if (exists $order_validation{$before} && $order_validation{$before}{'order'} <= $order_validation{$before}{'order'}) {
        warn "Plugin Validation Error: Plugin $plugin needs to be loaded before plugin $before.\n";
      }
    }

    # type
    if (my $type = $order_validation{$plugin}{'type'}) {
      if ($type eq 'functionality') {
        warn "Plugin Validation Error: Plugin $plugin of type 'functionality' being loaded after type 'configuration'.\n" if $current_plugin_type eq 'configuration';
      } elsif ($type eq 'configuration') {
        $current_plugin_type = 'configuration';
      } else {
        warn "Plugin Validation Error: Plugin $plugin type '$type' is invalid. Should be either 'functionality' or 'configuration'.\n";
      }
    }
  }

  push @ENSEMBL_LIB_DIRS, (
    "$ENSEMBL_WEBROOT/modules",
    $BIOPERL_DIR,
    $VCFTOOLS_PERL_LIB,
    "$ENSEMBL_SERVERROOT/biomart-perl/lib",
    "$ENSEMBL_SERVERROOT/ensembl-orm/modules",
    "$ENSEMBL_SERVERROOT/ensembl-io/modules",
    "$ENSEMBL_SERVERROOT/ensembl-funcgen/modules",
    "$ENSEMBL_SERVERROOT/ensembl-variation/modules",
    "$ENSEMBL_SERVERROOT/ensembl-compara/modules",
    "$ENSEMBL_SERVERROOT/ensembl/modules",
  );
}

sub _set_species_aliases {
  ## Add self referential elements to ENSEMBL_SPECIES_ALIASES
  ## And one without the _ in...
  $ENSEMBL_DATASETS = [ sort keys %__species_aliases ] unless scalar @$ENSEMBL_DATASETS;

  foreach my $name (@$ENSEMBL_DATASETS) {
    $ENSEMBL_SPECIES_ALIASES->{lc $_} = $name for @{$__species_aliases{$name}};

    my $key = lc $name;
    $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # homo_sapiens

    $key =~ s/\.//g;
    $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # homosapiens

    $key = lc $name;
    $key =~ s/^([a-z])[a-z]*_/$1_/g;
    $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # h_sapiens

    $key =~ s/_/\./g;
    $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # h.sapiens

    $key =~ s/_//g;
    $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # hsapiens
  }

  my @temp_species = @$ENSEMBL_DATASETS;

  unless ($__species_aliases{$ENSEMBL_PRIMARY_SPECIES}) {
    warn qq(Species "$ENSEMBL_PRIMARY_SPECIES" not defined in ENSEMBL_SPECIES_ALIASES);
    $ENSEMBL_PRIMARY_SPECIES = shift @temp_species;
  }

  unless ($__species_aliases{$ENSEMBL_SECONDARY_SPECIES}) {
    warn qq(Species "$ENSEMBL_SECONDARY_SPECIES" not defined in ENSEMBL_SPECIES_ALIASES);
    $ENSEMBL_SECONDARY_SPECIES = shift @temp_species;
  }

  $ENSEMBL_SECONDARY_SPECIES = shift @temp_species if $ENSEMBL_SECONDARY_SPECIES eq $ENSEMBL_PRIMARY_SPECIES;
}

sub _set_dedicated_mart {
  ## Set ENSEMBL_MART_SERVERNAME if mart is running on a separate dedicated server
  if ($ENSEMBL_MART_ENABLED && !$ENSEMBL_MART_PLUGIN_ENABLED && $ENSEMBL_MART_SERVER) {
    $ENSEMBL_MART_SERVERNAME = sprintf '%s://%s', $ENSEMBL_PROTOCOL, $ENSEMBL_MART_SERVER;
    $ENSEMBL_SETENV->{'ENSEMBL_MART_SERVERNAME'} = 'ENSEMBL_MART_SERVERNAME';
  }
}

sub _get_serverroot {
  ## @private
  ## Gets the root folder path for ensembl-webcode
  my $file            = shift;
  my ($volume, $dir)  = File::Spec->splitpath($file);

  return File::Spec->catpath($volume, [split '/ensembl-webcode', $dir]->[0]) || '.';
}

sub _populate_plugins_list {
  ## @private
  ## Populates ENSEMBL_PLUGINS from Plugins.pm or AutoPlugins.pm
  my ($server_root, $web_root, $plugins_root) = @_;

  $plugins_root ||= '*-plugins';

  my @plugins_paths = ($web_root, "$server_root/$plugins_root/".getpwuid($>));

  # Define Plugin directories
  if (-e "$web_root/conf/Plugins.pm") {
    eval qq(require '$web_root/conf/Plugins.pm');
    warn "Error requiring plugin file:\n$@" if $@;
  }

  # Load AutoIdentities files
  my @ensembl_identity;
  my $i_paths = join(" ", map {"$_/conf/AutoIdentities.pm"} @plugins_paths);
  my $a_paths = join(" ", map {"$_/conf/AutoPlugins.pm"}    @plugins_paths);

  foreach my $f (glob $i_paths) {
    our $ENSEMBL_IDENTITIES = []; # populated via AutoIdentities.pm files
    next unless -e $f;
    eval qq(require '$f');
    if ($@) {
      warn "Error requiring autoidentities file '$f': $@\n";
      next;
    }
    push @ensembl_identity, @{$_->()} for @$ENSEMBL_IDENTITIES;
  }
  warn " Server has identities\n    ".join("\n    ", @ensembl_identity)."\n" if $_VERBOSE;

  # Load AutoPlugin files
  my $paired            = sub { map {[$_[$_*2],$_[$_*2+1]]} 0..int(@_/2)-1 };
  my @plugins_seen      = map { $_->[0] } $paired->(@$ENSEMBL_PLUGINS);

  $ENSEMBL_IDS_USED->{'- direct -'} = 0;
  $ENSEMBL_PLUGINS_USED->{$_} = [0] for @plugins_seen;


  my $code = 1;
  my (%plugins_list, %plugins_priority, @identity_maps);
  foreach my $f (glob $a_paths) {
    our $ENSEMBL_AUTOPLUGINS  = {}; # populated via AutoPlugins.pm files
    our $ENSEMBL_IDENTITY_MAP = {}; # populated via AutoPlugins.pm files
    next unless -e $f;
    eval qq(require '$f');
    if ($@) {
      warn "Error requiring autoplugin file '$f': $@\n";
      next;
    }
    push @identity_maps, $ENSEMBL_IDENTITY_MAP;
    foreach my $k (keys %$ENSEMBL_AUTOPLUGINS) {
      my $prio = 50;
      my $orig_k = $k;
      $prio = $1 if $k =~ s/^(\d+)!//;
      $plugins_priority{$k} ||= $prio;
      push @{$plugins_list{$k}||=[]},@{$ENSEMBL_AUTOPLUGINS->{$orig_k}};
    }
  }

  # Calculate mapped identities
  my $any_maps = 1;
  while ($any_maps) {
    $any_maps = 0;
    foreach my $map (@identity_maps) {
      foreach my $id (keys %$map) {
        next if grep { $_ eq $id } @ensembl_identity;
        my $re = $map->{$id};
        next unless grep { /$re/ } @ensembl_identity;
        warn " Server has mapped identity $id ($re)\n" if $_VERBOSE;
        $any_maps = 1;
        push @ensembl_identity,$id;
      }
    }
  }

  # Process AutoPlugin files
  foreach my $k (sort { $plugins_priority{$a} <=> $plugins_priority{$b} } keys %plugins_list) {
    if (grep { $_ eq $k } @ensembl_identity) {
      warn " Loading $k\n";
      my @to_add;
      foreach my $p ($paired->(@{$plugins_list{$k}||[]})) {
        unless($ENSEMBL_IDS_USED->{$k}) {
          $ENSEMBL_IDS_USED->{$k} = $code++;
        }
        $ENSEMBL_PLUGINS_USED->{$p->[0]} ||= [];
        push @{$ENSEMBL_PLUGINS_USED->{$p->[0]}},$ENSEMBL_IDS_USED->{$k};
        next if grep { $p->[0] eq $_ } @plugins_seen;
        push @to_add,$p->[0],$p->[1];
        push @plugins_seen,$p->[0];
      }
      push @$ENSEMBL_PLUGINS,@to_add;
    }
  }
}

sub _set_env {
  ## Sets env variables for the apache server process or any script that's using SiteDefs
  ## This gets called once all the plugins are loaded and deferred configs are built
  no strict qw(refs);

  if (keys %$ENSEMBL_SETENV) {
    warn "Setting ENV variables:\n" if $_VERBOSE;
    for (sort keys %$ENSEMBL_SETENV) {
      if (defined $ENSEMBL_SETENV->{$_}) {
        $ENV{$_} = ${"SiteDefs::$ENSEMBL_SETENV->{$_}"};
        warn sprintf "%50s: %s\n", $_, $ENV{$_} if $_VERBOSE;
      } else {
        delete $ENV{$_};
        warn sprintf "%50s deleted\n", $_ if $_VERBOSE;
      }
    }
  }
}

sub memcached {
  my @caller  = caller;
  die qq(SiteDefs::memcached() is not in use anymore. Set \$SiteDefs::ENSEMBL_MEMCACHED variable to a ref of hash containing keys 'server' [list of server:port], 'debug' and 'default_exptime' at $caller[1] line $caller[2].\n);
}

1;

__END__
