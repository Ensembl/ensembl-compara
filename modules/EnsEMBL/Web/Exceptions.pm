=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Exceptions;

### Name: EnsEMBL::Web::Exceptions

### Status: Under development

### Description:
### Module gives Exceptions based error handling features using try, catch, throw and exception keywords
### Check example at the bottom of the file

### Things to be aware of while using:
### 'return' inside the try or catch blocks behaves as a 'break' to the code block but does not return from the wrapping function/method

### TODO
### Add commonly used exceptions in EXCEPTION_LIST and make them useable as in the following syntax
### "throw IllegalArgumentException" which means same as "throw exception('IllegalArgumentException', '.. some message')"


use strict;
use warnings;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Exception;

my @EXPORT          = qw(try catch throw exception);
my $EXCEPTION_BASE  = qq(EnsEMBL::Web::Exception);
my %EXCEPTION_LIST  = ();

sub import {
  ## Imports the functions try, catch, throw & exception to the caller and registers any exceptions if provided in the arguments
  ## @param List (hash) with key as a short string (exception is saved against this in the %EXCEPTION_LIST) and value as array/hash as arguments accepted by &exception function
  my $class  = shift;
  my $caller = caller;

  {
    # import functions
    no strict qw(refs);
    *{"${caller}::${_}"} = \&{"${class}::${_}"} for @EXPORT;
  }

  # register exceptions
  while (@_) {
    my ($key, $exception) = splice @_, 0, 2;
    $EXCEPTION_LIST{$caller}{$key} = ref $exception ? ref $exception eq 'ARRAY' ? $exception : [ map $exception->{$_}, qw(type message) ] : [ '', $exception ] if $key;
  }
}

sub try (&$) {
  ## To be used as typical 'try' keyword
  my ($try, $catch) = @_;
  eval { &$try };
  if ($@) {
    local $_ = ref $@ && UNIVERSAL::isa($@, $EXCEPTION_BASE) ? $@ : $EXCEPTION_BASE->new($@);
    $@ = undef;
    &$catch;
  }
}

sub catch (&) {
  ## To be used as typical 'catch' keyword
  ## $_ for the code inside the catch statement is the caught Exception object
  shift;
}

sub throw {
  ## To be used as typical 'throw' keyword
  ## @param Exception object
  die shift;
}

sub exception {
  ## To be used as an argument to &throw
  ## Creates and returns an Exception object
  ## @param Hashref with keys:
  ##  - type    Exception type
  ##  - message Exception message
  ##  - data    Any extra data to be saved inside the exception object that needs to be retrieved while catching the exception
  ##  OR (String) Unique code that was used for a particular exception while importing this module
  ##  OR (String) Exception type
  ## @param (String) Exception message (only if first argument is a string for exception type)
  ## @param Data (only if first argument is a string for exception type)
  my ($type, $message, $data) = @_;
  if (scalar @_ == 1 && $type) {

    # if it's a Hash - easy job
    if (ref $type eq 'HASH') {
      ($type, $message, $data) = map {$type->{$_}} qw(type message data);
    
    # if not a hash, check for the registered exceptions first
    } else {

      my $caller = caller;

      # if exception registered in the caller class
      if (exists $EXCEPTION_LIST{$caller}{$type}) {
        ($type, $message) = @{$EXCEPTION_LIST{$caller}{$type}};

      # if exception not registered, look up for any exception registered with the same code in caller's parent classes
      } else {
        my %exception_list = %EXCEPTION_LIST;
        for (keys %exception_list) {
          delete $exception_list{$_} unless exists $exception_list{$_}{$type} && $caller->isa($_);
        }
        if (my @ancestor_classes = keys %exception_list) {
          foreach my $ancestor_class (@ancestor_classes) {
            $ancestor_class ne $_ and $ancestor_class->isa($_) and delete $exception_list{$_} for keys %exception_list;
          }
          ($type, $message) = @{$exception_list{$_}{$type}} and last for keys %exception_list;
        } else {
          ($type, $message) = ('', $type);
        }
      }
    }
  }

  my $exception_class = $EXCEPTION_BASE;
     $exception_class = EnsEMBL::Web::Root->dynamic_use_fallback(reverse map {$exception_class = "$exception_class$_"} '', split(/(?=::)/, "::$type"));

  return $exception_class->new({'type' => $type, 'message' => $message, 'data' => $data});
}

1;

### Example:
### 
### package EnsEMBL::Web::XYZ;
### 
### use strict;
### 
### use EnsEMBL::Web::Exceptions (
###   numberic_arg_exception => ['IllegalArgument', 'Arguments are expected to be numeric']
### );
### 
### sub get_rows_per_page {
###   my ($self, $row_count, $page_count) = @_;
###   my $output;
###   try {
###     $output = $self->divide($row_count, $page_count);
###   }
###   catch {
###     if ($_->type eq 'DivisionByZero') { #catch DivisionByZero exception
###       $output = $row_count;
###     }
###     else {
###       throw; # rethrow IllegalArgument exception
###     }
###   }; # don't miss this semi-colon
###   return $output;
### }
### 
### sub divide {
###   my ($self, $a, $b) = @_;
###   if ($a !~ /^[0-9]+$/ || $b !~ /^[0-9]+$/) {
###     throw exception('numberic_arg_exception');
###   }
###   if ($b == 0) {
###     throw exception('DivisionByZero', 'Division by zero');
###   }
###   return $a / $b;
### }