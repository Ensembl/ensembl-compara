package EnsEMBL::Web::Hub;

### NAME: EnsEMBL::Web::Hub 
### A centralised object giving access to data connections and the web environment 

### STATUS: Under development
### Currently being developed, along with its associated moduled E::W::Resource,
### as a replacement for Proxy/Proxiable code

### DESCRIPTION:
### Hub is intended as a replacement for both the non-object-specific
### portions of Proxiable and the global variable ENSEMBL_WEB_REGISTRY
### It uses the Flyweight design pattern to create a single object that is 
### passed around between all other objects that require data connectivity.
### The Hub stores information about the current web page and its environment, 
### including cgi parameters, settings parsed from the URL, browser session, 
### database connections, and so on.

use strict;

use Carp;
use URI::Escape qw(uri_escape);

use EnsEMBL::Web::CoreObjects;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::SpeciesDefs;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, %args) = @_;

  my $type = $args{'_type'} || $ENV{'ENSEMBL_TYPE'}; # Parsed from URL:  Gene, UserData, etc
  $type = 'DAS' if $type =~ /^DAS::.+/;

  my $self = {
    _apache_handle => $args{'_apache_handle'} || undef,
    _input         => $args{'_input'}         || undef,                        # extension of CGI
    _species       => $args{'_species'}       || $ENV{'ENSEMBL_SPECIES'},    
    _type          => $type,
    _action        => $args{'_action'}        || $ENV{'ENSEMBL_ACTION'},       # View, Summary etc
    _function      => $args{'_function'}      || $ENV{'ENSEMBL_FUNCTION'},     # Extra path info
    _script        => $args{'_script'}        || $ENV{'ENSEMBL_SCRIPT'},       # name of script in this case action... ## deprecated
    _species_defs  => $args{'_species_defs'}  || new EnsEMBL::Web::SpeciesDefs, 
    _cache         => $args{'_cache'}         || new EnsEMBL::Web::Cache(enable_compress => 1, compress_threshold => 10000),
    _problem       => $args{'_problem'}       || {},    
    _ext_url       => $args{'_ext_url'}       || undef,                        # EnsEMBL::Web::ExtURL object used to create external links
    _user          => $args{'_user'}          || undef,                    
    _view_configs  => $args{'_view_configs_'} || {},
    _user_details  => $args{'_user_details'}  || 1,
    _timer         => $args{'_timer'}         || $ENSEMBL_WEB_REGISTRY->timer, # Diagnostic object
    _session       => $ENSEMBL_WEB_REGISTRY->get_session,
  };

  bless $self, $class;

  ## Get database connections 
  my $api_connection = $self->species ne 'common' ? new EnsEMBL::Web::DBSQL::DBConnection($self->species, $self->species_defs) : undef;
  $self->{'_databases'} = $api_connection;

  ## TODO - remove core objects! 
  $self->{'_core_objects'}  = new EnsEMBL::Web::CoreObjects($self->input, $api_connection);
  $self->_set_core_params;

  $self->species_defs->{'timer'} = $args{'_timer'};

  return $self;
}

# Accessor functionality
sub species   :lvalue { $_[0]{'_species'};   }
sub script    :lvalue { $_[0]{'_script'};    }
sub type      :lvalue { $_[0]{'_type'};      }
sub action    :lvalue { $_[0]{'_action'};    }
sub function  :lvalue { $_[0]{'_function'};  }
sub parent    :lvalue { $_[0]{'_parent'};    }
sub session   :lvalue { $_[0]{'_session'};   }
sub databases :lvalue { $_[0]{'_databases'}; } 
sub cache     :lvalue { $_[0]{'_cache'};     }
sub user      :lvalue { $_[0]{'_user'};      }

sub input         { return $_[0]{'_input'};         }
sub core_objects  { return $_[0]{'_core_objects'};  }
sub core_params   { return $_[0]{'_core_params'};   }
sub apache_handle { return $_[0]{'_apache_handle'}; }
sub species_defs  { return $_[0]{'_species_defs'} ||= new EnsEMBL::Web::SpeciesDefs; }
sub user_details  { return $_[0]{'_user_details'} ||= 1; }
sub timer         { return $_[0]{'_timer'}; }
sub timer_push    { return ref $_[0]->timer eq 'EnsEMBL::Web::Timer' ? $_[0]->timer->push(@_) : undef; }

sub has_a_problem      { return scalar keys %{$_[0]{'_problem'}}; }
sub has_fatal_problem  { return scalar @{$_[0]{'_problem'}{'fatal'}||[]}; }
sub has_problem_type   { return scalar @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub get_problem_type   { return @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub clear_problem_type { $_[0]{'_problem'}{$_[1]} = []; }
sub clear_problems     { $_[0]{'_problem'} = {}; }

sub problem {
  my $self = shift;
  push @{$self->{'_problem'}{$_[0]}}, new EnsEMBL::Web::Problem(@_) if @_;
  return $self->{'_problem'};
}

sub core_param  { 
  my $self = shift;
  my $name = shift;
  return unless $name;
  $self->{'_core_params'}->{$name} = @_ if @_;
  return $self->{'_core_params'}->{$name};
}

sub _set_core_params {
  ### Initialises core parameter hash from CGI parameters

  my $self = shift;
  my @params = @{$self->species_defs->core_params};
  my %core_params = map { $_ => $self->param($_) } @params;
  $self->{'_core_params'} = \%core_params;
}

# Does an ordinary redirect
sub redirect {
  my ($self, $url) = @_;
  $self->{'_input'}->redirect($url);
}

sub url {
  my $self = shift;
  my $params = shift || {};

  Carp::croak("Not a hashref while calling _url ($params @_)") unless ref $params eq 'HASH';

  my $species = exists $params->{'species'}  ? $params->{'species'}  : $self->species;
  my $type    = exists $params->{'type'}     ? $params->{'type'}     : $self->type;
  my $action  = exists $params->{'action'}   ? $params->{'action'}   : $self->action;
  my $fn      = exists $params->{'function'} ? $params->{'function'} : $action eq $self->action ? $self->function : undef;
  my %pars    = %{$self->core_params};

  # Remove any unused params
  foreach (keys %pars) {
    delete $pars{$_} unless $pars{$_};
  }

  if ($params->{'__clear'}) {
    %pars = ();
    delete $params->{'__clear'};
  }

  delete $pars{'t'}  if $params->{'pt'};
  delete $pars{'pt'} if $params->{'t'};
  delete $pars{'t'}  if $params->{'g'} && $params->{'g'} ne $pars{'g'};
  delete $pars{'time'};

  foreach (keys %$params) {
    next if $_ =~ /^(species|type|action|function)$/;

    if (defined $params->{$_}) {
      $pars{$_} = $params->{$_};
    } else {
      delete $pars{$_};
    }
  }

  my $url  = sprintf '%s/%s/%s', $self->species_defs->species_path($species), $type, $action . ($fn ? "/$fn" : '');
  my $flag = shift;

  return [ $url, \%pars ] if $flag;

  $url .= '?' if scalar keys %pars;

  # Sort the keys so that the url is the same for a given set of parameters
  foreach my $p (sort keys %pars) {
    next unless defined $pars{$p};

    # Don't escape :
    $url .= sprintf '%s=%s;', uri_escape($p), uri_escape($_, "^A-Za-z0-9\-_.!~*'():") for ref $pars{$p} ? @{$pars{$p}} : $pars{$p};
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
    my @params = map _sanitize($_), $self->input->param;
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

sub _sanitize {
  my $T = shift;
  $T =~ s/<script(.*?)>/[script$1]/igsm;
  $T =~ s/\s+on(\w+)\s*=/ on_$1=/igsm;
  return $T;
} 

### VIEWCONFIGS

# Returns the named (or one based on script) {{EnsEMBL::Web::ViewConfig}} object
sub get_viewconfig {
  my ($self, $type, $action) = @_;
  my $session = $self->session;
  return undef unless $session;
  my $T = $session->getViewConfig( $type || $self->type, $action || $self->action );
  return $T;
}

# Store default viewconfig so we don't have to keep getting it from session
sub viewconfig {
  my $self = shift;
  $self->{'_viewconfig'} ||= $self->get_viewconfig;
  return $self->{'_viewconfig'};
}

# Returns the named (or one based on script) {{EnsEMBL::Web::ImageConfig}} object
sub get_imageconfig  {
  my ($self, $key) = @_;
  my $session = $self->session || return;
  my $T = $session->getImageConfig($key); # No second parameter - this isn't cached
  $T->_set_core($self->core_objects);
  return $T;
}

# Retuns a copy of the script config stored in the database with the given key
sub image_config_hash {
  my ($self, $key, $type, @species) = @_;

  $type ||= $key;

  my $session = $self->session;
  return undef unless $session;
  my $T = $session->getImageConfig($type, $key, @species);
  return unless $T;
  $T->_set_core($self->core_objects);
  return $T;
}



1;
