#!/usr/local/bin/perl -w
###############################################################################
#   
#   Name:           SiteDefs.pm
#   
#   Description:    Localisation config for Ensembl website.
#
###############################################################################

package SiteDefs;
use strict;
use Text::Wrap;
use Config;
$Text::Wrap::columns = 75;

use vars qw ( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION
  $APACHE_DIR
 $APACHE_BIN
	$BIOPERL_DIR
  $ENSEMBL_RELEASE_DATE $ENSEMBL_MIN_SPARE_SERVERS $ENSEMBL_MAX_SPARE_SERVERS $ENSEMBL_START_SERVERS
  $ENSEMBL_HELPDESK_EMAIL
  $ENSEMBL_MAIL_SERVER
  $ENSEMBL_VERSION
  $ENSEMBL_PLUGINS $ENSEMBL_PLUGIN_ROOTS
  $ENSEMBL_TMPL_CSS
  $ENSEMBL_PAGE_CSS
  $ENSEMBL_IMAGE_WIDTH
  $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
  $ENSEMBL_API_VERBOSITY $ENSEMBL_DEBUG_FLAGS
  $ENSEMBL_SERVERROOT
  $ENSEMBL_SERVER
  $ENSEMBL_PORT
  $ENSEMBL_PROXY_PORT
  $ENSEMBL_USER
  $ENSEMBL_GROUP
  $ENSEMBL_SERVERADMIN
  $ENSEMBL_SERVERNAME $ENSEMBL_PROTOCOL
  $ENSEMBL_MAIL_COMMAND
  $ENSEMBL_MAIL_ERRORS
  $ENSEMBL_ERRORS_TO
  $ENSEMBL_LOGDIR
  $ENSEMBL_PIDFILE
  $ENSEMBL_ERRORLOG
  $ENSEMBL_CUSTOMLOG
  $ENSEMBL_NGINX_PIDFILE
  $ENSEMBL_NGINX_ERRORLOG
  $ENSEMBL_TEMPLATE_ROOT
  $ENSEMBL_TMP_CREATE
  $ENSEMBL_TMP_DELETE
  $ENSEMBL_TMP_DIR_BLAST
  $ENSEMBL_TMP_DIR_BLAST_OLD
  $ENSEMBL_BLASTSCRIPT
  $ENSEMBL_TMP_DIR
  $ENSEMBL_TMP_TMP
  $ENSEMBL_TMP_URL
  $ENSEMBL_TMP_DIR_IMG
  $ENSEMBL_TMP_DIR_DOTTER
  $ENSEMBL_TMP_URL_IMG
  $ENSEMBL_TMP_DIR_CACHE
  $ENSEMBL_TMP_URL_CACHE
  $ENSEMBL_MINIAD_DIR
  $ENSEMBL_DATASETS
  $ENSEMBL_SPECIES
  $ENSEMBL_PRIMARY_SPECIES
  $ENSEMBL_SECONDARY_SPECIES
  $ENSEMBL_BASE_URL $ENSEMBL_SITE_DIR $ENSEMBL_SITE_URL
  $ENSEMBL_SPECIES_ALIASES
  $ENSEMBL_ENCRYPT_0
  $ENSEMBL_ENCRYPT_1 $ENSEMBL_ENCRYPT_EXPIRY $ENSEMBL_ENCRYPT_REFRESH
  $ENSEMBL_ENCRYPT_2
  $ENSEMBL_ENCRYPT_3
  $ENSEMBL_USERDB_TYPE
  $ENSEMBL_USERDB_PORT
  $ENSEMBL_USERDB_NAME
  $ENSEMBL_USERDB_HOST
  $ENSEMBL_USERDB_USER
  $ENSEMBL_USERDB_PASS
  $ENSEMBL_COOKIEHOST
  $ENSEMBL_USER_COOKIE
  $ENSEMBL_USER_ID
  $ENSEMBL_USERADMIN_ID
  $ENSEMBL_WEBADMIN_ID
  $ENSEMBL_LOGINS
  $ENSEMBL_USER_DATA_TABLE
  $ENSEMBL_GROUP_DATA_TABLE
  $ENSEMBL_SESSION_COOKIE
  $ENSEMBL_CONFIG_FILENAME
  $ENSEMBL_CONFIG_BUILD
  $ENSEMBL_HAS_C_EXTENSIONS
  $ENSEMBL_LONGPROCESS_MINTIME
  $ENSEMBL_APACHE_RELOAD
  $ENSEMBL_SITETYPE
  $ARCHIVE_VERSION
  $EARLIEST_ARCHIVE
  $BIOMART_URL
  $MART_HELP_DESK
  %ENSEMBL_SETENV
  @ENSEMBL_CONF_DIRS
  @ENSEMBL_PERL_DIRS
  @ENSEMBL_HTDOCS_DIRS
  @ENSEMBL_LIB_DIRS
  $ENSEMBL_SHORTEST_ALIAS
  $MART_ENSEMBL_LINKS
  $ENSEMBL_MART_ENABLED
  $ENSEMBL_BLAST_ENABLED
  $ENSEMBL_FLAG_NAMES
);

use Sys::Hostname::Long;
use Exporter();
@ISA=qw(Exporter);

$VERSION                   = 55;
$ARCHIVE_VERSION           = "Jul2009";    # Change this to the archive site for this version
$ENSEMBL_RELEASE_DATE      = 'July 2009';

$ENSEMBL_MIN_SPARE_SERVERS =  5;
$ENSEMBL_MAX_SPARE_SERVERS = 20;
$ENSEMBL_START_SERVERS     =  7;

#### START OF VARIABLE DEFINITION #### DO NOT REMOVE OR CHANGE THIS COMMENT ####

###############################################################################
####################### LOCAL CONFIGURATION VARIABLES #########################
###############################################################################

##########################################################################
# You need to change the following server root setting.  It points to the
# directory that contains htdocs, modules, perl, ensembl, etc
# DO NOT LEAVE A TRAILING '/' ON ENSEMBL_SERVERROOT
##########################################################################
use File::Spec;

my( $volume, $dir, $file ) = File::Spec->splitpath( __FILE__ );
my @dir = File::Spec->splitdir( $dir );
my @clean_directory = ();
my $current_directory   = File::Spec->curdir();
my $parent_directory    = File::Spec->updir();
foreach( @dir ) {
  next if $_ eq $current_directory; ## If we have a "." in the path ignore
  if( $_ eq $parent_directory ) {
    pop @clean_directory;           ## If we have a ".." in the path remove the parent directory
  } else {
    push @clean_directory, $_;      ## Otherwise add it!
  }
}

#warn ".......... @clean_directory ..............";
my $CONF_DIR = 'conf';
while( ($CONF_DIR = pop @clean_directory) !~ /^conf/) { 1; }     ## Remove up to the last "conf" directory...

$ENSEMBL_SERVERROOT = File::Spec->catpath( $volume, File::Spec->catdir( @clean_directory ) );
$ENSEMBL_SERVERROOT = '.' unless $ENSEMBL_SERVERROOT;
$APACHE_DIR         = "$ENSEMBL_SERVERROOT/apache2";
$APACHE_BIN = "APACHE_DIR/bin/httpd";

$BIOPERL_DIR        = "$ENSEMBL_SERVERROOT/bioperl-live";
#warn "$ENSEMBL_SERVERROOT";
## Define Plugin directories....
eval qq(require '$ENSEMBL_SERVERROOT/$CONF_DIR/Plugins.pm');
error( "Error requiring plugin file:\n$@" ) if $@;

$ENSEMBL_MART_ENABLED   = 0;
$ENSEMBL_BLAST_ENABLED  = 0;

$ENSEMBL_SERVER         = Sys::Hostname::Long::hostname_long();  # Local machine name

$ENSEMBL_PORT           = 80;
$ENSEMBL_PROXY_PORT     = undef; # Port used for self-referential URLs: 

                                 # Set to undef if not using proxy-forwarding

$ENSEMBL_SITETYPE       = "Ensembl";
$EARLIEST_ARCHIVE       = 25;
$ENSEMBL_USER           = getpwuid($>); # Auto-set web serveruser
$ENSEMBL_GROUP          = getgrgid($)); # Auto-set web server group

$ENSEMBL_SERVERADMIN    = 'webmaster&#064;mydomain.org';
$ENSEMBL_HELPDESK_EMAIL = $ENSEMBL_SERVERADMIN;
$ENSEMBL_MAIL_SERVER    = 'mail.mydomain.org';
$ENSEMBL_SERVERNAME     = 'www.mydomain.org';
$ENSEMBL_PROTOCOL       = 'http';
$ENSEMBL_MAIL_COMMAND   = '/usr/bin/Mail -s';               # Mail command
$ENSEMBL_MAIL_ERRORS    = '0';                              # Do we want to email errors?
$ENSEMBL_ERRORS_TO      = 'webmaster&#064;mydomain.org';    # ...and to whom?

$ENSEMBL_API_VERBOSITY              = 'WARNING';
#    0 OFF NOTHING NONE
# 1000 EXCEPTION THROW
# 2000 (DEFAULT) WARNING WARN
# 3000 DEPRECATE DEPRECATED
# 4000 INFO
# *1e6 ON ALL

$ENSEMBL_DEBUG_FLAGS                = 1;

our $ENSEMBL_DEBUG_VERBOSE_ERRORS = 0;
our $ENSEMBL_FLAG_NAMES_HR = [];

$ENSEMBL_FLAG_NAMES = [qw(
  GENERAL_ERRORS
  DRAWING_CODE
  SD_AUTOLOADER
  HANDLER_ERRORS
  LONG_PROCESS
  PERL_PROFILER
  TIMESTAMPED_LOGS
  TREE_DUMPS
  REFERER
  MAGIC_MESSAGES
  JAVASCRIPT_DEBUG
  MEMCACHED
  EXTERNAL_COMMANDS
  WIZARD_MESSAGES
  VERBOSE_STARTUP
)];

my $i=0;

foreach( @$ENSEMBL_FLAG_NAMES ) {
no strict 'refs';
  my $variable_name = 'SiteDefs::ENSEMBL_DEBUG_'.$_;
  $$variable_name = 1<<($i++);
  $ENSEMBL_DEBUG_VERBOSE_ERRORS <<=1;
  $ENSEMBL_DEBUG_VERBOSE_ERRORS +=1;
  (my $t = ucfirst(lc($_)) ) =~ s/_/ /g;
  push @{$ENSEMBL_FLAG_NAMES_HR}, $t;
}

#####################
# Apache files
$ENSEMBL_PIDFILE = undef;
$ENSEMBL_ERRORLOG = undef;
$ENSEMBL_CUSTOMLOG = undef;

$ENSEMBL_TMPL_CSS = '/css/ensembl.css';
$ENSEMBL_PAGE_CSS = '/css/content.css';
$ENSEMBL_IMAGE_WIDTH = 800;
#####################
# TMP dirs
# ENSEMBL_TMP_DIR points to a filesystem dir
# ENSEMBL_TMP_URL points to a URL location. 
# httpd.conf creates an alias for ENSEMBL_TMP_URL to ENSEMBL_TMP_DIR
# httpd.conf also validates the existence of ENSEMBL_TMP_DIR.

$ENSEMBL_TMP_CREATE     = 1; # Create tmp dirs on server startup if not found?
$ENSEMBL_TMP_DELETE     = 0; # Delete files from the tmp dir on server startup? 
$ENSEMBL_TMP_TMP        = '/tmp';
$ENSEMBL_TMP_URL        = '/tmp';
$ENSEMBL_TMP_URL_IMG    = '/img-tmp';
$ENSEMBL_TMP_URL_CACHE  = '/img-cache';

#$ENSEMBL_TMP_DIR_BLAST  = '/ensemblweb/shared/data/blastqueue';
#$ENSEMBL_TMP_DIR_BLAST_OLD  = '/ensweb/shared/data/blastqueue';
$ENSEMBL_BLASTSCRIPT    = undef;
$ENSEMBL_REGISTRY       = undef;
$ENSEMBL_PRIVATE_AUTH   = undef;
####################
# Environment variables to set using the SetEnv directive
%ENSEMBL_SETENV =
    ( # --- LSF ---
      LSF_BINDIR      => $ENV{LSF_BINDIR}      || '',
      LSF_SERVERDIR   => $ENV{LSF_SERVERDIR}   || '',
      LSF_LIBDIR      => $ENV{LSF_LIBDIR}      || '',
      XLSF_UIDDIR     => $ENV{XLSF_UIDDIR}     || '',
      LD_LIBRARY_PATH => $ENV{LD_LIBRARY_PATH} || '',
      );

####
# Content dirs
# @ENSEMBL_CONF_DIRS   locates <species>.ini files
# @ENSEMBL_PERL_DIRS   locates mod-perl scripts
# @ENSEMBL_HTDOCS_DIRS locates static content
# @ENSEMBL_LIB_DIRS    locates perl library modules. 
#                      Array order is maintained in @INC
@ENSEMBL_CONF_DIRS    = ($ENSEMBL_SERVERROOT.'/'.$CONF_DIR);
@ENSEMBL_PERL_DIRS    = (
  $ENSEMBL_SERVERROOT.'/perl',
);

@ENSEMBL_HTDOCS_DIRS  = (
  $ENSEMBL_SERVERROOT.'/htdocs',
  $ENSEMBL_SERVERROOT.'/biomart-perl/htdocs'
);

###############################################################################
######################### END OF LOCAL CONFIGURATION SECTION ##################
###############################################################################

###############################################################################
## Choice of species...
###############################################################################

$ENSEMBL_PRIMARY_SPECIES  = 'Homo_sapiens'; # Default species

## This hash is used to configure the species available in this
## copy of EnsEMBL - comment out any lines which are not relevant
## If you add a new species MAKE sure that one of the values of the
## array is the "SPECIES_CODE" defined in the species.ini file

our %__species_aliases = ();

###############################################################################
## Web user datbase - used to store information about settings, e.g. DAS
## contigview and cytoview options.
###############################################################################

$ENSEMBL_VERSION                = $VERSION;
$ENSEMBL_USERDB_TYPE            = 'mysql';
$ENSEMBL_USERDB_NAME            = 'ensembl_web_user_db';
$ENSEMBL_USERDB_USER            = 'mysqluser';
$ENSEMBL_USERDB_HOST            = 'localhost';
$ENSEMBL_USERDB_PORT            =  3305;
$ENSEMBL_USERDB_PASS            = '';

$ENSEMBL_USER_COOKIE            = 'ENSEMBL_WWW_USER';
$ENSEMBL_USER_ID                = 0;
$ENSEMBL_USERADMIN_ID           = 0;
$ENSEMBL_WEBADMIN_ID            = 0;
$ENSEMBL_LOGINS                 = 0;
$ENSEMBL_USER_DATA_TABLE        = 'user_record';
$ENSEMBL_GROUP_DATA_TABLE       = 'group_record';
$ENSEMBL_SESSION_COOKIE         = 'ENSEMBL_WWW_SESSION';
$ENSEMBL_COOKIEHOST             = '';       #.ensembl.org';

$ENSEMBL_ENCRYPT_0              = 0x16a3b3; # Encryption keys for session
$ENSEMBL_ENCRYPT_1              = 'a9';     # Encryption keys for session
$ENSEMBL_ENCRYPT_2              = 'xX';     # Encryption keys for session
$ENSEMBL_ENCRYPT_3              = '2Q';     # Encryption keys for session
$ENSEMBL_ENCRYPT_EXPIRY         = 60;       # Cookies last 60 days 
$ENSEMBL_ENCRYPT_REFRESH        = 30;       # Refresh cookies with less than 30 days to go

$ENSEMBL_MINIAD_DIR             = $ENSEMBL_SERVERROOT.'/htdocs/img/mini-ads/';

###############################################################################
## General systems bumf
###############################################################################

$ENSEMBL_CONFIG_FILENAME        = 'config.packed';
$ENSEMBL_CONFIG_BUILD           = 0; # Build config on server startup?
                                     # Setting to 0 will try to recover from
                                     # $ENSEMBL_CONFIG_FILENAME on startup
$ENSEMBL_APACHE_RELOAD          = 0; # Debug setting - set to 0 for release

$ENSEMBL_HAS_C_EXTENSIONS       = 1;
$ENSEMBL_LONGPROCESS_MINTIME    = 10;

###############################################################################
##
## PLUGIN CODE.... We need to use the plugin modules
## 
## First of all look in "Plugins.pm" to get the definitions...
##
###############################################################################

sub tmp {
  my $tmp_dir = shift;

  $SiteDefs::ENSEMBL_TMP_DIR        = $tmp_dir;
  $SiteDefs::ENSEMBL_TMP_DIR_IMG    = "$tmp_dir/img/tmp";
  $SiteDefs::ENSEMBL_TMP_DIR_CACHE  = "$tmp_dir/img/cache";
  $SiteDefs::ENSEMBL_TMP_DIR_DOTTER = "$tmp_dir/dotter";
  $SiteDefs::ENSEMBL_TMP_DIR_BLAST  = "$tmp_dir/blastqueue";
}

sub logs {
  my $log_dir = shift;
  my $datestamp = '';
  if( $SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_TIMESTAMPED_LOGS ) {
    my @time = gmtime();
    $datestamp = sprintf( ".%04d-%02d-%02d-%02d-%02d-%02d", $time[5]+1900, $time[4]+1, @time[3,2,1,0] );
  }

## Set all log files into the /ensemblweb/tmp/logs/uswest/ directory
  my $log_prefix                    = "$log_dir/".$SiteDefs::ENSEMBL_SERVER;
  $SiteDefs::ENSEMBL_LOGDIR         = "$log_dir";
  $SiteDefs::ENSEMBL_PIDFILE        = "$log_prefix.httpd.pid";
  $SiteDefs::ENSEMBL_ERRORLOG       = "$log_prefix$datestamp.error_log";
  $SiteDefs::ENSEMBL_CUSTOMLOG      = "$log_prefix$datestamp.access_log ensembl_extended";
}

sub memcached {
  my $pars = shift;
  $pars->{'servers'}  = [] unless exists $pars->{'servers'};
  unless( @{$pars->{'servers'}} ) {
    $SiteDefs::ENSEMBL_MEMCACHED = undef;
    return;
  }
  $pars->{'debug'}    = 0  unless exists $pars->{'debug'};
  $pars->{'hm_stats'} = 0  unless exists $pars->{'hm_stats'};
  
  my %flags = map { ( $_ => 1) } qw( 
    PLUGGABLE_PATHS
    STATIC_PAGES_CONTENT
    WEBSITE_DB_DATA
    USER_DB_DATA
    DYNAMIC_PAGES_CONTENT
    TMP_IMAGES
    ORDERED_TREE
    OBJECTS_COUNTS
    IMAGE_CONFIG
  );
  foreach my $k ( keys %{$pars->{'flags'}} ) {
    if( $pars->{'flags'}{$k} ) {
      $flags{ $k } = 1;
    } else {
      delete $flags{ $k };
    }
  }
  $pars->{'flags'} = [ keys %flags ];

  $SiteDefs::ENSEMBL_MEMCACHED = $pars;
}

=for Information

Use flags to enable what you would like to cache:

 * PLUGGABLE_PATHS       - paths to pluggable scripts and static files
 * STATIC_PAGES_CONTENT  - .html pages content, any pages which SendDecPafe handler is responsible for
 * WEBSITE_DB_DATA       - website db data queries results
 * USER_DB_DATA          - user and group db data queries results (records, etc.)
 * DYNAMIC_PAGES_CONTENT - all dynamic ajax responses
 * TMP_IMAGES            - temporary images (the one you see actual genomic data on) and their imagemaps
 * ORDERED_TREE          - navigation tree
 * OBJECTS_COUNTS        - defferent counts for objects like gene, transcript, location, etc...
 * IMAGE_CONFIG          - Image configurations

=cut

sub error {
  my $message = join "\n", @_;
  $message =~ s/\s+$//sm;
  warn "#" x 78, "\n",
       wrap("# ","# ", $message ),
       "\n", "#" x 78, "\n";
}

logs("$ENSEMBL_SERVERROOT/logs");
tmp( "$ENSEMBL_SERVERROOT/tmp" );

my @T = reverse @{$ENSEMBL_PLUGINS||[]};
while( my( $dir, $name ) = splice(@T,0,2)  ) {
  my $plugin_conf = $name."::SiteDefs";
  eval "require '$dir/conf/SiteDefs.pm'";
  if($@) {
    my $message = "Can't locate $dir/conf/SiteDefs.pm in";
    error( "Error requiring $plugin_conf:\n$@" ) unless $@ =~ m:$message:;
  } else {
    my $FN = $plugin_conf.'::update_conf';
    eval "$FN()";
    if( $@ ) {
      my $message = "Undefined subroutine &$FN called at ";
      if( $@ =~ /$message/ ) {
        error( "Function $FN not defined in $dir/conf/SiteDefs.pm" );
      } else {       
        error( "Error calling $FN in $dir/conf/SiteDefs.pm\n$@" );
      }
    }
  }
}


#### END OF VARIABLE DEFINITION #### DO NOT REMOVE OR CHANGE THIS COMMENT ####
###############################################################################
# You should not change anything below here
###############################################################################

@ENSEMBL_LIB_DIRS     = (
  $APACHE_DIR."lib/perl5/site_perl/$Config{'version'}/$Config{archname}/",
  $ENSEMBL_SERVERROOT.'/ensembl/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-compara/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-draw/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-variation/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-functgenomics/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-external/modules',
  $ENSEMBL_SERVERROOT.'/biomart-perl/lib',
  $BIOPERL_DIR,
  $ENSEMBL_SERVERROOT.'/modules',
);

@T = reverse @{$ENSEMBL_PLUGINS||[]}; ## These have to go on in reverse order...
$ENSEMBL_PLUGIN_ROOTS = ();
while( my( $dir, $name ) = splice(@T,0,2)  ) {
  unshift @ENSEMBL_PERL_DIRS,     $dir.'/perl'; 
  unshift @ENSEMBL_HTDOCS_DIRS,   $dir.'/htdocs'; 
  unshift @$ENSEMBL_PLUGIN_ROOTS, $name;
  push    @ENSEMBL_CONF_DIRS,     $dir.'/conf'; 
  unshift @ENSEMBL_LIB_DIRS,      $dir.'/modules';
}

@T = @{$ENSEMBL_PLUGINS||[]};         ## But these have to go on in normal order...
while( my( $name, $dir ) = splice(@T,0,2)  ) {
}

@ENSEMBL_LIB_DIRS = reverse @ENSEMBL_LIB_DIRS; # Helps getting @inc into 
                                              # right order

$ENSEMBL_PROXY_PORT = $ENSEMBL_PORT unless ( $ENSEMBL_PROXY_PORT && $ENSEMBL_PROXY_PORT ne "" );

#-# Autogeneration stuff.... DO NOT TOUCH THIS - it does nasty stuff....

## Add self refernetial elements to ENSEMBL_SPECIES_ALIASES
## And one without the _ in...

$ENSEMBL_SPECIES_ALIASES = {};
$ENSEMBL_DATASETS = [ sort keys %__species_aliases ];

foreach my $name ( @$ENSEMBL_DATASETS ) {
  foreach my $alias ( @{$__species_aliases{$name}} ) {
    $ENSEMBL_SPECIES_ALIASES->{lc($alias)} = $name;
  }
  my $key = lc($name);
  $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # homo_sapiens
  $key =~s/\.//g;
  $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # homosapiens
  $key = lc($name);
  $key =~s/^([a-z])[a-z]*_/$1_/g;
  $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # h_sapiens
  $key =~s/_/\./g;
  $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # h.sapiens
  $key =~s/_//g;
  $ENSEMBL_SPECIES_ALIASES->{$key} = $name;   # hsapiens
}
$ENSEMBL_SHORTEST_ALIAS = {};
foreach my $key (keys %$ENSEMBL_SPECIES_ALIASES) {
  my $bin = $ENSEMBL_SPECIES_ALIASES->{$key};
  $ENSEMBL_SHORTEST_ALIAS->{$bin} = $key if !exists($ENSEMBL_SHORTEST_ALIAS->{$bin}) ||
    length($key) < length($ENSEMBL_SHORTEST_ALIAS->{$bin});
  
}
my @temp_species = @{$ENSEMBL_DATASETS};
unless( $__species_aliases{$ENSEMBL_PRIMARY_SPECIES} ) {
  error( qq(Species "$ENSEMBL_PRIMARY_SPECIES" not defined in ENSEMBL_SPECIES_ALIASES) );
  $ENSEMBL_PRIMARY_SPECIES = shift @temp_species;
}
unless( $__species_aliases{$ENSEMBL_SECONDARY_SPECIES} ) {
  error( qq(Species "$ENSEMBL_SECONDARY_SPECIES" not defined in ENSEMBL_SPECIES_ALIASES) );
  $ENSEMBL_SECONDARY_SPECIES = shift @temp_species;
}
$ENSEMBL_SECONDARY_SPECIES = shift @temp_species if $ENSEMBL_SECONDARY_SPECIES eq $ENSEMBL_PRIMARY_SPECIES;

$ENSEMBL_SERVERNAME ||= $ENSEMBL_SERVER;
## here we try and do the dynamic use stuff;
$BIOMART_URL = 'Multi';
$ENSEMBL_BASE_URL = "$ENSEMBL_PROTOCOL://$ENSEMBL_SERVERNAME".
  ( $ENSEMBL_PROXY_PORT==80  && $ENSEMBL_PROTOCOL eq 'http' ||
    $ENSEMBL_PROXY_PORT==443 && $ENSEMBL_PROTOCOL eq 'https' ? '' : ":$ENSEMBL_PROXY_PORT" );

$ENSEMBL_SITE_URL     = $ENSEMBL_BASE_URL.'/';
$ENSEMBL_SITE_URL    .= $ENSEMBL_SITE_DIR.'/' if $ENSEMBL_SITE_DIR;

$MART_ENSEMBL_LINKS    = $ENSEMBL_BASE_URL;
$MART_HELP_DESK        = $ENSEMBL_SITE_URL.'default/helpview';
$ENSEMBL_TEMPLATE_ROOT = $ENSEMBL_SERVERROOT.'/biomart-perl/conf';

####################
# Export by default
####################
@EXPORT = qw(
  $ENSEMBL_FLAG_NAMES
  $APACHE_DIR
  $BIOPERL_DIR
  $ENSEMBL_PLUGIN_ROOTS
  $ENSEMBL_TMPL_CSS 
  $ENSEMBL_PAGE_CSS 
  $ENSEMBL_IMAGE_WIDTH
  $ENSEMBL_PLUGINS
  $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
  $ENSEMBL_API_VERBOSITY $ENSEMBL_DEBUG_FLAGS
  $ENSEMBL_SERVERROOT
  $ENSEMBL_SERVER
  $ENSEMBL_PORT
  $ENSEMBL_PROXY_PORT
  $ENSEMBL_USER
  $ENSEMBL_GROUP
  $ENSEMBL_SERVERADMIN
  $ENSEMBL_SERVERNAME $ENSEMBL_PROTOCOL
  $ENSEMBL_MAIL_COMMAND
  $ENSEMBL_MAIL_ERRORS
  $ENSEMBL_ERRORS_TO
  $ENSEMBL_TMP_CREATE
  $ENSEMBL_TMP_DELETE
  $ENSEMBL_TMP_DIR_BLAST
  $ENSEMBL_TMP_DIR_BLAST_OLD
  $ENSEMBL_BLASTSCRIPT
  $ENSEMBL_TMP_DIR_DOTTER
  $ENSEMBL_TMP_TMP
  $ENSEMBL_TMP_DIR
  $ENSEMBL_TMP_URL
  $ENSEMBL_TMP_DIR_IMG
  $ENSEMBL_TMP_URL_IMG
  $ENSEMBL_TMP_DIR_CACHE
  $ENSEMBL_TMP_URL_CACHE
  $ENSEMBL_MINIAD_DIR
  $ENSEMBL_DATASETS
  $ENSEMBL_SPECIES
  $ENSEMBL_CONFIG_FILENAME
  $ENSEMBL_CONFIG_BUILD
  $ENSEMBL_HAS_C_EXTENSIONS
  $ENSEMBL_VERSION
  $ENSEMBL_RELEASE_DATE $ENSEMBL_MIN_SPARE_SERVERS $ENSEMBL_MAX_SPARE_SERVERS $ENSEMBL_START_SERVERS
  $ENSEMBL_HELPDESK_EMAIL
  $ENSEMBL_MAIL_SERVER
  $ENSEMBL_SHORTEST_ALIAS
  $MART_ENSEMBL_LINKS
);

############################
# Export anything asked for
############################
@EXPORT_OK = qw(
  $ENSEMBL_FLAG_NAMES
  $APACHE_DIR
	$BIOPERL_DIR
  $ENSEMBL_HELPDESK_EMAIL
  $ENSEMBL_MAIL_SERVER
  $ENSEMBL_VERSION
  $ENSEMBL_RELEASE_DATE $ENSEMBL_MIN_SPARE_SERVERS $ENSEMBL_MAX_SPARE_SERVERS $ENSEMBL_START_SERVERS
  $ENSEMBL_PLUGIN_ROOTS
  %ENSEMBL_SETENV
  @ENSEMBL_CONF_DIRS
  @ENSEMBL_PERL_DIRS
  @ENSEMBL_HTDOCS_DIRS
  @ENSEMBL_LIB_DIRS
  $ENSEMBL_SHORTEST_ALIAS

  $ENSEMBL_TMPL_CSS 
  $ENSEMBL_PAGE_CSS 
  $ENSEMBL_IMAGE_WIDTH
  $ENSEMBL_PLUGINS
  $ENSEMBL_API_VERBOSITY $ENSEMBL_DEBUG_FLAGS
  $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
  $ENSEMBL_SERVERROOT
  $ENSEMBL_SERVER
  $ENSEMBL_PORT
  $ENSEMBL_PROXY_PORT
  $ENSEMBL_USER
  $ENSEMBL_GROUP
  $ENSEMBL_SERVERADMIN
  $ENSEMBL_SERVERNAME $ENSEMBL_PROTOCOL
  $ENSEMBL_MAIL_COMMAND
  $ENSEMBL_MAIL_ERRORS
  $ENSEMBL_ERRORS_TO
  $ENSEMBL_LOGDIR
  $ENSEMBL_PIDFILE
  $ENSEMBL_ERRORLOG
  $ENSEMBL_CUSTOMLOG
  $ENSEMBL_NGINX_PIDFILE
  $ENSEMBL_NGINX_ERRORLOG
  $ENSEMBL_TMP_CREATE
  $ENSEMBL_TMP_DELETE
  $ENSEMBL_TMP_TMP
  $ENSEMBL_TMP_DIR
  $ENSEMBL_TMP_DIR_BLAST
  $ENSEMBL_TMP_DIR_BLAST_OLD
  $ENSEMBL_BLASTSCRIPT
  $ENSEMBL_TMP_DIR_DOTTER
  $ENSEMBL_TMP_DIR
  $ENSEMBL_TMP_URL
  $ENSEMBL_TMP_DIR_IMG
  $ENSEMBL_TMP_URL_IMG
  $ENSEMBL_TMP_DIR_CACHE
  $ENSEMBL_TMP_URL_CACHE
  $ENSEMBL_MINIAD_DIR
  $ENSEMBL_DATASETS
  $ENSEMBL_SPECIES
  $ENSEMBL_PRIMARY_SPECIES
  $ENSEMBL_SECONDARY_SPECIES
  $ENSEMBL_BASE_URL $ENSEMBL_SITE_DIR $ENSEMBL_SITE_URL
  $ENSEMBL_SPECIES_ALIASES
  $ENSEMBL_ENCRYPT_0
  $ENSEMBL_ENCRYPT_1 $ENSEMBL_ENCRYPT_EXPIRY $ENSEMBL_ENCRYPT_REFRESH
  $ENSEMBL_ENCRYPT_2
  $ENSEMBL_ENCRYPT_3
  $ENSEMBL_USERDB_TYPE
  $ENSEMBL_USERDB_PORT
  $ENSEMBL_USERDB_NAME
  $ENSEMBL_USERDB_HOST
  $ENSEMBL_USERDB_USER
  $ENSEMBL_USERDB_PASS
  $ENSEMBL_COOKIEHOST
  $ENSEMBL_USER_COOKIE
  $ENSEMBL_USER_ID
  $ENSEMBL_USERADMIN_ID
  $ENSEMBL_WEBADMIN_ID
  $ENSEMBL_LOGINS
  $ENSEMBL_USER_DATA_TABLE
  $ENSEMBL_GROUP_DATA_TABLE
  $ENSEMBL_SESSION_COOKIE
  $ENSEMBL_CONFIG_FILENAME
  $ENSEMBL_CONFIG_BUILD
  $ENSEMBL_HAS_C_EXTENSIONS
  $ENSEMBL_LONGPROCESS_MINTIME
  $ENSEMBL_APACHE_RELOAD
  $ENSEMBL_SITETYPE
  $ARCHIVE_VERSION
  $EARLIEST_ARCHIVE
  $MART_ENSEMBL_LINKS
  $ENSEMBL_MART_ENABLED
  $ENSEMBL_BLAST_ENABLED
);

###################################
# Export groups asked for by name
###################################
%EXPORT_TAGS = (
  ALL => [qw(
    $ENSEMBL_FLAG_NAMES
    $APACHE_DIR
    $BIOPERL_DIR
    $ENSEMBL_SHORTEST_ALIAS
    $ENSEMBL_PLUGINS $ENSEMBL_PLUGIN_ROOTS
    $ENSEMBL_TMPL_CSS 
    $ENSEMBL_PAGE_CSS 
    $ENSEMBL_IMAGE_WIDTH
    $ENSEMBL_API_VERBOSITY $ENSEMBL_DEBUG_FLAGS
    $ENSEMBL_SERVERROOT
    $ENSEMBL_SERVER
    $ENSEMBL_PORT
    $ENSEMBL_PROXY_PORT
    $ENSEMBL_USER
    $ENSEMBL_GROUP
    $ENSEMBL_SERVERADMIN
    $ENSEMBL_SERVERNAME $ENSEMBL_PROTOCOL
    $ENSEMBL_MAIL_COMMAND
    $ENSEMBL_MAIL_ERRORS
    $ENSEMBL_ERRORS_TO
    $ENSEMBL_LOGDIR
    $ENSEMBL_PIDFILE
    $ENSEMBL_ERRORLOG
    $ENSEMBL_CUSTOMLOG
    $ENSEMBL_NGINX_PIDFILE
    $ENSEMBL_NGINX_ERRORLOG
    $ENSEMBL_TMP_CREATE
    $ENSEMBL_TMP_DELETE
    $ENSEMBL_TMP_DIR_BLAST
    $ENSEMBL_TMP_DIR_BLAST_OLD
    $ENSEMBL_BLASTSCRIPT
    $ENSEMBL_TMP_DIR_DOTTER
    $ENSEMBL_TMP_TMP
    $ENSEMBL_TMP_DIR
    $ENSEMBL_TMP_URL
    $ENSEMBL_TMP_DIR_IMG
    $ENSEMBL_TMP_URL_IMG
    $ENSEMBL_TMP_DIR_CACHE
    $ENSEMBL_TMP_URL_CACHE
    $ENSEMBL_MINIAD_DIR
    $ENSEMBL_DATASETS
    $ENSEMBL_SPECIES
    $ENSEMBL_PRIMARY_SPECIES
    $ENSEMBL_SECONDARY_SPECIES
    $ENSEMBL_BASE_URL $ENSEMBL_SITE_DIR $ENSEMBL_SITE_URL
    $ENSEMBL_SPECIES_ALIASES
    $ENSEMBL_ENCRYPT_0
    $ENSEMBL_ENCRYPT_1 $ENSEMBL_ENCRYPT_EXPIRY $ENSEMBL_ENCRYPT_REFRESH
    $ENSEMBL_ENCRYPT_2
    $ENSEMBL_ENCRYPT_3
    $ENSEMBL_USERDB_TYPE
    $ENSEMBL_USERDB_PORT
    $ENSEMBL_USERDB_NAME
    $ENSEMBL_USERDB_HOST
    $ENSEMBL_USERDB_USER
    $ENSEMBL_USERDB_PASS
    $ENSEMBL_COOKIEHOST
    $ENSEMBL_USER_COOKIE
    $ENSEMBL_USER_ID
    $ENSEMBL_USERADMIN_ID
    $ENSEMBL_WEBADMIN_ID
    $ENSEMBL_LOGINS
    $ENSEMBL_USER_DATA_TABLE
    $ENSEMBL_GROUP_DATA_TABLE
    $ENSEMBL_SESSION_COOKIE
    $ENSEMBL_CONFIG_FILENAME
    $ENSEMBL_CONFIG_BUILD
    $ENSEMBL_LONGPROCESS_MINTIME
    $ENSEMBL_HAS_C_EXTENSIONS
    $ENSEMBL_APACHE_RELOAD
    $ENSEMBL_SITETYPE
    $ARCHIVE_VERSION
    $EARLIEST_ARCHIVE
    $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
    $ENSEMBL_VERSION
    $ENSEMBL_RELEASE_DATE $ENSEMBL_MIN_SPARE_SERVERS $ENSEMBL_MAX_SPARE_SERVERS $ENSEMBL_START_SERVERS
    $ENSEMBL_HELPDESK_EMAIL
    $ENSEMBL_MAIL_SERVER
    %ENSEMBL_SETENV
    @ENSEMBL_CONF_DIRS
    @ENSEMBL_PERL_DIRS
    @ENSEMBL_HTDOCS_DIRS
    @ENSEMBL_LIB_DIRS
    $MART_ENSEMBL_LINKS
    $ENSEMBL_MART_ENABLED
    $ENSEMBL_BLAST_ENABLED
  )],
  
  WEB => [qw(
    $ENSEMBL_FLAG_NAMES
    $APACHE_DIR
    $BIOPERL_DIR
    $ENSEMBL_PLUGIN_ROOTS
    $ENSEMBL_HELPDESK_EMAIL
    $ENSEMBL_MAIL_SERVER
    $ENSEMBL_VERSION
    $ENSEMBL_RELEASE_DATE $ENSEMBL_MIN_SPARE_SERVERS $ENSEMBL_MAX_SPARE_SERVERS $ENSEMBL_START_SERVERS
    $ENSEMBL_TMPL_CSS 
    $ENSEMBL_PAGE_CSS 
    $ENSEMBL_IMAGE_WIDTH
    $ENSEMBL_PLUGINS
    $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
    $ENSEMBL_API_VERBOSITY $ENSEMBL_DEBUG_FLAGS
    $ENSEMBL_SERVERROOT
    $ENSEMBL_TMP_DIR_BLAST
    $ENSEMBL_TMP_DIR_BLAST_OLD
    $ENSEMBL_BLASTSCRIPT
    $ENSEMBL_TMP_DIR_DOTTER
    $ENSEMBL_TMP_CREATE
    $ENSEMBL_TMP_DELETE
    $ENSEMBL_TMP_TMP
    $ENSEMBL_TMP_DIR
    $ENSEMBL_TMP_URL
    $ENSEMBL_TMP_DIR_IMG
    $ENSEMBL_TMP_URL_IMG
    $ENSEMBL_TMP_DIR_CACHE
    $ENSEMBL_TMP_URL_CACHE
    $ENSEMBL_MINIAD_DIR
    $ENSEMBL_SERVER
    $ENSEMBL_PORT
    $ENSEMBL_PROXY_PORT
    $ENSEMBL_USER
    $ENSEMBL_GROUP
    $ENSEMBL_SERVERADMIN
    $ENSEMBL_SERVERNAME $ENSEMBL_PROTOCOL
    $ENSEMBL_MAIL_COMMAND
    $ENSEMBL_MAIL_ERRORS
    $ENSEMBL_ERRORS_TO
    $ENSEMBL_LOGDIR
    $ENSEMBL_PIDFILE
    $ENSEMBL_ERRORLOG
    $ENSEMBL_CUSTOMLOG
    $ENSEMBL_NGINX_PIDFILE
    $ENSEMBL_NGINX_ERRORLOG
    $ENSEMBL_HAS_C_EXTENSIONS
    $ENSEMBL_APACHE_RELOAD
    %ENSEMBL_SETENV
    @ENSEMBL_HTDOCS_DIRS
    $ENSEMBL_SHORTEST_ALIAS
    @ENSEMBL_LIB_DIRS
    @ENSEMBL_PERL_DIRS
    $MART_ENSEMBL_LINKS
    $ENSEMBL_MART_ENABLED
    $ENSEMBL_BLAST_ENABLED
  )],

  APACHE => [qw(
    $ENSEMBL_FLAG_NAMES
    $APACHE_DIR
    $BIOPERL_DIR
    $ENSEMBL_PLUGIN_ROOTS
    $ENSEMBL_HELPDESK_EMAIL
    $ENSEMBL_MAIL_SERVER
    $ENSEMBL_VERSION
    $ENSEMBL_RELEASE_DATE $ENSEMBL_MIN_SPARE_SERVERS $ENSEMBL_MAX_SPARE_SERVERS $ENSEMBL_START_SERVERS
    $ENSEMBL_TMPL_CSS 
    $ENSEMBL_PAGE_CSS 
    $ENSEMBL_IMAGE_WIDTH
    $ENSEMBL_PLUGINS
    $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
    $ENSEMBL_API_VERBOSITY $ENSEMBL_DEBUG_FLAGS
    $ENSEMBL_SERVERROOT 
    $ENSEMBL_BLASTSCRIPT
    $ENSEMBL_TMP_DIR_BLAST
    $ENSEMBL_TMP_DIR_BLAST_OLD
    $ENSEMBL_DATASETS
    $ENSEMBL_SPECIES
    $ENSEMBL_PRIMARY_SPECIES
    $ENSEMBL_SECONDARY_SPECIES
    $ENSEMBL_BASE_URL $ENSEMBL_SITE_DIR $ENSEMBL_SITE_URL
    $ENSEMBL_SPECIES_ALIASES
    $ENSEMBL_ENCRYPT_0
    $ENSEMBL_ENCRYPT_1 $ENSEMBL_ENCRYPT_EXPIRY $ENSEMBL_ENCRYPT_REFRESH
    $ENSEMBL_ENCRYPT_2
    $ENSEMBL_ENCRYPT_3
    $ENSEMBL_USERDB_TYPE
    $ENSEMBL_USERDB_PORT
    $ENSEMBL_USERDB_NAME
    $ENSEMBL_USERDB_HOST
    $ENSEMBL_USERDB_USER
    $ENSEMBL_USERDB_PASS
    $ENSEMBL_COOKIEHOST
    $ENSEMBL_USER_COOKIE
    $ENSEMBL_USER_ID
    $ENSEMBL_USERADMIN_ID
    $ENSEMBL_WEBADMIN_ID
    $ENSEMBL_LOGINS
    $ENSEMBL_USER_DATA_TABLE
    $ENSEMBL_GROUP_DATA_TABLE
    $ENSEMBL_SESSION_COOKIE
    $ENSEMBL_MINIAD_DIR
    $ENSEMBL_CONFIG_FILENAME
    $ENSEMBL_CONFIG_BUILD
    $ENSEMBL_LONGPROCESS_MINTIME
    $ENSEMBL_SITETYPE
    $ENSEMBL_SHORTEST_ALIAS
    $ARCHIVE_VERSION
    $EARLIEST_ARCHIVE
    $MART_ENSEMBL_LINKS
    $ENSEMBL_MART_ENABLED
    $ENSEMBL_BLAST_ENABLED
  )],
);



__END__
           
=head1 NAME
                                                                                
SiteDefs

=head1 SYNOPSIS

    use <path>::SiteDefs;
    # Brief but working code example(s) here showing the most common usage

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible!

=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e. =head2, =head3, etc).

=head1 METHODS

An object of this class represents...

Below is a list of all public methods:

error

	Description:
	Arguments:
	Returns:
	Example:
	Exceptions:
	Status: [Stable|Medium Risk|At Risk]



=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of 
whether they are likely to be fixed in an upcoming release.

=head1 AUTHOR
                                                                                
[name], Ensembl Web Team
Support enquiries: helpdesk@ensembl.org
                                                                                
=head1 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html


__END__
           
=head1 NAME
                                                                                
SiteDefs

=head1 SYNOPSIS

    use <path>::SiteDefs;
    # Brief but working code example(s) here showing the most common usage

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible!

=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e. =head2, =head3, etc).

=head1 METHODS

An object of this class represents...

Below is a list of all public methods:

error

	Description:
	Arguments:
	Returns:
	Example:
	Exceptions:
	Status: [Stable|Medium Risk|At Risk]



=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of 
whether they are likely to be fixed in an upcoming release.

=head1 AUTHOR
                                                                                
[name], Ensembl Web Team
Support enquiries: helpdesk@ensembl.org
                                                                                
=head1 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
1;
