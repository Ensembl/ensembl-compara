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

package EnsEMBL::Web::Utils::MethodMaker;

### Module contains helpful methods to dynamically add, copy methods in a class

### @usage 1
### package EnsEMBL::Module
### use EnsEMBL::Web::Utils::MethodMaker (copy => {'new' => '_new'})
### # This makes a copy of 'new' method as '_new'

### @usage 2
### package Example;
### use EnsEMBL::Web::Utils::MethodMaker qw(copy_method add_method)
### # This imports methods 'copy_method' and 'add_method' to the calling package

use strict;

my @SUBS_OK = qw(add_method copy_method);
my @KEYS_OK = qw(copy add);

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
      my $function  = "${arg}_method";
      $function->($caller, @arguments);
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

1;
