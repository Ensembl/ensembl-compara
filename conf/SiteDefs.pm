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

use Config;
use ConfigDeferrer qw(:all);
use File::Spec;
use Sys::Hostname::Long;
use Text::Wrap;

$Text::Wrap::columns = 75;

our $ENSEMBL_VERSION           = 84;
our $ARCHIVE_VERSION           = 'Mar2016';    # Change this to the archive site for this version
our $ENSEMBL_RELEASE_DATE      = 'March 2016';

#### START OF VARIABLE DEFINITION #### DO NOT REMOVE OR CHANGE THIS COMMENT ####

###############################################################################
####################### LOCAL CONFIGURATION VARIABLES #########################
###############################################################################

##########################################################################
# You need to change the following server root setting.  It points to the
# directory that contains htdocs, modules, perl, ensembl, etc
# DO NOT LEAVE A TRAILING '/' ON ENSEMBL_SERVERROOT
##########################################################################
my ($volume, $dir) = File::Spec->splitpath(__FILE__);

our $ENSEMBL_SERVERROOT = File::Spec->catpath($volume, [split '/ensembl-webcode', $dir]->[0]) || '.';
our $ENSEMBL_WEBROOT    = "$ENSEMBL_SERVERROOT/ensembl-webcode";
our $ENSEMBL_DOCROOT    = "$ENSEMBL_WEBROOT/htdocs";
our $ENSEMBL_PLUGINS_ROOTS = $ENV{'ENSEMBL_PLUGINS_ROOTS'}||"*-plugins";
our @ENSEMBL_PLUGINS_PATHS = (
  $ENSEMBL_WEBROOT,
  "$ENSEMBL_SERVERROOT/$ENSEMBL_PLUGINS_ROOTS/".getpwuid($>),
);
our $ENSEMBL_PLUGINS;

## Define Plugin directories
if(-e "$ENSEMBL_WEBROOT/conf/Plugins.pm") {
  eval qq(require '$ENSEMBL_WEBROOT/conf/Plugins.pm');
  error("Error requiring plugin file:\n$@") if $@;
}

## Load AutoIdentities files
my @ENSEMBL_IDENTITY;
my $IPATHS = join(" ",map {"$_/conf/AutoIdentities.pm"} @ENSEMBL_PLUGINS_PATHS);
my $APATHS = join(" ",map {"$_/conf/AutoPlugins.pm"} @ENSEMBL_PLUGINS_PATHS);
foreach my $f (glob $IPATHS) {
  our $ENSEMBL_IDENTITIES = [];
  next unless -e $f;
  eval qq(require '$f');
  if($@) {
    warn "Error requiring autoidentities file '$f': $@\n";
    next;
  }
  push @ENSEMBL_IDENTITY,@{$_->()} for @$ENSEMBL_IDENTITIES;
}
warn " Server has identities\n    ".join("\n    ",@ENSEMBL_IDENTITY)."\n";

## Load AutoPlugin files
our $ENSEMBL_PLUGINS_USED = {};
our $ENSEMBL_IDS_USED = {};

sub paired { map {[$_[$_*2],$_[$_*2+1]]} 0..int(@_/2)-1 }
my @PLUGINS_SEEN = map { $_->[0] } paired @$ENSEMBL_PLUGINS;
$ENSEMBL_IDS_USED->{'- direct -'} = 0;
$ENSEMBL_PLUGINS_USED->{$_} = [0] for @PLUGINS_SEEN;
my $code = 1;
my (%ALIST,%APRIO,@AMAPS);
foreach my $f (glob $APATHS) {
  our $ENSEMBL_AUTOPLUGINS = {};
  our $ENSEMBL_IDENTITY_MAP = {};
  next unless -e $f;
  eval qq(require '$f');
  if($@) {
    warn "Error requiring autoplugin file '$f': $@\n";
    next;
  }
  push @AMAPS,$ENSEMBL_IDENTITY_MAP;
  foreach my $k (keys %$ENSEMBL_AUTOPLUGINS) {
    my $prio = 50;
    my $orig_k = $k;
    $prio = $1 if $k =~ s/^(\d+)!//;
    $APRIO{$k} ||= $prio;
    push @{$ALIST{$k}||=[]},@{$ENSEMBL_AUTOPLUGINS->{$orig_k}};
  }
}

## Calculate mapped identities
my $any_maps = 1;
while($any_maps) {
  $any_maps = 0;
  foreach my $map (@AMAPS) {
    foreach my $id (keys %$map) {
      next if grep { $_ eq $id } @ENSEMBL_IDENTITY;
      my $re = $map->{$id};
      next unless grep { /$re/ } @ENSEMBL_IDENTITY;
      warn " Server has mapped identity $id ($re)\n";
      $any_maps = 1;
      push @ENSEMBL_IDENTITY,$id;
    }
  }
}

## Process AutoPlugin files
foreach my $k (sort { $APRIO{$a} <=> $APRIO{$b} } keys %ALIST) {
  if(grep { $_ eq $k } @ENSEMBL_IDENTITY) {
    warn " Loading $k\n";
    my @to_add;
    foreach my $p (paired @{$ALIST{$k}||[]}) {
      unless($ENSEMBL_IDS_USED->{$k}) {
        $ENSEMBL_IDS_USED->{$k} = $code++;
      }
      $ENSEMBL_PLUGINS_USED->{$p->[0]} ||= [];
      push @{$ENSEMBL_PLUGINS_USED->{$p->[0]}},$ENSEMBL_IDS_USED->{$k};
      next if grep { $p->[0] eq $_ } @PLUGINS_SEEN;
      push @to_add,$p->[0],$p->[1];
      push @PLUGINS_SEEN,$p->[0];
    }
    push @$ENSEMBL_PLUGINS,@to_add;
  }
}

# Needed for parsing BAM files
our ($UDC_CACHEDIR, $HTTP_PROXY);

# Server config
our $ENSEMBL_MIN_SPARE_SERVERS =  5;
our $ENSEMBL_MAX_SPARE_SERVERS = 20;
our $ENSEMBL_START_SERVERS     =  7;
our $CGI_POST_MAX              = 20 * 1024 * 1024; # 20MB max upload

our $ENSEMBL_SERVER            = Sys::Hostname::Long::hostname_long;  # Local machine name
our $ENSEMBL_PORT              = 80;
our $ENSEMBL_PROXY_PORT        = undef; # Port used for self-referential URLs. Set to undef if not using proxy-forwarding

our $ENSEMBL_SERVERADMIN       = 'webmaster&#064;mydomain.org';
our $ENSEMBL_HELPDESK_EMAIL    = $ENSEMBL_SERVERADMIN;
our $ENSEMBL_MAIL_SERVER       = 'mail.mydomain.org';
our $ENSEMBL_SERVERNAME        = 'www.mydomain.org';
our $ENSEMBL_PROTOCOL          = 'http';
our $ENSEMBL_MAIL_COMMAND      = '/usr/bin/Mail -s';               # Mail command
our $ENSEMBL_MAIL_ERRORS       = '0';                              # Do we want to email errors?
our $ENSEMBL_ERRORS_TO         = 'webmaster&#064;mydomain.org';    # ...and to whom?

our $ENSEMBL_SITETYPE          = 'Ensembl';
our $ENSEMBL_USER              = getpwuid($>); # Auto-set web serveruser
our $ENSEMBL_GROUP             = getgrgid($)); # Auto-set web server group
our $ENSEMBL_IMAGE_WIDTH       = 800;

our $ENSEMBL_MINIFIED_FILES_PATH = '/minified'; # path for saving the minified files
our $ENSEMBL_DEBUG_JS            = 0; # change these to 1 to prevent js minification
our $ENSEMBL_DEBUG_CSS           = 0; # change these to 1 to prevent css minification
our $ENSEMBL_DEBUG_IMAGES        = 0; # change these to 1 to prevent css minification
our $ENSEMBL_DEBUG_NOCACHE       = 0; # disable even in-run caches
our $ENSEMBL_SKIP_RSS            = 0; # set to 1 in sandboxes to avoid overloading blog

our $ENSEMBL_EXTERNAL_SEARCHABLE = 0; # No external bots allowed by default

our $ENSEMBL_MART_ENABLED      = 0;

our $ENSEMBL_ORM_DATABASES     = {};

# ENSEMBL_API_VERBOSITY: 
#    0 OFF NOTHING NONE
# 1000 EXCEPTION THROW
# 2000 (DEFAULT) WARNING WARN
# 3000 DEPRECATE DEPRECATED
# 4000 INFO
# *1e6 ON ALL
our $ENSEMBL_API_VERBOSITY        = 'WARNING';
our $ENSEMBL_DEBUG_FLAGS          = 1;
our $ENSEMBL_DEBUG_VERBOSE_ERRORS = 0;
our $ENSEMBL_DEBUG_FLAG_NAMES     = [qw(
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

my $i = 0;

foreach (@$ENSEMBL_DEBUG_FLAG_NAMES) {
  no strict 'refs';
  
  my $variable_name = "SiteDefs::ENSEMBL_DEBUG_$_";
    $$variable_name = 1 << ($i++)
    ;
    
  $ENSEMBL_DEBUG_VERBOSE_ERRORS <<= 1
  ;
  $ENSEMBL_DEBUG_VERBOSE_ERRORS  += 1;
}

# Apache files
our ($ENSEMBL_PIDFILE, $ENSEMBL_ERRORLOG, $ENSEMBL_CUSTOMLOG);

# TMP dirs
# ENSEMBL_TMP_DIR points to a filesystem dir
# ENSEMBL_TMP_URL points to a URL location. 
# httpd.conf creates an alias for ENSEMBL_TMP_URL to ENSEMBL_TMP_DIR
# httpd.conf also validates the existence of ENSEMBL_TMP_DIR.

our $ENSEMBL_TMP_CREATE     = 1; # Create tmp dirs on server startup if not found?
our $ENSEMBL_TMP_DELETE     = 0; # Delete files from the tmp dir on server startup? 
our $ENSEMBL_TMP_TMP        = '/tmp';
our $ENSEMBL_TMP_URL        = '/tmp';
our $ENSEMBL_TMP_URL_IMG    = '/img-tmp';
our $ENSEMBL_TMP_URL_CACHE  = '/img-cache';
our $TRACKHUB_TIMEOUT       = 60*60*24;

our ($ENSEMBL_REGISTRY);

# Environment variables to set using the SetEnv directive
our %ENSEMBL_SETENV = (
  LSF_BINDIR      => $ENV{'LSF_BINDIR'}      || '',
  LSF_SERVERDIR   => $ENV{'LSF_SERVERDIR'}   || '',
  LSF_LIBDIR      => $ENV{'LSF_LIBDIR'}      || '',
  XLSF_UIDDIR     => $ENV{'XLSF_UIDDIR'}     || '',
  LD_LIBRARY_PATH => $ENV{'LD_LIBRARY_PATH'} || '',
);

# Content dirs
# @ENSEMBL_LIB_DIRS    locates perl library modules. Array order is maintained in @INC
# @ENSEMBL_CONF_DIRS   locates <species>.ini files
# @ENSEMBL_PERL_DIRS   locates mod-perl scripts
# @ENSEMBL_HTDOCS_DIRS locates static content
our @ENSEMBL_LIB_DIRS;
our @ENSEMBL_CONF_DIRS    = ("$ENSEMBL_WEBROOT/conf");
our @ENSEMBL_PERL_DIRS    = ("$ENSEMBL_WEBROOT/perl");
our @ENSEMBL_HTDOCS_DIRS  = ($ENSEMBL_DOCROOT, "$ENSEMBL_SERVERROOT/biomart-perl/htdocs");

our $APACHE_DIR           = "$ENSEMBL_SERVERROOT/apache2";
our $APACHE_BIN           = "$APACHE_DIR/bin/httpd";
our $SAMTOOLS_DIR         = "$ENSEMBL_SERVERROOT/samtools";
our $HTSLIB_DIR           = "$ENSEMBL_SERVERROOT/htslib";
our $BIOPERL_DIR          = "$ENSEMBL_SERVERROOT/bioperl-live";

# See Memoize.pm for meaning of these
our $MEMOIZE_ENABLED      = 1;
our $MEMOIZE_DEBUG        = 0;
our $MEMOIZE_SIZE         = [14,32,4*1024*1024];

our $PACED_MULTI = 6; # Max simultaneous connections

###############################################################################
######################### END OF LOCAL CONFIGURATION SECTION ##################
###############################################################################

###############################################################################
## Choice of species...
###############################################################################

our $ENSEMBL_DATASETS         = [];
our $ENSEMBL_PRIMARY_SPECIES  = 'Homo_sapiens'; # Default species
our $ENSEMBL_SECONDARY_SPECIES;

## This hash is used to configure the species available in this
## copy of EnsEMBL - comment out any lines which are not relevant
## If you add a new species MAKE sure that one of the values of the
## array is the "SPECIES_CODE" defined in the species.ini file

our %__species_aliases;

###############################################################################
## Cookies and cookie encryption
###############################################################################

our $ENSEMBL_USER_COOKIE        = 'ENSEMBL_WWW_USER';
our $ENSEMBL_USER_COOKIEHOST    = '';
our $ENSEMBL_SESSION_COOKIE     = 'ENSEMBL_WWW_SESSION';
our $ENSEMBL_SESSION_COOKIEHOST = '';
our $ENSEMBL_COOKIEHOST         = '';

our $ENSEMBL_ENCRYPT_0        = 0x16a3b3; # Encryption keys for session
our $ENSEMBL_ENCRYPT_1        = 'a9';     # Encryption keys for session
our $ENSEMBL_ENCRYPT_2        = 'xX';     # Encryption keys for session
our $ENSEMBL_ENCRYPT_3        = '2Q';     # Encryption keys for session
our $ENSEMBL_ENCRYPT_EXPIRY   = 60;       # Cookies last 60 days 
our $ENSEMBL_ENCRYPT_REFRESH  = 30;       # Refresh cookies with less than 30 days to go

###############################################################################
## General systems bumf
###############################################################################

our $ENSEMBL_CONFIG_FILENAME     = 'config.packed';
our $ENSEMBL_HTTPD_CONFIG_FILE   = "$ENSEMBL_WEBROOT/conf/httpd.conf";
our $ENSEMBL_CONFIG_BUILD        = 0; # Build config on server startup? Setting to 0 will try to recover from $ENSEMBL_CONFIG_FILENAME on startup
our $ENSEMBL_LONGPROCESS_MINTIME = 10;
our $APACHE_DEFINE               = undef; # command line arguments for httpd command

## ALLOWABLE DATA OBJECTS
our $OBJECT_TO_SCRIPT = {
  Config              => 'Config',
  Component           => 'Component',
  ZMenu               => 'ZMenu',
  psychic             => 'Psychic',
  Ajax                => 'Ajax',
  Share               => 'Share',
  Export              => 'Export',
  DataExport          => 'DataExport',
  ImageExport         => 'ImageExport',

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

  CSS                 => 'CSS',
};

## Set log directory and files
our $ENSEMBL_LOGDIR    = defer { "$ENSEMBL_SERVERROOT/logs" };
our $ENSEMBL_PIDFILE   = defer { "$ENSEMBL_LOGDIR/$ENSEMBL_SERVER.httpd.pid" };
our $ENSEMBL_ERRORLOG  = defer { "$ENSEMBL_LOGDIR/$ENSEMBL_SERVER.error_log" };
our $ENSEMBL_CUSTOMLOG = defer { "$ENSEMBL_LOGDIR/$ENSEMBL_SERVER.access_log ensembl_extended" };

## Set tmp dirs
our $ENSEMBL_TMP_DIR       = defer { "$ENSEMBL_SERVERROOT/tmp" };
our $ENSEMBL_TMP_DIR_IMG   = defer { "$ENSEMBL_TMP_DIR/img/tmp" };
our $ENSEMBL_TMP_DIR_CACHE = defer { "$ENSEMBL_TMP_DIR/img/cache" };

our $ENSEMBL_BOOK_DIR      = defer { "$ENSEMBL_WEBROOT/conf/book" };
our $ENSEMBL_BOOK_DISABLE  = 0;

#### END OF VARIABLE DEFINITION #### DO NOT REMOVE OR CHANGE THIS COMMENT ####
###############################################################################
# You should not change anything below here
###############################################################################

our ($ENSEMBL_SITE_DIR, $ENSEMBL_STATIC_SERVER);
our $BIOMART_URL = 'Multi';

update_conf();

$ENSEMBL_PROXY_PORT   = $ENSEMBL_PORT unless $ENSEMBL_PROXY_PORT && $ENSEMBL_PROXY_PORT ne '';
$ENSEMBL_SERVERNAME ||= $ENSEMBL_SERVER;

our $ENSEMBL_BASE_URL = "$ENSEMBL_PROTOCOL://$ENSEMBL_SERVERNAME" . (
  $ENSEMBL_PROXY_PORT == 80  && $ENSEMBL_PROTOCOL eq 'http' ||
  $ENSEMBL_PROXY_PORT == 443 && $ENSEMBL_PROTOCOL eq 'https' ? '' : ":$ENSEMBL_PROXY_PORT"
);

our $ENSEMBL_SITE_URL          = join '/', $ENSEMBL_BASE_URL, $ENSEMBL_SITE_DIR || (), '';
our $ENSEMBL_STATIC_SERVERNAME = $ENSEMBL_STATIC_SERVER || $ENSEMBL_SERVERNAME;
    $ENSEMBL_STATIC_SERVER     = "$ENSEMBL_PROTOCOL://$ENSEMBL_STATIC_SERVER" if $ENSEMBL_STATIC_SERVER;
our $ENSEMBL_STATIC_BASE_URL   = $ENSEMBL_STATIC_SERVER || $ENSEMBL_BASE_URL;

our $MART_HELP_DESK            = "${ENSEMBL_SITE_URL}default/helpview";
our $ENSEMBL_TEMPLATE_ROOT     = "$ENSEMBL_SERVERROOT/biomart-perl/conf";

set_species_aliases();

sub update_conf {
  our $ENSEMBL_PLUGIN_ROOTS = [];
  
  my @plugins = reverse @{$ENSEMBL_PLUGINS || []}; # Go on in reverse order so that the first plugin is the most important
  
  while (my ($dir, $name) = splice @plugins, 0, 2) {
    my $plugin_conf = "${name}::SiteDefs";

    if (!-d $dir) {
      die "[ERROR] Plugin $name could not be loaded: $dir not found.\n";
    }
    
    eval qq{ package $plugin_conf; use ConfigDeferrer qw(defer); }; # export 'defer' to the plugin SiteDefs
    eval qq{ require '$dir/conf/SiteDefs.pm' };                     # load the actual plugin SiteDefs
    
    if ($@) {
      my $message = "Can't locate $dir/conf/SiteDefs.pm in";
      error("Error requiring $plugin_conf:\n$@") unless $@ =~ m:$message:;
    } else {
      my $func = "${plugin_conf}::update_conf";
      
      eval "$func()";
      
      if ($@) {
        my $message = "Undefined subroutine &$func called at ";
        
        if ($@ =~ /$message/) {
          error("Function $func not defined in $dir/conf/SiteDefs.pm");
        } else {       
          error("Error calling $func in $dir/conf/SiteDefs.pm\n$@");
        }
      }
      register_deferred_configs();
    }
    
    unshift @ENSEMBL_PERL_DIRS,     "$dir/perl"; 
    unshift @ENSEMBL_HTDOCS_DIRS,   "$dir/htdocs"; 
    unshift @$ENSEMBL_PLUGIN_ROOTS, $name;
    push    @ENSEMBL_CONF_DIRS,     "$dir/conf"; 
  }
  build_deferred_configs();
  
  push @ENSEMBL_LIB_DIRS, (
    "$ENSEMBL_WEBROOT/modules",
    $BIOPERL_DIR,
    "$ENSEMBL_SERVERROOT/biomart-perl/lib",
    "$ENSEMBL_SERVERROOT/ensembl-orm/modules",
    "$ENSEMBL_SERVERROOT/ensembl-io/modules",
    "$ENSEMBL_SERVERROOT/ensembl-funcgen/modules",
    "$ENSEMBL_SERVERROOT/ensembl-variation/modules",
    "$ENSEMBL_SERVERROOT/ensembl-compara/modules",
    "$ENSEMBL_SERVERROOT/ensembl/modules",
    "${APACHE_DIR}lib/perl5/site_perl/$Config{'version'}/$Config{'archname'}/",
  );
}

sub set_species_aliases {
  #-# Autogeneration stuff.... DO NOT TOUCH THIS - it does nasty stuff....

  ## Add self refernetial elements to ENSEMBL_SPECIES_ALIASES
  ## And one without the _ in...
  
  our $ENSEMBL_SPECIES_ALIASES = {};
  
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
    error(qq{Species "$ENSEMBL_PRIMARY_SPECIES" not defined in ENSEMBL_SPECIES_ALIASES});
    $ENSEMBL_PRIMARY_SPECIES = shift @temp_species;
  }

  unless ($__species_aliases{$ENSEMBL_SECONDARY_SPECIES}) {
    error(qq{Species "$ENSEMBL_SECONDARY_SPECIES" not defined in ENSEMBL_SPECIES_ALIASES});
    $ENSEMBL_SECONDARY_SPECIES = shift @temp_species;
  }

  $ENSEMBL_SECONDARY_SPECIES = shift @temp_species if $ENSEMBL_SECONDARY_SPECIES eq $ENSEMBL_PRIMARY_SPECIES;
}

sub verbose_params {

  my $params = {};

  no strict qw(refs);

  for (sort keys %{'SiteDefs::'}) {

    my $sym_name  = "SiteDefs::$_";
    my $sym       = *$sym_name;

    next unless ref(\$sym) eq 'GLOB';

    warn sprintf "%50s: %s\n", $_, ref *{$sym}{'CODE'} ? 'SUBROUTINE' : ref $$sym || $$sym // 'undef';
  }
}

sub error {
  my $message = join "\n", @_;
     $message =~ s/\s+$//sm;
  
  warn '#' x 78, "\n",
       wrap('# ', '# ', $message),
       "\n", '#' x 78, "\n";
}

sub logs { warn sprintf q(SiteDefs::logs is deprecated. Just define $SiteDefs::ENSEMBL_LOGDIR = '%s' instead in %s if needed.%s), $_[0] =~ s/\/$//r, [ caller ]->[0],  "\n"; }
sub tmp { warn sprintf q(SiteDefs::tmp is deprecated. Just define $SiteDefs::ENSEMBL_TMP_DIR = '%s' instead in %s if needed.%s), $_[0] =~ s/\/$//r, [ caller ]->[0], "\n"; }

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
sub memcached {
  my $pars = shift;
  
  unless (scalar @{$pars->{'servers'} || []}) {
    $SiteDefs::ENSEMBL_MEMCACHED = undef;
    return;
  }
  
  $pars->{'debug'}    = 0  unless exists $pars->{'debug'};
  $pars->{'hm_stats'} = 0  unless exists $pars->{'hm_stats'};
  
  my %flags = map { $_ => 1 } qw( 
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
  
  foreach my $k (keys %{$pars->{'flags'}}) {
    if ($pars->{'flags'}{$k}) {
      $flags{$k} = 1;
    } else {
      delete $flags{$k};
    }
  }
  
  $pars->{'flags'} = [ keys %flags ];
  
  $SiteDefs::ENSEMBL_MEMCACHED = $pars;

  $SiteDefs::ENSEMBL_COHORT =
    Sys::Hostname::Long::hostname_long().":".$ENSEMBL_SERVERROOT;
}


1;

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
                                                                                
=head1 LICENSE
                                                                                
Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

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

