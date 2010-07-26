# $Id$

package EnsEMBL::Web::Model;

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
  
  my $object_params = [
    [ 'Location',   'r'   ],
    [ 'Gene',       'g'   ],
    [ 'Transcript', 't'   ],
    [ 'Variation',  'v'   ],
    [ 'Regulation', 'rf'  ],
    [ 'Marker',     'm'   ],
    [ 'LRG',        'lrg' ],
  ];
    
  my $self = { 
    _objects         => {},
    _object_params   => $object_params,
    _object_types    => { map { $_->[0] => $_->[1] } @$object_params },
    _ordered_objects => [ map $_->[0], @$object_params ]
  };
  
  $self->{'_hub'} = new EnsEMBL::Web::Hub(
    _apache_handle => $args->{'_apache_handle'},
    _input         => $args->{'_input'},
    _object_types  => $self->{'_object_types'}
  );
   
  bless $self, $class;
  
  return $self; 
}

sub hub              { return $_[0]{'_hub'};             }
sub all_objects      { return $_[0]{'_objects'};         }
sub object_params    { return $_[0]{'_object_params'};   }
sub object_types     { return $_[0]{'_object_types'};    }
sub ordered_objects  { return $_[0]{'_ordered_objects'}; }

sub object {
  ### Getter/setter for data objects - acts on the default data type
  ### for this page if none is specified
  ### Returns the first object in the array of the appropriate type
  
  my ($self, $type, $object) = @_;
  my $hub = $self->hub;
  $type ||= $hub->type;
  
  $self->{'_objects'}{$type} = $object if $object;
  
  my $object_type = $self->{'_objects'}{$type};
  $object_type  ||= $self->{'_objects'}{$hub->factorytype} unless $_[1];
  
  return $object_type;
}

sub api_object {
  ### Returns the underlying API object(s)
  
  my ($self, $type) = @_;
  my $object = $self->object($type);
  return $object->__objecttype eq 'Location' ? $object->slice : $object->Obj if $object;
}

sub create_objects {
  ### Used to generate the objects needed for the top tabs and the rest of the page
  ### The object of type $type is the primary object, used for the page.
  
  my ($self, $type, $request) = @_;
  
  my $hub   = $self->hub;
  my $url   = $hub->url($hub->multi_params);
  my $input = $hub->input;
  $type   ||= $hub->factorytype;
  
  my ($factory, $new_factory, $data);
  
  if ($request eq 'lazy') {
    $factory = $self->create_factory($type) unless $self->object($type);
    return $self->object($type);
  }
  
  if ($self->object_types->{$type} && $input->param('r')) {
    $factory = $self->create_factory('Location');
    $data    = $factory->__data;
  }
  
  $new_factory = $self->create_factory($type, $data) unless $type eq 'Location' && $factory; # If it's a Location page with an r parameter, don't duplicate the Location factory
  $factory     = $new_factory if $new_factory;
  
  foreach (@{$self->object_params}) {
    last if $hub->get_problem_type('redirect');                    # Don't continue if a redirect has been requested
    next if $_->[0] eq $type;                                      # This factory already exists, so skip it
    next unless $input->param($_->[1]) && !$self->object($_->[0]); # This parameter doesn't exist in the URL, or the object has already been created, so skip it
    
    $new_factory = $self->create_factory($_->[0], $factory->__data) || undef;
    $factory     = $new_factory if $new_factory;
  }
  
  $hub->clear_problem_type('fatal') if $type eq 'MultipleLocation' && $self->object('Location');
  
  if ($request eq 'page') {
    my ($redirect) = $hub->get_problem_type('redirect');
    my $new_url;
    
    if ($redirect) {
      $new_url = $redirect->name;
    } elsif (!$hub->has_fatal_problem) { # If there's a fatal problem, we want to show it, not redirect
      $hub->_set_core_params;
      $new_url = $hub->url($hub->multi_params);
    }
    
    if ($new_url && $new_url ne $url) {
      $hub->redirect($new_url);
      return 'redirect';
    }
  }
}

sub create_factory {
  ### Creates a Factory object which can then generate one or more 
  ### domain objects
  
  my ($self, $type, $data) = @_;
  
  return unless $type;
  
  my $hub = $self->hub;
  
  $data ||= {
    _hub           => $hub,
    _input         => $hub->input,
    _apache_handle => $hub->apache_handle,
    _databases     => $hub->databases,
    _parent        => $hub->parent
  };
  
  my $factory = $self->new_factory($type, $data);
  
  if ($factory) {
    $factory->createObjects;
    
    $self->object($_->__objecttype, $_) for @{$factory->DataObjects};
    
    return $factory;
  }
}

sub create_data_object_of_type {
  my ($self, $type, $args) = @_;
  
  my $class = "EnsEMBL::Web::Data::$type";
  my $object;
  
  if ($self->dynamic_use($class)) {
    $object = $class->new($self->hub, $args);
    $self->object($object->type, $object) if $object;
  }
}

1;
