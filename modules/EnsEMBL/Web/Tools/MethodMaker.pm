package EnsEMBL::Web::Tools::MethodMaker;

### Module contains helpful methods to dynamically add, copy methods in a class
### and methods to dynamically create accessor/mutator methods for any given keys in the object

### @usage 1
### package Person;
### use EnsEMBL::Web::Tools::MethodMaker (get => ['name', 'age'], 'get_set' => ['phonenumber', 'address'])
### # This will create methods 'get_name', 'get_age' for getting name and age respectively, and methods 'phonenumber', 'address' for getting or setting phonenumber, address respectively.

### @usage 2
### package EnsEMBL::Module
### use EnsEMBL::Web::Tools::MethodMaker (copy => {'new' => '_new'})
### # This makes a copy of 'new' method to '_new' - useful for plugins if you need to modify the 'new' method

### @usage 3
### package Example;
### use EnsEMBL::Web::Tools::MethodMaker qw(copy_method add_method)
### # This imports methods 'copy_method' and 'add_method' to the calling package

use strict;

my @SUBS_OK = qw(add_method copy_method create_get_method create_set_method create_get_set_method);
my @KEYS_OK = qw(get set get_set copy add);

sub import {
  ## Imports/creates the required methods to the calling class
  ## @params  Either list of methods in @SUBS_OK
  ##          OR hash with keys as in @KEYS_OK and values as arrayref of arguments as accepted by respective methods
  my $class  = shift;
  my $caller = caller;

  no strict qw(refs);

  while (@_) {
    my $arg = shift @_;
    if (grep {$_ eq $arg} @SUBS_OK) {
      *{"${caller}::${arg}"} = \&{"${class}::${arg}"};

    } elsif (grep {$_ eq $arg} @KEYS_OK) {
      my $arguments = shift;
      my @arguments = ref $arguments ? ref $arguments eq 'HASH' ? %$arguments : @$arguments : $arguments;
      if ($arg =~ /^(copy|add)$/) {
        my $function = "${arg}_method";
        $function->($caller, @arguments);
      } else {
        _create_method($caller, $arg, @arguments);
      }
    }
  }
}

# From Class::ISA by Sean Burke
# (C) 1999-2009 Sean Burke, distributed under terms of Perl itself
# Avoid introducing dependency mid release for a bug-fix, but better would
# be installing Class::ISA.

sub self_and_super_path {
  # Assumption: searching is depth-first.
  # Assumption: '' (empty string) can't be a class package name.
  # Note: 'UNIVERSAL' is not given any special treatment.
  return () unless @_;

  my @out = ();

  my @in_stack = ($_[0]);
  my %seen = ($_[0] => 1);

  my $current;
  while(@in_stack) {
    next unless defined($current = shift @in_stack) && length($current);
    #print "At $current\n" if $Debug;
    push @out, $current;
    no strict 'refs';
    next unless *{${"$current\::"}{"ISA"}}{ARRAY};
    unshift @in_stack,
      map
        { my $c = $_; # copy, to avoid being destructive
          substr($c,0,2) = "main::" if substr($c,0,2) eq '::';
           # Canonize the :: -> main::, ::foo -> main::foo thing.
           # Should I ever canonize the Foo'Bar = Foo::Bar thing? 
          $seen{$c}++ ? () : $c;
        }
        @{"$current\::ISA"}
    ;
    # I.e., if this class has any parents (at least, ones I've never seen
    # before), push them, in order, onto the stack of classes I need to
    # explore.
  }

  return @out;
}

sub _sub_exists {
  my ($class,$method) = @_;

  no strict;
  return (defined *{${$class."::"}{$method}}{CODE});
}

sub _find_sub_in_self_or_super {
  my ($class,$method) = @_;

  foreach my $k (self_and_super_path($class)) {
    return $k if _sub_exists($k,$method);
  }
  return undef;
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

    next unless $class->can($old_method) xor $class->can($new_method); # ignore if both methods exist, or none of them exists
    # Maybe the old method was defiend in a supertype?
    my $old_class = _find_sub_in_self_or_super($class,$old_method);
    next unless defined $old_class;   

    # ignore if both methods exist, or none of them exists
    next unless _sub_exists($old_class,$old_method) xor _sub_exists($class,$new_method);

    no strict qw(refs);
    *{"${class}::${new_method}"} = \&{"${old_class}::${old_method}"};
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

sub create_get_method {
  ## Creates getter methods for given key names - 'get_<key name>'
  ## @params List of property names for which methods are to be added
  _create_method('get', @_);
}

sub create_set_method {
  ## Creates setter methods for given key names - 'set_<key name>'
  ## @params List of property names for which methods are to be added
  _create_method('set', @_);
}

sub create_get_set_method {
  ## Creates getter/setter methods for given key names - method name same as the key name
  ## @params List of property names for which methods are to be added
  _create_method('get_set', @_);
}

sub _create_method {
  ## @private
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
