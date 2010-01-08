package EnsEMBL::Web::Hub;

### A centralised object giving access to database connections, 
### CGI parameters, session, logged-in user, etc

use strict;

use EnsEMBL::Web::Problem;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::CoreObjects;
use EnsEMBL::Web::DBSQL::DBConnection;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, %args) = @_;
  
  my $self = {
      _apache_handle  => $args{'_apache_handle'} || undef,
      _input          => $args{'_input'}         || undef,                    # extension of CGI
      _species        => $args{'_species'}       || $ENV{'ENSEMBL_SPECIES'},
      _type           => $args{'_type'}          || $ENV{'ENSEMBL_TYPE'},     # Parsed from URL:  Gene, UserData, etc
      _action         => $args{'_action'}        || $ENV{'ENSEMBL_ACTION'},   # View, Summary etc
      _function       => $args{'_function'}      || $ENV{'ENSEMBL_FUNCTION'}, # Extra path info
      _script         => $args{'_script'}        || $ENV{'ENSEMBL_SCRIPT'},   # name of script in this case action... ## deprecated
      _species_defs   => $args{'_species_defs'}  || new EnsEMBL::Web::SpeciesDefs, 
      _session        => $ENSEMBL_WEB_REGISTRY->get_session,
      _cache          => $args{'_cache'}
                          || new EnsEMBL::Web::Cache(enable_compress => 1, compress_threshold => 10000),

      _problem        => $args{'_problem'}       || {},    
      _ext_url        => $args{'_ext_url'}       || undef,                    # EnsEMBL::Web::ExtURL object used to create external links
      _user           => $args{'_user'}          || undef,                    
      _view_configs   => $args{'_view_configs_'} || {},
      _user_details   => $args{'_user_details'}  || 1,
      _web_user_db    => $args{'_web_user_db'}   || undef,
      _timer          => $args{'_timer'}         || [],                       # Diagnostic object
  };
  
  bless $self, $class;
 
  my $db_connection = $self->species ne 'common' ? 
                        new EnsEMBL::Web::DBSQL::DBConnection($self->species, $self->species_defs) : undef;
  my $core_objects  = new EnsEMBL::Web::CoreObjects($self->input, $db_connection);
  $self->databases($db_connection);
  $self->core_objects($core_objects);
 
  $self->species_defs->{'timer'} = $args{'_timer'};
  
  return $self;
}

# Accessor functionality
sub species      :lvalue { $_[0]{'_species'};  }
sub type         :lvalue { $_[0]{'_type'};   }
sub parent       :lvalue { $_[0]{'_parent'};   }
sub script       :lvalue { $_[0]{'_script'};   }
sub function     :lvalue { $_[0]{'_function'}; }
sub session      :lvalue { $_[0]{'_session'}; }
sub databases    :lvalue { $_[0]{'_databases'}; }
sub cache        :lvalue { $_[0]{'_cache'};   }

sub action {
  my ($self, $action) = @_;
  if ($action) {
    $self->{'_action'} = $action;
  }
  return $self->{'_action'};
}

sub core_objects {
  my ($self, $core_objects) = @_;
  if ($core_objects) {
    $self->{'_core_objects'} = $core_objects;
  }
  return $self->{'_core_objects'};
}

sub apache_handle   { return $_[0]{'_apache_handle'}; }
sub species_defs    { return $_[0]{'_species_defs'} ||= new EnsEMBL::Web::SpeciesDefs; }
sub user_details    { return $_[0]{'_user_details'} ||= 1; }
sub timer           { return $_[0]{'_timer'}; }
sub timer_push      { return ref $_[0]->timer eq 'EnsEMBL::Web::Timer' ? $_[0]->timer->push(@_) : undef; }

sub has_a_problem      { return scalar keys %{$_[0][1]{'_problem'}}; }
sub has_fatal_problem  { return scalar @{$_[0][1]{'_problem'}{'fatal'}||[]}; }
sub has_problem_type   { return scalar @{$_[0][1]{'_problem'}{$_[1]}||[]}; }
sub get_problem_type   { return @{$_[0][1]{'_problem'}{$_[1]}||[]}; }
sub clear_problem_type { $_[0][1]{'_problem'}{$_[1]} = []; }
sub clear_problems     { $_[0][1]{'_problem'} = {}; }

sub problem {
  my $self = shift;
  push @{$self->[1]{'_problem'}{$_[0]}}, new EnsEMBL::Web::Problem(@_) if @_;
  return $self->[1]{'_problem'};
}

sub core_params {
  my $self = shift;
  my @params = $self->species_defs->core_params;
  my %core_params = map { $_ => $self->param($_) } @params;
  return \%core_params;
}

sub url {
  my $self = shift;
  my $params = shift || {};

  Carp::croak("Not a hashref while calling _url ($params @_)") unless ref($params) eq 'HASH';

  my $species = exists($params->{'species'})  ? $params->{'species'}  : $self->species;
  my $type    = exists($params->{'type'})     ? $params->{'type'}     : $self->type;
  my $action  = exists($params->{'action'})   ? $params->{'action'}   : $self->action;
  my $fn      = exists($params->{'function'}) ? $params->{'function'} : ($action eq $self->action ? $self->function : undef);
  my %pars    = %{$self->core_params};

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

  my $url = sprintf '%s/%s/%s', $self->species_path($species), $type, $action.( $fn ? "/$fn" : '' );
  my $join = '?';

  my $flag = shift;

  return [$url, \%pars] if $flag;

  # Sort the keys so that the url is the same for a given set of parameters
  foreach (sort keys %pars) {
    next unless defined $pars{$_};

    $url .= sprintf '%s%s=%s', $join, uri_escape($_), uri_escape($pars{$_}, "^A-Za-z0-9\-_.!~*'():"); # Don't escape :
    $join = ';';
  }

  return $url;
}

### Wrappers around CGI parameter access
sub input     :lvalue { $_[0]{'_input'}; }

sub param {
  my $self = shift;
  
  if (@_) {
    my @T = map { _sanitize($_) } $self->input->param(@_);
    return wantarray ? @T : $T[0] if @T;
    my $view_config = $self->viewconfig;
    
    if ($view_config) {
      $view_config->set(@_) if @_ > 1;
      my @val = $view_config->get(@_);
      return wantarray ? @val : $val[0];
    }
   
    return wantarray ? () : undef;
  } else {
    my @params = map { _sanitize($_) } $self->input->param;
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


1;
