package EnsEMBL::Web::Resource;

### A container object for data objects and their means of communication 
### with databases, Apache, etc.
### Models are stored as a hash of key-arrayref pairs, since theoretically 
### a page can have more than one data object of a given type attached

use strict;
use warnings;
no warnings 'uninitialized';

use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Proxy::Factory;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $args) = @_;
  my $self = { 
    '_models' => {}, 
  };

  ## Create the hub - a mass of connections to databases, Apache, etc
  $self->{'_hub'} = EnsEMBL::Web::Hub->new(
    '_apache_handle'  => $args->{'_apache_handle'},
    '_input'          => $args->{'_input'},
  );

  bless $self, $class;
  return $self; 
}

sub hub { return $_[0]->{'_hub'}; }
sub all_models { return $_[0]->{'_models'}};

sub models {
### Getter/setter for data models - acts on the default data type for this page if none is specified
### Returns an array of models of the appropriate type
  my ($self, $type, $models) = @_;
  $type ||= $self->type;
  if ($models) {
    my $m = $self->{'_models'}{$type} || [];
    my @a = ref($models) eq 'ARRAY' ? @$models : ($models); 
    push @$m, @a;
    $self->{'_models'}{$type} = $m;
  }
  return @{$self->{'_models'}{$type}};
}

sub model {
### Getter/setter for data models - acts on the default data type for this page if none is specified
### Returns the first model in the array of the appropriate type
  my ($self, $type, $model) = @_;
  $type ||= $self->type;
  if ($model) {
    my $m = $self->{'_models'}{$type} || [];
    push @$m, $model; 
    $self->{'_models'}{$type} = $m;
  }
  return $self->{'_models'}{$type}[0];
}

sub create_factory {
### Creates a Factory object which can then generate one or more Models
  my ($self, $type) = @_;
  return unless $type;

  return EnsEMBL::Web::Proxy::Factory->new($type, {
    _input         => $self->hub->input,
    _apache_handle => $self->hub->apache_handle,
    _databases     => $self->hub->databases,
    _core_objects  => $self->core_objects,
    _parent        => $self->_parse_referer,
  });
}

sub add_models {
### Adds Models created by the factory to this Resource
  my ($self, $data) = @_;
  return unless $data;
  if (ref($data) eq 'ARRAY') {
    foreach my $proxy_object (@$data) {
      $self->models($proxy_object->__objecttype, $proxy_object);
    }
  }
  elsif (ref($data) eq 'HASH') {
    while (my ($key, $object) = each (%$data)) {
      $self->models($key, $object);
    }
  }
}
## Backwards compatibility
sub object {
  my $self = shift;
  return $self->model;
}

## Direct accessors to hub contents, to make life easier!
sub apache_handle     { return $_[0]->hub->apache_handle; }
sub type              { return $_[0]->hub->type; }
sub function          { return $_[0]->hub->function;  }
sub script            { return $_[0]->hub->script;  }
sub species           { return $_[0]->hub->species; }
sub species_defs      { return $_[0]->hub->species_defs }
sub DBConnection      { return $_[0]->hub->databases; }
sub ExtURL            { return $_[0]->hub->ext_url; } 
sub session           { return $_[0]->hub->session; }
sub get_session       { return $_[0]->session; }
sub param             { return $_[0]->hub->param(@_); }
sub delete_param      { my $self = shift; $self->hub->input->delete(@_); }
sub get_databases     { my $self = shift; $self->hub->DBConnection->get_databases(@_); }
sub databases_species { my $self = shift; $self->hub->DBConnection->get_databases_species(@_); }
sub species_path      { my $self = shift; $self->hub->species_defs->species_path(@_); }
sub core_objects      { return $_[0]->hub->core_objects; }
sub cache             { return $_[0]->hub->cache; }
sub parent            { return $_[0]->hub->parent; }

sub action {
  my ($self, $action) = @_;
  if ($action) {
    $self->hub->action($action);
  }
  return $self->hub->action;  
}

sub url             { return $_[0]->hub->url(@_); }
sub _url            { return $_[0]->hub->url(@_); }
sub viewconfig      { return $_[0]->hub->viewconfig; }
sub get_viewconfig  { return $_[0]->hub->get_viewconfig(@_); }

## TODO - needs to return hub and data objects
sub __data            { return $_[0]->{'data'}; }

sub table_info {
  my $self = shift;
  return $self->species_defs->table_info( @_ );
}


sub timer_push {
  my $self = shift;
  
  return unless ref $self->hub->timer eq 'EnsEMBL::Web::Timer';
  return $self->hub->timer->push(@_);
}

# Does an ordinary redirect
sub redirect {
  my ($self, $url) = @_;
  $self->hub->input->redirect($url);
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

sub has_a_problem      {} #return scalar keys %{$_[0]->hub->problem}; }
sub has_fatal_problem  {} # return scalar @{$_[0]->hub->problem_type('fatal'); }
sub has_problem_type   {} # return scalar @{$_[0]->hub->problem_type($_[1])}; }
sub get_problem_type   {} # return @{$_[0]->hub->problem($_[1])}; }
sub clear_problem_type {} # $_[0]->hub->clear_problem($_[1]); }
sub clear_problems     {} # $_[0]->hub->clear_problems; }

sub problem {} # $_[0]->hub->problem($_[1], @_); }

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
  
  my $session = $self->get_session;
  return undef unless $session;
  my $T = $session->getImageConfig($type, $key, @species);
  return unless $T;
  $T->_set_core($self->core_objects);
  return $T;
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

