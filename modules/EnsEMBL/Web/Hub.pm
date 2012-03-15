# $Id$

package EnsEMBL::Web::Hub;

### NAME: EnsEMBL::Web::Hub 
### A centralised object giving access to data connections and the web environment 

### DESCRIPTION:
### Hub uses the Flyweight design pattern to create a single object that is 
### passed around between all other objects that require data connectivity.
### The Hub stores information about the current web page and its environment, 
### including cgi parameters, settings parsed from the URL, browser session, 
### database connections, and so on.

use strict;

use Carp;
use CGI;
use CGI::Cookie;
use URI::Escape qw(uri_escape uri_unescape);

use Bio::EnsEMBL::ColourMap;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::DBSQL::ConfigAdaptor;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Session;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::ViewConfig;
use EnsEMBL::Web::Tools::Misc qw(get_url_content);

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $args) = @_;

  my $type         = $args->{'type'}         || $ENV{'ENSEMBL_TYPE'}; # Parsed from URL: Gene, UserData, etc
  my $species      = $args->{'species'}      || $ENV{'ENSEMBL_SPECIES'};
  my $input        = $args->{'input'}        || new CGI;
  my $species_defs = $args->{'species_defs'} || new EnsEMBL::Web::SpeciesDefs;
  my $factorytype  = $ENV{'ENSEMBL_FACTORY'} || ($input && $input->param('factorytype') ? $input->param('factorytype') : $type);
  my $cookies      = $args->{'apache_handle'} ? CGI::Cookie->parse($args->{'apache_handle'}->headers_in->{'Cookie'}) : {};
  
  $species_defs->{'timer'} = $args->{'timer'};
  
  my $self = {
    _input         => $input,
    _species       => $species,    
    _species_defs  => $species_defs, 
    _factorytype   => $factorytype,
    _type          => $type,
    _action        => $args->{'action'}        || $ENV{'ENSEMBL_ACTION'},   # View, Summary etc
    _function      => $args->{'function'}      || $ENV{'ENSEMBL_FUNCTION'}, # Extra path info
    _script        => $args->{'script'}        || $ENV{'ENSEMBL_SCRIPT'},   # Page, Component, Config etc
    _cache         => $args->{'cache'}         || new EnsEMBL::Web::Cache(enable_compress => 1, compress_threshold => 10000),
    _ext_url       => $args->{'ext_url'}       || new EnsEMBL::Web::ExtURL($species, $species_defs),
    _problem       => $args->{'problem'}       || {},
    _user_details  => $args->{'user_details'}  || 1,
    _object_types  => $args->{'object_types'}  || {},
    _apache_handle => $args->{'apache_handle'} || undef,
    _user          => $args->{'user'}          || undef,
    _timer         => $args->{'timer'}         || undef,
    _databases     => new EnsEMBL::Web::DBSQL::DBConnection($species, $species_defs),
    _cookies       => $cookies,
    _core_objects  => {},
    _core_params   => {},
    _components    => [],
  };

  bless $self, $class;
  
  $self->initialize_user($args->{'user_cookie'}) if $args->{'user_cookie'};
  $self->session = new EnsEMBL::Web::Session($self, $args->{'session_cookie'});
  $self->timer ||= $ENSEMBL_WEB_REGISTRY->timer if $ENSEMBL_WEB_REGISTRY;
  
  $self->set_core_params;
  
  $self->{'_config_adaptor'} = new EnsEMBL::Web::DBSQL::ConfigAdaptor($self);
  
  return $self;
}

# Accessor functionality
sub species     :lvalue { $_[0]{'_species'};     }
sub script      :lvalue { $_[0]{'_script'};      }
sub type        :lvalue { $_[0]{'_type'};        }
sub action      :lvalue { $_[0]{'_action'};      }
sub function    :lvalue { $_[0]{'_function'};    }
sub factorytype :lvalue { $_[0]{'_factorytype'}; }
sub session     :lvalue { $_[0]{'_session'};     }
sub cache       :lvalue { $_[0]{'_cache'};       }
sub user        :lvalue { $_[0]{'_user'};        }
sub timer       :lvalue { $_[0]{'_timer'};       }
sub components  :lvalue { $_[0]{'_components'};  }
sub viewconfig  :lvalue { $_[0]{'_viewconfig'};  } # Store viewconfig so we don't have to keep getting it from session

sub input          { return $_[0]{'_input'};          }
sub cookies        { return $_[0]{'_cookies'};        }
sub databases      { return $_[0]{'_databases'};      }
sub object_types   { return $_[0]{'_object_types'};   }
sub core_params    { return $_[0]{'_core_params'};    }
sub apache_handle  { return $_[0]{'_apache_handle'};  }
sub ExtURL         { return $_[0]{'_ext_url'};        }
sub user_details   { return $_[0]{'_user_details'};   }
sub species_defs   { return $_[0]{'_species_defs'};   }
sub config_adaptor { return $_[0]{'_config_adaptor'}; }

sub timer_push        { return ref $_[0]->timer eq 'EnsEMBL::Web::Timer' ? shift->timer->push(@_) : undef;    }
sub referer           { return $_[0]{'referer'}    ||= $_[0]->parse_referer;                                  }
sub colourmap         { return $_[0]{'colourmap'}  ||= new Bio::EnsEMBL::ColourMap($_[0]->species_defs);      }

sub check_ajax        { exists $_[0]{'check_ajax'} or $_[0]{'check_ajax'} = $_[0]->get_cookies('ENSEMBL_AJAX') eq 'enabled';                                return $_[0]{'check_ajax'}; }
sub is_ajax_request   { exists $_[0]{'is_ajax'}    or $_[0]{'is_ajax'}    = $_[0]{'_apache_handle'}->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest';  return $_[0]{'is_ajax'};    }

sub species_path      { return shift->species_defs->species_path(@_);       }
sub table_info        { return shift->species_defs->table_info(@_);         }
sub get_databases     { return shift->databases->get_databases(@_);         }
sub databases_species { return shift->databases->get_databases_species(@_); }
sub delete_param      { shift->input->delete(@_); }

sub has_a_problem      { return scalar keys %{$_[0]{'_problem'}}; }
sub has_fatal_problem  { return scalar @{$_[0]{'_problem'}{'fatal'}||[]}; }
sub has_problem_type   { return scalar @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub get_problem_type   { return @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub clear_problem_type { delete $_[0]{'_problem'}{$_[1]}; }
sub clear_problems     { $_[0]{'_problem'} = {}; }

# Returns the values of cookies
# If only one cookie name is given, returns the value as a scalar
# If more than one cookie name is given, returns a hash of name => value
sub get_cookies {
  my $self     = shift;
  my %cookies  = %{$self->cookies};
  %cookies     = map { exists $cookies{$_} ? ($_ => $cookies{$_}) : () } @_ if @_;
  $cookies{$_} = $cookies{$_}->value for grep exists $cookies{$_}, @_;
  return scalar keys %cookies > 1 ? \%cookies : [ values %cookies ]->[0];
}

sub set_cookie {
  my ($self, $name, $value) = @_;
  
  my $cookie = new CGI::Cookie(
    -name    => $name,
    -value   => $value,
    -domain  => $self->species_defs->ENSEMBL_COOKIEHOST,
    -path    => '/',
    -expires => 'Monday, 31-Dec-2037 23:59:59 GMT'
  );
  
  $self->apache_handle->headers_out->add('Set-cookie' => $cookie);
  $self->apache_handle->err_headers_out->add('Set-cookie' => $cookie);
  
  $self->cookies->{$name} = $cookie;
  
  return !!$cookie;
}

sub problem {
  my $self = shift;
  push @{$self->{'_problem'}{$_[0]}}, new EnsEMBL::Web::Problem(@_) if @_;
  return $self->{'_problem'};
}

sub get_adaptor {
  my ($self, $method, $db, $species) = @_;
  
  $db      ||= 'core';
  $species ||= $self->species;
  
  my $adaptor;
  eval { $adaptor = $self->database($db, $species)->$method(); };

  if ($@) {
    warn $@;
    $self->problem('fatal', "Sorry, can't retrieve required information.", $@);
  }
  
  return $adaptor;
}

sub database {
  my $self = shift;

  if ($_[0] =~ /compara/) {
    return Bio::EnsEMBL::Registry->get_DBAdaptor('multi', $_[0], 1);
  } else {
    return $self->databases->get_DBAdaptor(@_);
  }
}

# Gets the database name used to create the object
sub get_db {
  my $self = shift;
  my $db = $self->param('db') || 'core';
  return $db eq 'est' ? 'otherfeatures' : $db;
}

sub core_objects {
  my $self = shift;
  my $core_objects = shift;
  $self->{'_core_objects'}->{lc $_}        = $core_objects->{$_} for keys %{$core_objects || {}};
  $self->{'_core_objects'}->{'parameters'} = $self->core_params if $core_objects;
  $self->{'_core_objects'}->{'parameters'}->{'db'} ||= 'core';
  return $self->{'_core_objects'};
}

sub core_param { 
  my $self = shift;
  my $name = shift;
  return unless $name;
  $self->{'_core_params'}->{$name} = @_ if @_;
  return $self->{'_core_params'}->{$name};
}

sub set_core_params {
  ### Initialises core parameter hash from CGI parameters

  my $self = shift;
  my $core_params = {};

  foreach (@{$self->species_defs->core_params}) {
    my @param = $self->param($_);
    $core_params->{$_} = scalar @param == 1 ? $param[0] : \@param if scalar @param;
  }

  $self->{'_core_params'} = $core_params;
}

# Determines the species for userdata pages (mandatory, since userdata databases are species-specific)
sub data_species {
  my $self    = shift;
  my $species = $self->species;
  $species    = $self->species_defs->ENSEMBL_PRIMARY_SPECIES if !$species || $species eq 'common';
  return $species;
}

# Does an ordinary redirect
sub redirect {
  my ($self, $url) = @_;
  $self->input->redirect($url || $self->current_url);
}

sub current_url { return $_[0]->url(undef, undef, 1); }

sub url {
  ## Gets the current or modified url
  ## If no argument provided, gets the current url after removing unwanted params, and sorting remaining ones
  ## @param Extra string that goes in the url path just after Species name and before type (optional)
  ## @param Hashref of new params that will be added, or will override the existing params in the current url - can have following keys:
  ##  - species, type, action, funtion: Overrides the existing corresponding values in the url path
  ##  - __clear: Flag if on, prevents the core params to be added to the url
  ##  - any other keys: will get serialised and joined to the url as query string
  ## @param Flag if on, returns url as an arrayref [url path, hashref of name-value pair of GET params] - off by default
  ## @param Flag if on, adds existing GET params to the new given GET params - off by default
  ## @return URL string or ArrayRef of path and params
  my $self   = shift;
  my $extra  = $_[0] && !ref $_[0] ? shift : undef;
  my $params = shift || {};
  my ($flag, $all_params) = @_;

  Carp::croak("Not a hashref while calling _url ($params @_)") unless ref $params eq 'HASH';

  my $species = exists $params->{'species'}  ? $params->{'species'}  : $self->species;
  my $type    = exists $params->{'type'}     ? $params->{'type'}     : $self->type;
  my $action  = exists $params->{'action'}   ? $params->{'action'}   : $self->action;
  my $fn      = exists $params->{'function'} ? $params->{'function'} : $action eq $self->action ? $self->function : undef;
  my %pars;
  
  if ($all_params) {
    # Parse the existing query string to get params if flag is on
    push @{$pars{$_->[0]}}, $_->[1] for map { /^time=/ || /=$/ ? () : [ split /=/ ]} split /;|&/, uri_unescape($self->input->query_string);
  } elsif ($params->{'__clear'}) {
    delete $params->{'__clear'}; # Skip adding the core params if clear flag is on
  } else {
    %pars = %{$self->core_params};

    # Remove any unused params
    foreach (keys %pars) {
      delete $pars{$_} unless $pars{$_};
    }
  }

  delete $pars{'t'}  if $params->{'pt'};
  delete $pars{'pt'} if $params->{'t'};
  delete $pars{'t'}  if $params->{'g'} && $params->{'g'} ne $pars{'g'};
  delete $pars{'time'};
  delete $pars{'expand'};

  # add the requested GET params to the query string
  foreach (keys %$params) {
    next if $_ =~ /^(species|type|action|function)$/;

    if (defined $params->{$_}) {
      $pars{$_} = $params->{$_};
    } else {
      delete $pars{$_};
    }
  }

  my $url = join '/', map $_ || (), $self->species_defs->species_path($species), $extra, $type, $action, $fn;
  
  return [ $url, \%pars ] if $flag;

  $url .= '?' if scalar keys %pars;

  # Sort the keys so that the url is the same for a given set of parameters
  foreach my $p (sort keys %pars) {
    next unless defined $pars{$p};
    
    # Don't escape colon or space
    $url .= sprintf '%s=%s;', uri_escape($p), uri_escape($_, "^A-Za-z0-9\-_ .!~*'():\/") for ref $pars{$p} ? @{$pars{$p}} : $pars{$p};
  }

  $url =~ s/;$//;

  return $url;
}

sub param {
  my $self = shift;
  
  if (@_) {
    my @T = map _sanitize($_), $self->input->param(@_);
    return wantarray ? @T : $T[0] if @T;
    
    my $view_config = $self->viewconfig;
    
    if ($view_config) {
      $view_config->set(@_) if @_ > 1;
      my @val = $view_config->get(@_);
      return wantarray ? @val : $val[0];
    }
    
    return wantarray ? () : undef;
  } else {
    my @params      = map _sanitize($_), $self->input->param;
    my $view_config = $self->viewconfig;
    
    push @params, $view_config->options if $view_config;
    my %params = map { $_, 1 } @params; # Remove duplicates
    
    return keys %params;
  }
}

sub input_param  {
  my $self = shift;
  return _sanitize($self->param(@_));
}

sub multi_params {
  my $self = shift;
  my $realign = shift;

  my $input = $self->input;

  my %params = defined $realign ?
    map { $_ => $input->param($_) } grep { $realign ? /^([srg]\d*|pop\d+|align)$/ && !/^[rg]$realign$/ : /^(s\d+|r|pop\d+|align)$/ && $input->param($_) } $input->param :
    map { $_ => $input->param($_) } grep { /^([srg]\d*|pop\d+|align)$/ && $input->param($_) } $input->param;

  return \%params;
}

sub parse_referer {
  my $self = shift;
  my $species_defs = $self->species_defs;
  
  my $uri = $ENV{'HTTP_REFERER'}; 
  $uri    =~ s/^(https?:\/\/.*?)?\///i;
  $uri    =~ s/[;&]$//;
  
  my ($url, $query_string) = split /\?/, $uri;
  
  my @path = split /\//, $url;
  
  unshift @path, 'common' unless $path[0] =~ /(Multi|common)/ || $species_defs->valid_species($path[0]);
  
  return { absolute_url => $ENV{'HTTP_REFERER'} } unless $ENV{'HTTP_REFERER'} =~ /$ENV{'HTTP_HOST'}/ && $species_defs->OBJECT_TO_SCRIPT->{$path[1]};

  my ($species, $type, $action, $function) = @path;

  my @pairs  = split /[&;]/, $query_string;
  my $params = {};
  
  foreach (@pairs) {
    my ($param, $value) = split '=', $_, 2;
    
    next unless defined $param;
    
    $value = '' unless defined $value;
    $param = uri_unescape($param);
    $value = uri_unescape($value);
    
    push @{$params->{$param}}, $value unless $param eq 'time'; # don't copy time
  }

  if ($species_defs->ENSEMBL_DEBUG_FLAGS & $species_defs->ENSEMBL_DEBUG_REFERER) {
    warn "\n";
    warn "------------------------------------------------------------------------------\n";
    warn "\n";
    warn "  SPECIES:  $species\n";
    warn "  TYPE:     $type\n";
    warn "  ACTION:   $action\n";
    warn "  FUNCTION: $function\n";
    warn "  QS:       $query_string\n";
    
    foreach my $param (sort keys %$params) {
      warn sprintf '%20s = %s\n', $param, $_ for sort @{$params->{$param}};
    }
    
    warn "\n";
    warn "  URI:      $uri\n";
    warn "\n";
    warn "------------------------------------------------------------------------------\n";
  }
  
  return {
    ENSEMBL_SPECIES  => $species,
    ENSEMBL_TYPE     => $type,
    ENSEMBL_ACTION   => $action,
    ENSEMBL_FUNCTION => $function,
    params           => $params,
    uri              => "/$uri",
    absolute_url     => $ENV{'HTTP_REFERER'}
  };
}

sub filename {
  my ($self, $object) = @_;
  
  my $name = sprintf('%s-%s-%s-%d',
    $self->species,
    $self->type,
    $self->action,
    $self->species_defs->ENSEMBL_VERSION
  );
  
  $name .= '-' . $object->stable_id if $object && $object->can('stable_id');
  $name  =~ s/[^-\w\.]/_/g;
  
  return $name;
}

sub _sanitize {
  my $T = shift;
  $T =~ s/<script(.*?)>/[script$1]/igsm;
  $T =~ s/\s+on(\w+)\s*=/ on_$1=/igsm;
  return $T;
} 

sub get_ExtURL {
  my $self = shift;
  my $new_url = $self->ExtURL || return;
  return $new_url->get_url(@_);
}

sub get_ExtURL_link {
  my $self = shift;
  my $text = shift;
  my $url = $self->get_ExtURL(@_);
  return $url ? qq(<a href="$url" rel="external">$text</a>) : $text;
}

# use PFETCH etc to get description and sequence of an external record
sub get_ext_seq {
  my ($self, $id, $ext_db, $strand_mismatch) = @_;
  my $indexer = new EnsEMBL::Web::ExtIndex($self->species_defs);
  
  return [" Could not get an indexer: $@", -1] unless $indexer;
  
  my $seq_ary;
  my %args;
  $args{'ID'} = $id;
  $args{'DB'} = $ext_db ? $ext_db : 'DEFAULT';
  $args{'strand_mismatch'} = $strand_mismatch ? $strand_mismatch : 0;

  eval { $seq_ary = $indexer->get_seq_by_id(\%args); };
  
  if (!$seq_ary) {
    return [ "The $ext_db server is unavailable: $@" , -1];
  } else {
      if ($seq_ary->[0] =~ /Error|No entries found/i) {
	  return [$seq_ary->[0], -1];
      }
    my ($list, $l);
    
    foreach (@$seq_ary) {
      if (!/^>/) {
        $l += length;
        $l-- if /\n/; # don't count carriage returns
      }
      
      $list .= $_;
    }
    
    return $list =~ /no match/i ? [] : [ $list, $l ];
  }
}

# This method gets all configured DAS sources for the current species.
# Source configurations are retrieved first from SpeciesDefs, then additions and
# modifications are added from the User and Session.
# Returns a hashref, indexed by logic_name.
sub get_all_das {
  my $self     = shift;
  my $species  = shift || $self->species;
  $species     = '' if $species eq 'common';
  my @spec_das = $self->species_defs->get_all_das($species);
  my @sess_das = $self->session->get_all_das($species);
  my @user_das = $self->user ? $self->user->get_all_das($species) : ({}, {});

  # TODO: group data??

  # First hash is keyed by logic_name, second is keyed by full_url
  my %by_name = ( %{$spec_das[0]},       %{$user_das[0]},       %{$sess_das[0]}       );
  my %by_url  = ( %{$spec_das[1] || {}}, %{$user_das[1] || {}}, %{$sess_das[1] || {}} );
  
  return wantarray ? (\%by_name, \%by_url) : \%by_name;
}

# This method gets a single named DAS source for the current species.
# The source's configuration is an amalgam of species, user and session data.
sub get_das_by_logic_name {
  my ($self, $name) = @_;
  return $self->get_all_das->{$name};
}

# VIEW / IMAGE CONFIGS

sub get_viewconfig {
  ### Create a new EnsEMBL::Web::ViewConfig object for the component and type passed.
  ### Stores the ViewConfig as $self->viewconfig if a third argument of "cache" is passed.

  my $self       = shift;
  my $component  = shift;
  my $type       = shift || $self->type;
  my $cache      = shift eq 'cache';
  my $session    = $self->session;
  my $cache_code = "${type}::$component";
  
  return undef unless $session;
  
  my $config = $session->view_configs->{$cache_code};
  
  if (!$config) {
    my $module_name = $self->get_module_names('ViewConfig', $type, $component);
    return unless $module_name;
    
    $config = $module_name->new($type, $component, $self);
    
    $session->apply_to_view_config($config, $type, $cache_code, $config->code); # $config->code and $cache_code can be different
  }
  
  $self->viewconfig = $config if $cache;
  
  return $config;
}

sub get_imageconfig {
  ### Returns an EnsEMBL::Web::ImageConfig object
  ### If passed one parameter then it loads the data (and doesn't cache it)
  ### If passed two parameters it loads the data (and caches it against the second name - NOTE you must use the
  ### second name version IF you want the configuration to be saved by the session - otherwise it will be lost
  
  my $self    = shift;
  my $type    = shift;
  my $code    = shift || $type;
  my $species = shift;
  my $session = $self->session;
  
  return undef unless $session;
  return $session->image_configs->{$code} if $session->image_configs->{$code};
  
  my $module_name  = "EnsEMBL::Web::ImageConfig::$type";
  my $image_config = $self->dynamic_use($module_name) ? $module_name->new($self, $species, $code) : undef;
  
  if ($image_config) {
    $session->apply_to_image_config($image_config, $type, $code);
    $image_config->attach_das if $image_config->has_das;
    return $image_config;
  } else {
    $self->dynamic_use_failure($module_name);
    return undef;
  }
}

sub fetch_userdata_by_id {
  my ($self, $record_id) = @_;
  
  return unless $record_id;
  
  my ($type, $code) = split '_', $record_id, 2;
  my $data = {};
  
  if ($type eq 'user') {
    my $user    = $self->user;
    my $user_id = [ split '_', $record_id ]->[1];
    
    return unless $user && $user->id == $user_id;
  } else {
    $data = $self->get_data_from_session($type, $code);
  }
  
  if (!scalar keys %$data) {
    my $fa       = $self->get_adaptor('get_DnaAlignFeatureAdaptor', 'userdata');
    my $aa       = $self->get_adaptor('get_AnalysisAdaptor',        'userdata');
    my $features = $fa->fetch_all_by_logic_name($record_id);
    my $analysis = $aa->fetch_by_logic_name($record_id);
    my $config   = $analysis->web_data;
    
    $config->{'track_name'}  = $analysis->description   || $record_id;
    $config->{'track_label'} = $analysis->display_label || $analysis->description || $record_id;
    
    $data->{$record_id} = { features => $features, config => $config };
  }
  
  return $data;
}

sub get_data_from_session {
  my ($self, $type, $code) = @_;
  my $species  = $self->param('species') || $self->species;
  my $tempdata = $self->session->get_data(type => $type, code => $code);
  my $name     = $tempdata->{'name'};
  my ($content, $format);

  # NB this used to be new EnsEMBL::Web... etc but this does not work with the
  # FeatureParser module for some reason, so have to use FeatureParser->new()
  my $parser = EnsEMBL::Web::Text::FeatureParser->new($self->species_defs, undef, $species);
  
  if ($type eq 'url') {
    my $response = EnsEMBL::Web::Tools::Misc::get_url_content($tempdata->{'url'});
       $content  = $response->{'content'};
  } else {
    my $file    = new EnsEMBL::Web::TmpFile::Text(filename => $tempdata->{'filename'});
       $content = $file->retrieve;
    
    return {} unless $content;
  }
   
  $parser->parse($content, $tempdata->{'format'});

  return { parser => $parser, name => $name };
}

sub initialize_user {
  my ($self, $cookie) = @_;
  my $id = $cookie->get_value;
  
  if ($id) {
    # try to log in with user id from cookie
    eval { 
      $self->user = new EnsEMBL::Web::Data::User($id);
    };
      
    if ($@) {
      # login failed (because the connection to the used db has gone away)
      # so log the user out by clearing the cookie
      $cookie->clear($self->apache_handle);
      $self->user = undef;
    }
  }
}

sub get_favourite_species {
  my $self         = shift;
  my $user         = $self->user;
  my $species_defs = $self->species_defs;
  my @favourites   = $user ? @{$user->favourite_species} : ();
     @favourites   = @{$species_defs->DEFAULT_FAVOURITES || []} unless scalar @favourites;
     @favourites   = ($species_defs->ENSEMBL_PRIMARY_SPECIES, $species_defs->ENSEMBL_SECONDARY_SPECIES) unless scalar @favourites;
  return \@favourites;
}

1;
