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
    '_objects'  => {}, 
    '_tabs'     => [],
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

sub objects {
### Getter/setter for domain objects - acts on the default data type 
### for this page if none is specified
### Returns an arrayref of objects of the appropriate type
  my ($self, $type, $objects) = @_;
  $type ||= $self->type;
  if ($objects) {
    my $m = $self->{'_objects'}{$type} || [];
    my @a = ref($objects) eq 'ARRAY' ? @$objects : ($objects); 
    push @$m, @a;
    $self->{'_objects'}{$type} = $m;
  } 
  return $self->{'_objects'}{$type};
}

sub object {
### Getter/setter for data objects - acts on the default data type 
### for this page if none is specified
### Returns a single object, or undef if there is more than one 
  my ($self, $type, $object) = @_;
  $type ||= $self->hub->type;
  if ($object) {
    my $m = $self->{'_objects'}{$type} || [];
    push @$m, $object; 
    $self->{'_objects'}{$type} = $m;
  }
  if ($self->{'_objects'}{$type} && scalar @{$self->{'_objects'}{$type}} == 1) {
    return $self->{'_objects'}{$type}[0];
  }
}

sub raw_object {
### returns the underlying object (mainly for API objects)
  my ($self, $type) = @_;
  my $object = $self->{'_objects'}{$type}[0];
  return unless $object;
  if ($type eq 'Location') {
    return $object->slice;
  }
  else {
    return $object->Obj;
  }
}

sub add_objects {
### Adds domain objects created by the factory to this Model
  my ($self, $type, $data) = @_;
  return unless $data;
  #warn ">>> DATA $data";

  ### Proxy Object(s)
  if (ref($data) eq 'ARRAY') {
    foreach my $element (@$data) {
      #warn ">>> ELEMENT $element";
      if (ref($element) eq 'HASH') {
      ## "FEATUREVIEW"
        while (my ($key, $array) = each (%$element)) {
          #warn ">>> KEY $key = $array";
          foreach (@$array) {
            #warn "... ".$_->Obj;
            $self->object($key, $_);
          }
        }
      }
      else {
        $self->object($type, $element);
      }
    }
  }
  ### Other object type
  elsif (ref($data) eq 'HASH') {
    while (my ($key, $object) = each (%$data)) {
      if (ref($object) eq 'ARRAY') {
        foreach (@$object) {
          $self->object($key, $_);
        }
      }
      else {
        $self->object($key, $object);
      }
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
        warn "!!! OBJECT $type ".$problem->[0]->description;
      } 
      else {
        $self->add_objects($type, $factory->DataObjects);
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

  my $location     = $self->raw_object('Location');
  my $gene         = $self->raw_object('Gene');
  my $transcript   = $self->raw_object('Transcript');
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

  unless ($types) {
    my @keys = keys %{$self->{'_objects'}};
    foreach (@keys) {
      push @$types, $_ unless $_ eq 'Location';
    }
  }

  foreach my $type (@$types) {
    my $objects = $self->objects($type);
    my $features = [];
    next unless $objects && @$objects;
    foreach my $object (@$objects) {
      next unless $object;
      my ($f, $columns) = $object->convert_to_drawing_parameters;
      push @{$features->[0]}, $f;
      $features->[1] = $columns;
    }
    $drawable_features->{$type} = $features;
  }
  return $drawable_features;
}

1;

