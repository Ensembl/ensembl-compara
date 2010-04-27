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
### Domain objects are stored as a hash of key-arrayref pairs, since 
### theoretically a page can have more than one domain object of a 
### given type.
### E.g.
### $self->{'_objects'} = {
###   'Location'  => [$x],
###   'Gene'      => [$a, $b, $c],
###   'UserData'  => [$bed, $gff],
### };
### Note: Currently, most domain objects are Proxy::Object objects, but an
### alternative implementation is under development 

use strict;
use warnings;
no warnings 'uninitialized';

use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $args) = @_;
  my $self = { 
    '_objects'      => {}, 
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
sub all_objects { return $_[0]->{'_objects'}};

sub objects {
### Getter/setter for domain objects - acts on the default data type 
### for this page if none is specified
### Returns an array of objects of the appropriate type
  my ($self, $type, $objects) = @_;
  $type ||= $self->type;
  if ($objects) {
    my $m = $self->{'_objects'}{$type} || [];
    my @a = ref($objects) eq 'ARRAY' ? @$objects : ($objects); 
    push @$m, @a;
    $self->{'_objects'}{$type} = $m;
  }
  return @{$self->{'_objects'}{$type}};
}

sub object {
### Getter/setter for data objects - acts on the default data type 
### for this page if none is specified
### Returns the first object in the array of the appropriate type
  my ($self, $type, $object) = @_;
  $type ||= $self->hub->type;
  if ($object) {
    my $m = $self->{'_objects'}{$type} || [];
    push @$m, $object; 
    $self->{'_objects'}{$type} = $m;
  }
  return $self->{'_objects'}{$type}[0];
}

sub add_objects {
### Adds domain objects created by the factory to this Model
  my ($self, $data, $type) = @_;
  return unless $data;
  $type ||= $self->hub->type;

  ### Proxy Object(s)
  if (ref($data) eq 'ARRAY') {
    foreach my $proxy_object (@$data) {
      $self->object($type, $proxy_object);
    }
  }
  ### Other object type
  elsif (ref($data) eq 'HASH') {
    while (my ($key, $object) = each (%$data)) {
      $self->object($key, $object);
    }
  }
}

sub create_data_object_of_type {
  my ($self, $type, $args) = @_;
  my $object;
  my $class = 'EnsEMBL::Web::Data::'.$type;
  if ($self->dynamic_use($class)) {
    $object = $class->new($self->hub, $args);
    $self->object($object->type, $object) if $object;
  }
}

sub create_objects {  
  my ($self, $type) = @_;
  
  my $hub     = $self->hub;
  $type       ||= $hub->type;
  my $factory = $self->create_factory($type);
  my $problem;
  
  if ($factory) {
    if ($hub->has_fatal_problem) {
      $problem = $hub->problem('fatal', 'Fatal problem in the factory')->{'fatal'};
    } else {
      eval {
        $factory->createObjects;
      };
      
      $hub->problem('fatal', "Unable to execute createObject on Factory of type " . $type, $@) if $@;
      
      # $hub->handle_problem returns string 'redirect', or array ref of EnsEMBL::Web::Problem object
      if ($hub->has_a_problem) {
        $problem = $hub->handle_problem; 
      } else {
        #my $DO = $factory->DataObjects;
        #if (@$DO > 1) {
        #  foreach my $do (@$DO) {
        #    my @namespace = split('::', ref($do));
        #    $self->data($namespace[-1], $do);
        #  }
        #}
        #$self->data($type, $DO->[0]);
        $self->add_objects($factory->DataObjects, $type);
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
    _hub           => $self->hub,
    _input         => $self->hub->input,
    _apache_handle => $self->hub->apache_handle,
    _databases     => $self->hub->databases,
    _core_objects  => $self->hub->core_objects,
    _parent        => $self->hub->parent,
  });
}

sub munge_features_for_drawing {
### Converts full objects into simple data structures that can be used by the drawing code
  my ($self, $types) = @_;
  my $drawable_features = {};
  my $stored_features = $self->{'_objects'}{'Feature'}[0];

  while (my ($type, $domain_object) = each(%$stored_features)) {
    next unless $domain_object;
    my $parameters = $domain_object->convert_to_drawing_parameters;
    $drawable_features->{$type} = $parameters;
  }
  return $drawable_features;
}


1;

