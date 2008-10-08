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
$Text::Wrap::columns = 75;

use vars qw ( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION
  $ENSEMBL_RELEASE_DATE $ENSEMBL_MIN_SPARE_SERVERS $ENSEMBL_MAX_SPARE_SERVERS $ENSEMBL_START_SERVERS
  $ENSEMBL_HELPDESK_EMAIL
  $ENSEMBL_MAIL_SERVER
  $ENSEMBL_VERSION
  $ENSEMBL_PLUGINS $ENSEMBL_PLUGIN_ROOTS
  $ENSEMBL_TMPL_CSS
  $ENSEMBL_PAGE_CSS
  $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
  $ENSEMBL_DEBUG_FLAGS
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
  $ENSEMBL_PIDFILE
  $ENSEMBL_ERRORLOG
  $ENSEMBL_CUSTOMLOG
  $ENSEMBL_TEMPLATE_ROOT
  $ENSEMBL_TMP_CREATE
  $ENSEMBL_TMP_DELETE
  $ENSEMBL_TMP_DIR_BLAST
  $ENSEMBL_TMP_DIR_BLAST_OLD
  $ENSEMBL_BLASTSCRIPT
  $ENSEMBL_TMP_DIR
  $ENSEMBL_TMP_URL
  $ENSEMBL_TMP_DIR_IMG
  $ENSEMBL_TMP_DIR_DOTTER
  $ENSEMBL_TMP_URL_IMG
  $ENSEMBL_TMP_DIR_CACHE
  $ENSEMBL_TMP_URL_CACHE
  $ENSEMBL_MINIAD_DIR
  $ENSEMBL_SPECIES
  $ENSEMBL_PRIMARY_SPECIES
  $ENSEMBL_SECONDARY_SPECIES
  $ENSEMBL_BASE_URL
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
  $ENSEMBL_FIRSTSESSION_COOKIE
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
);
use Sys::Hostname::Long;
use Exporter();
@ISA=qw(Exporter);

$VERSION                   = 51;
$ARCHIVE_VERSION           = "Sep2008";    # Change this to the archive site for this version
$ENSEMBL_RELEASE_DATE      = 'Sept 2008';

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

## 1024 <- Debug/timing div - at top left of webpages...
##   64 <- Time stamped logs...
##   32 <- Enable eprof error diagnostics in web scripts
##   16 <- Apache handler long process errors
##    8 <- Apache handler error messages... 
##    4 <- SpeciesDef autohandler errors...
##    2 <- Drawing code errors...
##    1 <- General error messages

$ENSEMBL_DEBUG_FLAGS = 1;

our $ENSEMBL_DEBUG_JAVASCRIPT_DEBUG = 1024;
our $ENSEMBL_DEBUG_TIMESTAMPED_LOGS =   64;
our $ENSEMBL_DEBUG_PERL_PROFILER    =   32;
our $ENSEMBL_DEBUG_LONG_PROCESS     =   16;
our $ENSEMBL_DEBUG_HANDLER_ERRORS   =    8;
our $ENSEMBL_DEBUG_SD_AUTOLOADER    =    4;
our $ENSEMBL_DEBUG_DRAWING_CODE     =    2;
our $ENSEMBL_DEBUG_GENRAL_ERRORS    =    1;
#####################
# Apache files
$ENSEMBL_PIDFILE = undef;
$ENSEMBL_ERRORLOG = undef;
$ENSEMBL_CUSTOMLOG = undef;

$ENSEMBL_TMPL_CSS = '/css/ensembl.css';
$ENSEMBL_PAGE_CSS = '/css/content.css';
#####################
# TMP dirs
# ENSEMBL_TMP_DIR points to a filesystem dir
# ENSEMBL_TMP_URL points to a URL location. 
# httpd.conf creates an alias for ENSEMBL_TMP_URL to ENSEMBL_TMP_DIR
# httpd.conf also validates the existence of ENSEMBL_TMP_DIR.

$ENSEMBL_TMP_CREATE     = 1; # Create tmp dirs on server startup if not found?
$ENSEMBL_TMP_DELETE     = 0; # Delete files from the tmp dir on server startup? 
$ENSEMBL_TMP_DIR        = $ENSEMBL_SERVERROOT.'/tmp';
$ENSEMBL_TMP_URL        = '/tmp';
$ENSEMBL_TMP_DIR_IMG    = $ENSEMBL_SERVERROOT.'/img-tmp';
$ENSEMBL_TMP_URL_IMG    = '/img-tmp';
$ENSEMBL_TMP_DIR_CACHE = $ENSEMBL_SERVERROOT.'/img-cache';
$ENSEMBL_TMP_URL_CACHE = '/img-cache';
$ENSEMBL_TMP_DIR_DOTTER = $ENSEMBL_SERVERROOT.'/shared/data/dotter';

#$ENSEMBL_TMP_DIR_BLAST  = '/ensemblweb/shared/data/blastqueue';
#$ENSEMBL_TMP_DIR_BLAST_OLD  = '/ensweb/shared/data/blastqueue';
$ENSEMBL_TMP_DIR_BLAST  = $ENSEMBL_TMP_DIR;
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

my $perl_version = sprintf( '%d.%d.%d', $] =~ /(\d)\.(\d{3})(\d{3})/ ) || "5.8.0";
@ENSEMBL_LIB_DIRS     = (
  $ENSEMBL_SERVERROOT."/apache2/lib/site_perl/5.8.8/x86_64-linux-thread-multi/",
  $ENSEMBL_SERVERROOT.'/ensembl/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-compara/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-draw/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-variation/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-functgenomics/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-external/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-mart/modules',
  $ENSEMBL_SERVERROOT.'/ensembl-genename/modules',
  $ENSEMBL_SERVERROOT.'/biomart-perl/lib',
  $ENSEMBL_SERVERROOT.'/bioperl-live',
  $ENSEMBL_SERVERROOT.'/modules',
);

# Add perl-version specific lib from /ensemblweb/shared/lib for e.g. Storable.pm
my @vers = split( /[\.0]+/, $] );
my $ver  = join(".",$vers[0], $vers[1]||0, $vers[2]||0 ); # e.g. 5.8.0
# push @ENSEMBL_LIB_DIRS, "/ensemblweb/shared/lib/perl5/$ver/alpha-dec_osf";


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
$ENSEMBL_FIRSTSESSION_COOKIE    = 'ENSEMBL_WWW_FIRSTSESSION';
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

sub error {
  my $message = join "\n", @_;
  $message =~ s/\s+$//sm;
  warn "=" x 78, "\n",
       wrap("= ","= ", $message ),
       "\n", "=" x 78, "\n";
}

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

@T = reverse @{$ENSEMBL_PLUGINS||[]}; ## These have to go on in reverse order...
$ENSEMBL_PLUGIN_ROOTS = ();
while( my( $dir, $name ) = splice(@T,0,2)  ) {
  unshift @ENSEMBL_PERL_DIRS,   $dir.'/perl'; 
  unshift @ENSEMBL_HTDOCS_DIRS, $dir.'/htdocs'; 
  unshift @$ENSEMBL_PLUGIN_ROOTS,   $name;
  push    @ENSEMBL_CONF_DIRS,   $dir.'/conf'; 
  unshift    @ENSEMBL_LIB_DIRS,    $dir.'/modules';
}

@T = @{$ENSEMBL_PLUGINS||[]};         ## But these have to go on in normal order...
while( my( $name, $dir ) = splice(@T,0,2)  ) {
}

@ENSEMBL_LIB_DIRS = reverse @ENSEMBL_LIB_DIRS; # Helps getting @inc into 
                                              # right order

my $DATESTAMP = '';
if( $ENSEMBL_DEBUG_FLAGS & 64 ) { ##  Set to 0 - disables time stamped logs
        ##  Set to 1 -  enables time stamped logs
  my @TIME = gmtime();
  $DATESTAMP = sprintf( ".%04d-%02d-%02d-%02d-%02d-%02d", $TIME[5]+1900, $TIME[4]+1, @TIME[3,2,1,0] );
}
$ENSEMBL_PIDFILE   = "$ENSEMBL_SERVERROOT/logs/$ENSEMBL_SERVER.httpd.pid"                             unless defined $ENSEMBL_PIDFILE;
$ENSEMBL_ERRORLOG  = "$ENSEMBL_SERVERROOT/logs/$ENSEMBL_SERVER$DATESTAMP.error_log"                   unless defined $ENSEMBL_ERRORLOG;
$ENSEMBL_CUSTOMLOG = "$ENSEMBL_SERVERROOT/logs/$ENSEMBL_SERVER$DATESTAMP.access_log ensembl_extended" unless defined $ENSEMBL_CUSTOMLOG;

$ENSEMBL_PROXY_PORT = $ENSEMBL_PORT unless ( $ENSEMBL_PROXY_PORT && $ENSEMBL_PROXY_PORT ne "" );

#-# Autogeneration stuff.... DO NOT TOUCH THIS - it does nasty stuff....

## Add self refernetial elements to ENSEMBL_SPECIES_ALIASES
## And one without the _ in...

$ENSEMBL_SPECIES_ALIASES = {};
$ENSEMBL_SPECIES = [ sort keys %__species_aliases ];

foreach my $binomial ( @$ENSEMBL_SPECIES ) {
  foreach my $alias ( @{$__species_aliases{$binomial}} ) {
    $ENSEMBL_SPECIES_ALIASES->{lc($alias)} = $binomial;
  }
  my $key = lc($binomial);
  $ENSEMBL_SPECIES_ALIASES->{$key} = $binomial;   # homo_sapiens
  $key =~s/\.//g;
  $ENSEMBL_SPECIES_ALIASES->{$key} = $binomial;   # homosapiens
  $key = lc($binomial);
  $key =~s/^([a-z])[a-z]*_/$1_/g;
  $ENSEMBL_SPECIES_ALIASES->{$key} = $binomial;   # h_sapiens
  $key =~s/_/\./g;
  $ENSEMBL_SPECIES_ALIASES->{$key} = $binomial;   # h.sapiens
  $key =~s/_//g;
  $ENSEMBL_SPECIES_ALIASES->{$key} = $binomial;   # hsapiens
}
$ENSEMBL_SHORTEST_ALIAS = {};
foreach my $key (keys %$ENSEMBL_SPECIES_ALIASES) {
  my $bin = $ENSEMBL_SPECIES_ALIASES->{$key};
  $ENSEMBL_SHORTEST_ALIAS->{$bin} = $key if !exists($ENSEMBL_SHORTEST_ALIAS->{$bin}) ||
    length($key) < length($ENSEMBL_SHORTEST_ALIAS->{$bin});
  
}
my @temp_species = @{$ENSEMBL_SPECIES};
unless( $__species_aliases{$ENSEMBL_PRIMARY_SPECIES} ) {
  error( qq(Species "$ENSEMBL_PRIMARY_SPECIES" not defined in ENSEMBL_SPECIES_ALIASES) );
  $ENSEMBL_PRIMARY_SPECIES = shift @temp_species;
}
unless( $__species_aliases{$ENSEMBL_SECONDARY_SPECIES} ) {
  error( qq(Species "$ENSEMBL_SECONDARY_SPECIES" not defined in ENSEMBL_SPECIES_ALIASES) );
  $ENSEMBL_SECONDARY_SPECIES = shift @temp_species;
}
$ENSEMBL_SECONDARY_SPECIES = shift @temp_species if $ENSEMBL_SECONDARY_SPECIES eq $ENSEMBL_PRIMARY_SPECIES;

## here we try and do the dynamic use stuff;
$BIOMART_URL = 'Multi';
$ENSEMBL_BASE_URL      = "$ENSEMBL_PROTOCOL://$ENSEMBL_SERVERNAME".
  ( $ENSEMBL_PROXY_PORT==80  && $ENSEMBL_PROTOCOL eq 'http' ||
    $ENSEMBL_PROXY_PORT==443 && $ENSEMBL_PROTOCOL eq 'https' ?'' : ":$ENSEMBL_PROXY_PORT" );

$MART_ENSEMBL_LINKS    = $ENSEMBL_BASE_URL;
$MART_HELP_DESK        = "$ENSEMBL_BASE_URL/default/helpview";
$ENSEMBL_TEMPLATE_ROOT = $ENSEMBL_SERVERROOT.'/biomart-web/conf';

####################
# Export by default
####################
@EXPORT = qw(
  $ENSEMBL_PLUGIN_ROOTS
  $ENSEMBL_TMPL_CSS 
  $ENSEMBL_PAGE_CSS 
  $ENSEMBL_PLUGINS
  $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
  $ENSEMBL_DEBUG_FLAGS
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
  $ENSEMBL_TMP_DIR
  $ENSEMBL_TMP_URL
  $ENSEMBL_TMP_DIR_IMG
  $ENSEMBL_TMP_URL_IMG
   $ENSEMBL_TMP_DIR_CACHE
   $ENSEMBL_TMP_URL_CACHE
  $ENSEMBL_MINIAD_DIR
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
  $ENSEMBL_PLUGINS
  $ENSEMBL_DEBUG_FLAGS
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
  $ENSEMBL_PIDFILE
  $ENSEMBL_ERRORLOG
  $ENSEMBL_CUSTOMLOG
  $ENSEMBL_TMP_CREATE
  $ENSEMBL_TMP_DELETE
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
  $ENSEMBL_SPECIES
  $ENSEMBL_PRIMARY_SPECIES
  $ENSEMBL_SECONDARY_SPECIES
  $ENSEMBL_BASE_URL
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
  $ENSEMBL_FIRSTSESSION_COOKIE
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
  $ENSEMBL_SHORTEST_ALIAS
    $ENSEMBL_PLUGINS $ENSEMBL_PLUGIN_ROOTS
    $ENSEMBL_TMPL_CSS 
    $ENSEMBL_PAGE_CSS 
    $ENSEMBL_DEBUG_FLAGS
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
    $ENSEMBL_PIDFILE
    $ENSEMBL_ERRORLOG
    $ENSEMBL_CUSTOMLOG
    $ENSEMBL_TMP_CREATE
    $ENSEMBL_TMP_DELETE
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
    $ENSEMBL_SPECIES
  $ENSEMBL_PRIMARY_SPECIES
  $ENSEMBL_SECONDARY_SPECIES
  $ENSEMBL_BASE_URL
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
    $ENSEMBL_FIRSTSESSION_COOKIE
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
  $ENSEMBL_PLUGIN_ROOTS
  $ENSEMBL_HELPDESK_EMAIL
    $ENSEMBL_MAIL_SERVER
    $ENSEMBL_VERSION
  $ENSEMBL_RELEASE_DATE $ENSEMBL_MIN_SPARE_SERVERS $ENSEMBL_MAX_SPARE_SERVERS $ENSEMBL_START_SERVERS
    $ENSEMBL_TMPL_CSS 
    $ENSEMBL_PAGE_CSS 
    $ENSEMBL_PLUGINS
    $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
    $ENSEMBL_DEBUG_FLAGS
    $ENSEMBL_SERVERROOT
    $ENSEMBL_TMP_DIR_BLAST
    $ENSEMBL_TMP_DIR_BLAST_OLD
    $ENSEMBL_BLASTSCRIPT
    $ENSEMBL_TMP_DIR_DOTTER
    $ENSEMBL_TMP_CREATE
    $ENSEMBL_TMP_DELETE
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
    $ENSEMBL_PIDFILE
    $ENSEMBL_ERRORLOG
    $ENSEMBL_CUSTOMLOG
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
    $ENSEMBL_PLUGIN_ROOTS
  $ENSEMBL_HELPDESK_EMAIL
  $ENSEMBL_MAIL_SERVER
    $ENSEMBL_VERSION
  $ENSEMBL_RELEASE_DATE $ENSEMBL_MIN_SPARE_SERVERS $ENSEMBL_MAX_SPARE_SERVERS $ENSEMBL_START_SERVERS
    $ENSEMBL_TMPL_CSS 
    $ENSEMBL_PAGE_CSS 
    $ENSEMBL_PLUGINS
    $ENSEMBL_PRIVATE_AUTH $ENSEMBL_REGISTRY
    $ENSEMBL_DEBUG_FLAGS
    $ENSEMBL_SERVERROOT 
    $ENSEMBL_BLASTSCRIPT
    $ENSEMBL_TMP_DIR_BLAST
    $ENSEMBL_TMP_DIR_BLAST_OLD
    $ENSEMBL_SPECIES
  $ENSEMBL_PRIMARY_SPECIES
  $ENSEMBL_SECONDARY_SPECIES
  $ENSEMBL_BASE_URL
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
    $ENSEMBL_FIRSTSESSION_COOKIE
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
