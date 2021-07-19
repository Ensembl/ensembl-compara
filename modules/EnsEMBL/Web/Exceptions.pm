=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

### Module gives Exceptions based error handling features using try, catch, throw and exception keywords
### Check example at the bottom of the file

### Things to be aware of while using:
### 'return' inside the try or catch blocks behaves as a 'break' to the code block but does not return from the wrapping function/method

use strict;
use warnings;

use EnsEMBL::Web::Exception;

my @EXPORT          = qw(try catch throw exception);
my $EXCEPTION_BASE  = qq(EnsEMBL::Web::Exception);
my %EXCEPTION_CLASS;

sub import {
  ## Imports the functions try, catch, throw & exception to the caller and registers any exceptions if provided in the arguments
  ## @params List of exception type to allow their usage in the calling package with arguments as excepted by the exception method below
  my $class  = shift;
  my $caller = caller;

  {
    no strict qw(refs);

    # register exceptions
    foreach my $exception_name (@_) {

      *{"${caller}::${exception_name}"} = sub { return exception($exception_name, @_); };

      $EXCEPTION_CLASS{$exception_name} ||= _get_exception_class($exception_name);
    }

    # import functions
    *{"${caller}::${_}"} = \&{"${class}::${_}"} for @EXPORT;
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
  ## @param (String) Exception type
  ## @param (String) Exception message or Exception object
  ## @param (Mixed) Any data that needs to be passed to the code that will eventually handle this exception
  my ($type, $message, $data) = @_;

  # if second argument is the exception object already
  if (UNIVERSAL::isa($message, $EXCEPTION_BASE)) {
    $message->type($type);
    $message->data($data) if defined $data;
    return $message;
  }

  # if data is provided as second argument with no message
  ref $message and $data = $message and $message = '';

  # check if the exception class exists but is not cached yet
  $EXCEPTION_CLASS{$type} ||= _get_exception_class($type);

  return $EXCEPTION_CLASS{$type}->new({'type' => $type, 'message' => $message, 'data' => $data});
}

sub _get_exception_class {
  ## @private
  ## Returns the exception class if it exists, otherwise returns the base class (EnsEMBL::Web::Exception)
  ## eg. for ORMException, it would return EnsEMBL::Web::Exception::ORMException because this package exists
  my $name  = shift;
  my $class = "${EXCEPTION_BASE}::${name}";

  eval "require $class";

  $class  = $EXCEPTION_BASE if $@;
  $@      = undef;

  return $class;
}

1;

### Example:
### 
### package EnsEMBL::Web::XYZ;
### 
### use strict;
### 
### use EnsEMBL::Web::Exceptions qw(IllegalArgumentException);
### 
### sub get_rows_per_page {
###   my ($self, $row_count, $page_count) = @_;
###   my $output;
###   try {
###     $output = $self->divide($row_count, $page_count);
###   }
###   catch {
###     if ($_->isa('DivisionByZero')) { #catch DivisionByZero exception
###       $output = $row_count;
###     }
###     else {
###       throw $_; # rethrow IllegalArgumentException
###     }
###   }; # don't miss this semi-colon
###   return $output;
### }
### 
### sub divide {
###   my ($self, $a, $b) = @_;
###   if ($a !~ /^[0-9]+$/ || $b !~ /^[0-9]+$/) {
###     throw IllegalArgumentException;
###     # or throw IllegalArgumentException('Invalid arguments provided');
###   }
###   if ($b == 0) {
###     throw exception('DivisionByZero', 'Division by zero');
###   }
###   return $a / $b;
### }
