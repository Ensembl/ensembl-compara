package EnsEMBL::Web::Model;

### NAME: EnsEMBL::Web::Model
### The M in the MVC design pattern - a container for domain objects

### PLUGGABLE: No

### STATUS: Under development
### Currently being developed, along with its associated moduled E::W::Hub,
### as a replacement for Proxy/Proxiable/CoreObjects code

### DESCRIPTION:
### Model is a container for domain objects such as Location, Gene, 
### and User plus a single helper module, Hub (see separate documentation).
### Domain objects are stored as a hash of key-object pairs
### E.g.
### $self->{'_data'} = {
###   'Location'  => $x,
###   'Gene'      => $y,
###   'UserData'  => $gff,
### };
### Note: Currently, most domain objects are Proxy::Object objects (containing
### a single API object), but an alternative implementation is under development 
### which can contain multiple API objects in each domain object

use strict;
use warnings;
no warnings 'uninitialized';

use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $args) = @_;
  my $self = { 
    '_data' => {}, 
    '_tabs' => [],
  };

  ## Create the hub - a mass of connections to databases, Apache, etc
  $self->{'_hub'} = EnsEMBL::Web::Hub->new(
    '_apache_handle'  => $args->{'_apache_handle'},
    '_input'          => $args->{'_input'},
  );

  bless $self, $class;
  
  $self->hub->parent = $self->_parse_referer;
  
  return $self; 
}

sub hub { return $_[0]->{'_hub'}; }
sub tabs    :lvalue { $_[0]->{'_hub'}{'_tabs'}};

sub add_tab {
  my ($self, $tab, $direction) = @_;
  return unless $tab && ref($tab) eq 'HASH';
  if ($direction eq 'previous') {
    unshift @{$self->hub->tab_order}, $tab->{'type'};
  }
  else {
    push @{$self->hub->tab_order}, $tab->{'type'};
  }
  $self->hub->add_tab($tab);
}

sub all_data {
### Getter/setter for domain objects
### Returns all the domain objects 
  my ($self, $hash) = @_;
  if ($hash) {
    $self->{'_data'} = $hash;
  } 
  return $self->{'_data'};
}

sub data {
### Getter/setter for data objects - acts on the default data type 
### for this page if none is specified
  my ($self, $type, $object) = @_;
  $type ||= $self->hub->type;
  if ($object) {
    $self->{'_data'}{$type} = $object;
  }
  return $self->{'_data'}{$type};
}

sub object {
### Backwards compatibility - wrapper around 'data'
  my $self = shift;
  return $self->data(@_);
}

sub api_object {
### returns the underlying API object(s)
  my ($self, $type, $subtype) = @_;
  my $object = $self->{'_data'}{$type};
  return unless $object;
  if ($type eq 'Location') {
    return $object->slice;
  }
  elsif ($type eq 'Feature') {
    return $self->{'_data'}{'Feature'};
  }
  else {
    return $object->Obj;
  }
}

sub all_features {
### Direct access to Feature, which is a nested hash of
### domain objects used to render point data on whole chromosomes
### Returns a hash of key-arrayref pairs
  my $self = shift;
  return $self->{'_data'}{'Feature'};
}

sub features_of_type {
### Direct access to Feature, which is a nested hash of
### domain objects used to render point data on whole chromosomes
### Arg 1: type of features to return
### Returns: arrayref of features of that type
  my ($self, $type) = @_;
  return unless $type;
  return $self->{'_data'}{'Feature'}{$type};
}

sub create_data_object_of_type {
  my $self = shift;
  my $type = shift || $self->hub->type;
  my $data;
  my $class = 'EnsEMBL::Web::Data::'.$type;
  if ($self->dynamic_use($class)) {
    $data = $class->new($self->hub, @_);
    $self->data($type, $data) if $data;
  }
}

sub create_domain_object {  
  my ($self, $type, $params) = @_;
  
  my $hub     = $self->hub;
  my $factory = $self->create_factory($type);
  my $problem;
  
  if ($factory) {
    if ($hub->has_fatal_problem) {
      $problem = $hub->problem('fatal', 'Fatal problem in the factory')->{'fatal'};
    } 
    else {
      eval {
        $factory->createObjects($params);
      };
      
      $hub->problem('fatal', "Unable to execute createObject on Factory of type " . $hub->type, $@) if $@;
      
      # $hub->handle_problem returns string 'redirect', or array ref of EnsEMBL::Web::Problem object
      if ($hub->has_a_problem) {
        $problem = $hub->handle_problem; 
      } 
      else {
        my $DO = $factory->DataObjects;
        if (@$DO > 1) {
          warn ">>> MULTIPLE DOMAIN OBJECTS OF TYPE $type";
        }
        $self->data($type, $DO->[0]);
      }
    }
  }
  
  return $problem;
}

sub create_factory {
  ### Creates a Factory object which can then generate one or more 
  ### domain objects
  
  my ($self, $type) = @_;
  
  return unless $type;
  
  return $self->new_factory($type, {
    _model         => $self,
    _hub           => $self->hub,
    _input         => $self->hub->input,
    _apache_handle => $self->hub->apache_handle,
    _databases     => $self->hub->databases,
    _core_info     => $self->hub->tabs,
    _parent        => $self->hub->parent,
  });
}

sub core_param_strings {
  my $self = shift;

  my $location     = $self->api_object('Location');
  my $gene         = $self->api_object('Gene');
  my $transcript   = $self->api_object('Transcript');
  my $params       = [];
 
  push @$params, sprintf 'r=%s:%s-%s', $location->seq_region_name, $location->start, $location->end if $location;
  push @$params, 'g=' . $gene->stable_id if $gene;
  push @$params, 't=' . $transcript->stable_id if $transcript;

  return $params;
}


sub munge_features_for_drawing {
### Converts full objects into simple data structures that can be used by the drawing code
  my ($self, $types) = @_;
  my $drawable_features = {};
  my $stored_features = $self->{'_data'}{'Feature'};

  while (my ($type, $domain_object) = each(%$stored_features)) {
    next unless $domain_object;
    my $parameters = $domain_object->convert_to_drawing_parameters;
    $drawable_features->{$type} = $parameters;
  }
  return $drawable_features;
}

1;

