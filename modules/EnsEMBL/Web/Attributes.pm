=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Attributes;

### Attributes for modifying default behaviour of subroutines
### For any attribute added to a subroutine, the corresponding method from this package gets called with following arguments:
###  - The package that contains the actual method
###  - Coderef to the actual method
###  - GLOB for the actual method
###  - Actual method's name
###  - plus list of arguments as provided to the Attribute

use strict;
use warnings;
no warnings 'redefine';

use EnsEMBL::Web::Exceptions;

sub AccessorMutator {
  ## Attribute to declare a method that can act as an accessor and a mutator (read and write)
  ## @param Key name to access or mutate the value (defaults to the method name)
  my ($package, $code, $glob, $method, $key) = @_;
  *{$glob} = sub {
    my $object  = shift;
    $object->{$key // $method} = shift if @_;
    return $object->{$key // $method};
  }
}

sub Accessor {
  ## Attribute to declare a accessor method (readonly)
  ## @param Key name to get value for (defaults to the method name)
  my ($package, $code, $glob, $method, $key) = @_;
  *{$glob} = sub {
    my $object = shift;
    return $object->{$key // $method};
  }
}

sub Abstract {
  ## Attribute to declare an abstract method
  ## This will modify the subroutine to throw an exception if an accidental call is made to this method
  my ($package, $code, $glob, $method) = @_;
  *{$glob} = sub {
    my $ex = exception('AbstractMethodNotImplemented', "Abstract method '$method' called.");
    $ex->stack_trace_array->[0][3] = "${package}::${method}"; # replace EnsEMBL::Web::Attributes::__ANON__ with the actual method that was called
    throw $ex;
  };
}

sub Cacheable {
  ## Attribute to declare a method that should cache its output in a key and return the cached value in further calls
  ## @param Key name where the cached return value should be saved (defaults to method name)
  my ($package, $code, $glob, $method, $key) = @_;
  *{$glob} = sub {
    my $object = shift;
    $object->{$key // $method} = $code->($object, @_) unless exists $object->{$key // $method};
    return $object->{$key // $method};
  };
}

sub Deprecated {
  ## Attribute to declare a method to have been deprecated
  ## It modifies the code to print a warning to stderr before calling the actual method
  ## @param Message that needs to be printed as deprecated warning (optional - defaults to a simple message)
  my ($package, $code, $glob, $method, $message) = @_;
  *{$glob} = sub {
    my @caller = caller(0);
#    warn sprintf "Call to deprecated method %s::%s: %s at %s:%s\n", $package, $method, $message || '', $caller[1], $caller[2];
    goto &$code;
  };
}

#############################################
# Do not change anything after this comment #
#############################################

use Exporter qw(import);
our @EXPORT = qw(MODIFY_CODE_ATTRIBUTES);

sub MODIFY_CODE_ATTRIBUTES {
  ## This method gets injected into the caller's namespace and is the actual method that is called by perl attributes package
  ## Currently only one attribute is supported (although this method receives list of all attributes)
  my ($package, $code, $attr) = @_;

  # parse any arguments provided to the attribute
  $attr     =~ /^([^\(]+)(\((.+)\))?$/s;
  $attr     = $1;
  my @args  = defined $2 ? eval($2) : ();

  die("Invalid attribute arguments: $3\n") if $@;

  if (my $coderef = __PACKAGE__->can($attr)) {
    $coderef->($package, $code, $_, *{$_} =~ s/.+\:\://r, @args) for _findsym($package, $code);
    return;
  }

  # non-undef return value means the attribute is invalid
  return $attr;
}

sub _findsym {
  my ($package, $ref) = @_;

  no strict 'refs';
  my $type = ref($ref);
  foreach my $sym (values %{$package."::"}) {
    next unless ref(\$sym) eq 'GLOB';
    return \$sym if *{$sym}{$type} && *{$sym}{$type} == $ref;
  }
}

1;
