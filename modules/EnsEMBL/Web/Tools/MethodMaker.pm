package EnsEMBL::Web::Tools::MethodMaker;

use strict;

my @SUBS_OK = qw(create_get_method create_set_method create_get_set_method create_accessor_method copy_method add_method);
my @KEYS_OK = qw(get set get_set copy add);

sub import {
  ## Imports the to the caller and creates methods if provided in the arguments
  ## @params Either list of methods in @SUBS_OK or hash with key as one in @KEYS_OK, and value as arrayref of arguments as accepted by respective methods
  my $class  = shift;
  my $caller = caller;

  my (@keys, @subs);

  while (@_) {
    my $arg = shift @_;
    if (grep {$_ eq $arg} @SUBS_OK) {
      no strict qw(refs);
      *{"${caller}::${arg}"} = \&{"${class}::${arg}"};

    } elsif (grep {$_ eq $arg} @KEYS_OK) {
      my $arguments = shift;
      warn sprintf('Values to key %s must be an arrayref while importing %s', $arg,  __PACKAGE__) unless $arguments && ref $arguments eq 'ARRAY';
      if ($arg =~ /^(copy|add)$/) {
        my $function = "${arg}_method";
        $function->(@$arguments);
      } else {
        _create_method(caller[0], $arg, @$arguments);
      }
    }
  }
}

sub copy_method {
  ## Copies one method to another
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
  ## Create a new method
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

sub create_get_method               { _create_method('get',           @_); } ## @method ## Creates getter methods for given key names ## Creates method with name 'get_property' if property is the key
sub create_set_method               { _create_method('set',           @_); } ## @method ## Creates setter methods for given key names ## Creates method with name 'set_property' if property is the key
sub create_get_set_method           { _create_method('get_set',       @_); } ## @method ## Creates getter and setter methods for given key names  ## Creates both 'get_property' and 'set_property' for a property key 
sub create_accessor_method          { _create_method('access',        @_); } ## @method ## Creates accessor method for given key names ## Creates method same as key name ## Acts as setter if value provided, getter otherwise
sub create_mutator_method           { _create_method('mutate',        @_); } ## @method ## Creates accessor method for given key names ## Creates method same as key name ## Acts as setter if value provided, getter otherwise
sub create_accessor_mutator_method  { _create_method('access_mutate', @_); } ## @method ## Creates accessor method for given key names ## Creates method same as key name ## Acts as setter if value provided, getter otherwise

sub _create_method {
  my ($type, $class) = splice @_, 0, 2;
  $class = ref $class if ref $class;

  no strict qw(refs);
  foreach my $property (@_) {
    if ($type eq 'access') {
      *{"${class}::${property}"} = sub {
        my $object = shift;
        $object->{"_$property"} = shift if @_;
        return $object->{"_$property"};
      }
    } elsif ($type =~ /^get/) {
      *{"${class}::get_${property}"} = sub {
        return shift->{"_$property"};
      }
    } elsif ($type =~ /set$/) {
      *{"${class}::set_${property}"} = sub {
        my $object = shift;
        $object->{"_$property"} = shift;
        return $object->{"_$property"};
      }
    }
  }
}

1;