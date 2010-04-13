package EnsEMBL::Web::Proxiable;

### NAME: Proxiable.pm
### Base class for data objects and factories

### PLUGGABLE: No - but part of Proxy plugin infrastructure

### STATUS: At Risk
### * duplicates Resource/Hub functionality 
### * multiple methods of plugin-handling are confusing!

### DESCRIPTION
### A Proxiable object contains both the data object (either
### an Object or a Factory) and all the 'connections' (db handles, 
### cgi parameters, web session, etc) needed to support 
### manipulation of that data

use strict;
use warnings;
no warnings 'uninitialized';

use URI::Escape qw(uri_escape);

use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Problem;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $data) = @_;
  
  $data->{'_type'}    ||= $ENV{'ENSEMBL_TYPE'};
  $data->{'_action'}  ||= $ENV{'ENSEMBL_ACTION'};
  $data->{'_function'}||= $ENV{'ENSEMBL_FUNCTION'}; 
  $data->{'_species'} ||= $ENV{'ENSEMBL_SPECIES'};
  $data->{'timer'}    ||= $ENSEMBL_WEB_REGISTRY->timer;

  my $self = { data => $data };
  bless $self, $class;
  return $self; 
}

sub __data            { return $_[0]->{'data'}; }
sub __objecttype      { return $_[0]->{'data'}{'_objecttype'}; }
sub parent            { return $_[0]->hub->parent; }
sub apache_handle     { return $_[0]->{'data'}{'_apache_handle'}; }
sub hub               { return $_[0]->{'data'}{'_hub'}; }
sub type              { return $_[0]->{'data'}{'_type'}; }
sub action            { return $_[0]->{'data'}{'_action'};  }
sub function          { return $_[0]->{'data'}{'_function'};  }
sub script            { return $_[0]->{'data'}{'_script'};  }
sub species           { return $_[0]->{'data'}{'_species'}; }
sub species_defs      { return $_[0]->{'data'}{'_species_defs'} ||= $ENSEMBL_WEB_REGISTRY->species_defs; }
sub DBConnection      { return $_[0]->{'data'}{'_databases'}    ||= new EnsEMBL::Web::DBSQL::DBConnection($_[0]->species, $_[0]->species_defs); }
sub ExtURL            { return $_[0]->{'data'}{'_ext_url_'}     ||= new EnsEMBL::Web::ExtURL($_[0]->species, $_[0]->species_defs); } # Handling ExtURLs
sub session           { return $_[0]->{'session'} ||= $ENSEMBL_WEB_REGISTRY->get_session; }
sub get_session       { return $_[0]->{'session'} ||  $ENSEMBL_WEB_REGISTRY->get_session; }
sub user              { return defined $_[0]->{'user'} ? $_[0]->{'user'} : ($_[0]->{'user'} = $ENSEMBL_WEB_REGISTRY->get_user || 0); }
sub delete_param      { my $self = shift; $self->{'data'}{'_input'}->delete(@_); }
sub get_databases     { my $self = shift; $self->DBConnection->get_databases(@_); }
sub databases_species { my $self = shift; $self->DBConnection->get_databases_species(@_); }
sub species_path      { my $self = shift; $self->species_defs->species_path(@_); }

sub table_info {
  my $self = shift;
  return $self->species_defs->table_info( @_ );
}

sub _url {
  my $self = shift;
  my $params = shift || {};
  
  die "Not a hashref while calling _url ($params @_)" unless ref($params) eq 'HASH';
  
  my $species = exists($params->{'species'})  ? $params->{'species'}  : $self->species;
  my $type    = exists($params->{'type'})     ? $params->{'type'}     : $self->type;
  my $action  = exists($params->{'action'})   ? $params->{'action'}   : $self->action;
  my $fn      = exists($params->{'function'}) ? $params->{'function'} : ($action eq $self->action ? $self->function : undef);
  my %pars    = %{$self->hub->core_params};
  ### Remove any unused params
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
  
  my $url = sprintf '%s/%s/%s', $self->species_path($species), $type, $action.( $fn ? "/$fn" : '' );
  
  my $flag = shift;
  
  return [$url, \%pars] if $flag;
  
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

sub timer_push {
  my $self = shift;
  
  return unless ref $self->{'data'}{'timer'} eq 'EnsEMBL::Web::Timer';
  return $self->{'data'}{'timer'}->push(@_);
}

sub input { 
  my $self = shift;
  $self->{'data'}{'_input'} = shift if @_;
  return $self->{'data'}{'_input'};
}

sub _sanitize {
  my $T = shift;
  $T =~ s/<script(.*?)>/[script$1]/igsm;
  $T =~ s/\s+on(\w+)\s*=/ on_$1=/igsm;
  return $T;
}

# Does an ordinary redirect
sub redirect {
  my ($self, $url) = @_;
  $self->{'data'}{'_input'}->redirect($url);
}

sub param {
  my $self = shift;
  
  if (@_) { 
    my @T = map { _sanitize($_) } $self->{'data'}{'_input'}->param(@_);
    return wantarray ? @T : $T[0] if @T;
    my $view_config = $self->viewconfig;
    
    if ($view_config) {
      $view_config->set(@_) if @_ > 1;
      my @val = $view_config->get(@_);
      return wantarray ? @val : $val[0];
    }
    
    return wantarray ? () : undef;
  } else {
    my @params = map { _sanitize($_) } $self->{'data'}{'_input'}->param;
    my $view_config = $self->viewconfig;
    push @params, $view_config->options if $view_config;
    my %params = map { $_, 1 } @params; # Remove duplicates
    
    return keys %params;
  }
}

sub input_param  {
  my $self = shift;
  return _sanitize($self->{'data'}{'_input'}->param(@_));
}

sub multi_params {
  my $self = shift;
  my $realign = shift;
  
  my $input = $self->{'data'}{'_input'};
  
  my %params = defined $realign ? 
    map { $_ => $input->param($_) } grep { $realign ? /^([srg]\d*|pop\d+|align)$/ && !/^[rg]$realign$/ : /^(s\d+|r|pop\d+|align)$/ && $input->param($_) } $input->param :
    map { $_ => $input->param($_) } grep { /^([srg]\d*|pop\d+|align)$/ && $input->param($_) } $input->param;
  
  return \%params;
}

# Determines the species for userdata pages (mandatory, since userdata databases are species-specific)
sub data_species {
  my $self = shift;
  my $species = $self->species;
  $species = $self->species_defs->ENSEMBL_PRIMARY_SPECIES if !$species || $species eq 'common';
  return $species;
}

sub database {
  my $self = shift;
  
  if ($_[0] =~ /compara/) {
    return Bio::EnsEMBL::Registry->get_DBAdaptor('multi', $_[0]);
  } else {
    return $self->DBConnection->get_DBAdaptor(@_);
  }
}

##---------- BACKWARDS COMPATIBILITY - WRAPPERS AROUND HUB METHODS -------------

# Returns the named (or one based on script) {{EnsEMBL::Web::ImageConfig}} object
sub get_imageconfig  {
  my $self = shift;
  return $self->hub->get_imageconfig(@_);
}

# Retuns a copy of the script config stored in the database with the given key
sub image_config_hash {
  my $self = shift;
  return $self->hub->image_config_hash(@_);
}

# Returns the named (or one based on script) {{EnsEMBL::Web::ViewConfig}} object
sub get_viewconfig {
  my $self = shift;
  return $self->hub->get_viewconfig(@_);
}

# Store default viewconfig so we don't have to keep getting it from session
sub viewconfig {
  my $self = shift;
  return $self->hub->viewconfig(@_);
}

sub attach_image_config {
  my $self = shift;
  return $self->hub->viewconfig(@_);
}

##---------------------------------------------------------------

sub get_ExtURL {
  my $self = shift;
  my $new_url = $self->ExtURL || return;
  return $new_url->get_url(@_);
}

sub get_ExtURL_link {
  my $self = shift;
  my $text = shift;
  my $url = $self->get_ExtURL(@_);
  return $url ? qq(<a href="$url">$text</a>) : $text;
}

# use PFETCH etc to get description and sequence of an external record
sub get_ext_seq {
  my ($self, $id, $ext_db) = @_;
  my $indexer = new EnsEMBL::Web::ExtIndex($self->species_defs);
  
  return unless $indexer;
  
  my $seq_ary;
  my %args;
  $args{'ID'} = $id;
  $args{'DB'} = $ext_db ? $ext_db : 'DEFAULT';

  eval { $seq_ary = $indexer->get_seq_by_id(\%args); };
  
  if (!$seq_ary) {
    warn "The $ext_db server is unavailable: $@";
    return '';
  } else {
    my $list = join ' ', @$seq_ary;
    return $list =~ /no match/i ? '' : $list;
  }
}

1;

