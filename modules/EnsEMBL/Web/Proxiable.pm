package EnsEMBL::Web::Proxiable;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::DBSQL::DBConnection;
use CGI qw(escape escapeHTML);

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $data) = @_;
  my $self = { data => $data };
  bless $self, $class;
  return $self; 
}

sub apache_handle     { return $_[0]->{'data'}{'_apache_handle'}; }
sub __data            { return $_[0]->{'data'}; }
sub core_objects      { return $_[0]->{'data'}{'_core_objects'}; }
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
  my %pars    = %{$self->core_objects->{'parameters'}};
  
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
    
    $url .= sprintf '%s%s=%s', $join, escape($_), $self->hack_escape($pars{$_});
    $join = ';';
  }

  return $url;
}

sub hack_escape {
  my ($self, $s) = @_;
  (my $t = escape($s)) =~ s/%3A/:/g;
  return $t;
}

sub timer_push {
  my $self = shift;
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

# Does an ordinary CGI redirect
sub redirect {
  my ($self, $url) = @_;
  $self->{'data'}{'_input'}->redirect($url);
}

sub param {
  my $self = shift;
  
  if (@_) { 
    my @T = map { _sanitize($_) } $self->{'data'}{'_input'}->param(@_);
    return wantarray ? @T : $T[0] if @T;
    my $wsc = $self->viewconfig;
    
    if ($wsc) {
      $wsc->set(@_) if @_ > 1;
      my @val = $wsc->get(@_);
      return wantarray ? @val : $val[0];
    }
    
    return wantarray ? () : undef;
  } else {
    my @params = map { _sanitize($_) } $self->{'data'}{'_input'}->param;
    my $wsc    = $self->viewconfig;
    push @params, $wsc->options if $wsc;
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
    map { $_ => $input->param($_) } grep { $realign ? /^([srg]\d*|align)$/ && !/^[rg]$realign$/ : /^(s\d+|r|align)$/ && $input->param($_) } $input->param :
    map { $_ => $input->param($_) } grep { /^([srg]\d*|align)$/ && $input->param($_) } $input->param;
  
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

sub has_a_problem     { return scalar @{$_[0]->{'data'}{'_problem'}}; }
sub has_fatal_problem { return scalar grep $_->isFatal, @{$_[0]->{'data'}{'_problem'}}; }
sub has_problem_type  { my ($self, $type) = @_; return scalar grep $_->get_by_type($type), @{$self->{'data'}{'_problem'}}; }
sub get_problem_type  { my ($self, $type) = @_; return grep $_->get_by_type($type), @{$self->{'data'}{'_problem'}}; }
sub clear_problems    { $_[0]{'data'}{'_problem'} = []; }

sub problem {
  my $self = shift;
  push @{$self->{'data'}{'_problem'}}, new EnsEMBL::Web::Problem(@_) if @_;
  return $self->{'data'}{'_problem'};
}

# Returns the named (or one based on script) {{EnsEMBL::Web::ImageConfig}} object
sub get_imageconfig  {
  my ($self, $key) = @_;
  my $session = $self->get_session || return;
  my $T = $session->getImageConfig($key); # No second parameter - this isn't cached
  $T->_set_core($self->core_objects);
  return $T;
}

# Retuns a copy of the script config stored in the database with the given key
sub image_config_hash {
  my ($self, $key, $type, @species) = @_;

  $type ||= $key;
  
  my $session = $self->get_session;
  return undef unless $session;
  my $T = $session->getImageConfig($type, $key, @species);
  return unless $T;
  $T->_set_core($self->core_objects);
  return $T;
}

# Returns the named (or one based on script) {{EnsEMBL::Web::ViewConfig}} object
sub get_viewconfig {
  my ($self, $type, $action) = @_;
  my $session = $self->get_session;
  return undef unless $session;
  my $T = $session->getViewConfig( $type || $self->type, $action || $self->action );
  return $T;
}

# Store default viewconfig so we don't have to keep getting it from session
sub viewconfig {
  my $self = shift;
  $self->{'data'}->{'_viewconfig'} ||= $self->get_viewconfig;
  return $self->{'data'}->{'_viewconfig'};
}

sub attach_image_config {
  my ($self, $key, $image_key) = @_;
  my $session = $self->get_session;
  return undef unless $session;
  my $T = $session->attachImageConfig($key, $image_key);
  $T->_set_core($self->core_objects);
  return $T;
}

sub get_ExtURL {
  my $self = shift;
  my $new_url = escapeHTML($self->ExtURL) || return;
  return $new_url->get_url(@_);
}

sub get_ExtURL_link {
  my $self = shift;
  my $text = shift;
  my $url = escapeHTML($self->get_ExtURL(@_));
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

