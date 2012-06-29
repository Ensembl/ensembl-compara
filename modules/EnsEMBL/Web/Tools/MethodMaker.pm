package EnsEMBL::Web::Tools::MethodMaker;

### Module contains helpful methods to dynamically add, copy methods in a class
### and methods to dynamically create accessor/mutator methods for any given keys in the object

### @usage 1
### package Person;
### use EnsEMBL::Web::Tools::MethodMaker (get => ['name', 'age'], 'get_set' => ['phonenumber', 'address'])
### # This will create methods 'get_name', 'get_age' for getting name and age respectively, and methods 'phonenumber', 'address' for getting or setting phonenumber, address respectively.

### @usage 2
### package EnsEMBL::Module
### use EnsEMBL::Web::Tools::MethodMaker (copy => ['new', '_new'])
### # This renames the new method to _new - useful for plugins

use strict;

my @SUBS_OK = qw(add_method copy_method create_get_method create_set_method create_get_set_method);
my @KEYS_OK = qw(get set get_set copy add);

sub import {
  ## Imports/creates the required methods to the calling class
  ## @params  Either list of methods in @SUBS_OK
  ##          OR hash with keys as in @KEYS_OK and values as arrayref of arguments as accepted by respective methods
  my $class  = shift;
  my $caller = caller;

  my (@keys, @subs);

  no strict qw(refs);

  while (@_) {
    my $arg = shift @_;
    if (grep {$_ eq $arg} @SUBS_OK) {
      *{"${caller}::${arg}"} = \&{"${class}::${arg}"};

    } elsif (grep {$_ eq $arg} @KEYS_OK) {
      my $arguments = shift;
      warn sprintf('Values to key %s must be an arrayref while importing %s', $arg,  __PACKAGE__) unless $arguments && ref $arguments eq 'ARRAY';
      if ($arg =~ /^(copy|add)$/) {
        my $function = "${arg}_method";
        $function->($caller, @$arguments);
      } else {
        _create_method($caller, $arg, @$arguments);
      }
    }
  }
}

sub copy_method {
  ## Copies one method to another in a given class
  ## @param Class name/Object that contains the method
  ## @param Name of the method to be copied
  ## @param Name of new method
  ## Multiple methods can be copied by providing a list of old method and new method in series
  my $class = shift;
     $class = ref $class if ref $class;

  while (@_) {
    my ($old_method, $new_method) = splice @_, 0, 2;
    no strict qw(refs);
    *{"${class}::${new_method}"} = \&{"${class}::${old_method}"};
  }
}

sub add_method {
  ## Create a new method in the given class
  ## @param Class name/Object
  ## @param Method name
  ## @param subroutine code
  ## Multiple methods can be added by providing a list of method name and subroutine code in series
  my $class = shift;
     $class = ref $class if ref $class;

  while (@_) {
    my ($method_name, $method) = splice @_, 0, 2;
    no strict qw(refs);
    *{"${class}::${method_name}"} = $method;
  }
}

sub create_get_method               { _create_method('get',     @_); } ## @method ## Creates getter methods for given key names ## Creates method with name 'get_property' if property is the key
sub create_set_method               { _create_method('set',     @_); } ## @method ## Creates setter methods for given key names ## Creates method with name 'set_property' if property is the key
sub create_get_set_method           { _create_method('get_set', @_); } ## @method ## Creates getter and setter methods for given key names  ## Creates both 'get_property' and 'set_property' for a property key 

sub _create_method {
  my ($type, $class) = splice @_, 0, 2;
  $class = ref $class if ref $class;

  no strict qw(refs);
  foreach my $property (@_) {
    if ($type eq 'get_set') {
      *{"${class}::${property}"} = sub {
        my $object = shift;
        $object->{"_$property"} = shift if @_;
        return $object->{"_$property"};
      }
    } elsif ($type eq 'get') {
      *{"${class}::get_${property}"} = sub {
        return shift->{"_$property"};
      }
    } elsif ($type eq 'set') {
      *{"${class}::set_${property}"} = sub {
        my $object = shift;
        $object->{"_$property"} = shift;
        return $object->{"_$property"};
      }
    }
  }
}

1;