package EnsEMBL::Web::Exceptions;

### Name: EnsEMBL::Web::Exceptions

### Status: Under development

### Description:
### Module gives Exceptions based error handling features using try, catch, throw and exception keywords
### Check example at the bottom of the file

### Things to be aware of while using:
### 'return' inside the try or catch blocks behaves as a 'break' to the code block but does not return from the wrapping function/method
### 'throw' inside catch always throws the exception being caught in the catch block irrespective of any argument to throw

use strict;
use warnings;

use EnsEMBL::Web::Exception;

my %EXCEPTION_LIST;

sub import {
  ## Imports the functions try, catch, throw & exception to the caller and registers any exceptions if provided in the arguments
  ## @param List (hash) with key as a short string (exception is saved against this in the %EXCEPTION_LIST) and value as array/hash as arguments accepted by &exception function
  my $class  = shift;
  my $caller = caller;

  {
    # import functions
    no strict qw(refs);
    *{"${caller}::${_}"} = \&{"${class}::${_}"} for qw(try catch throw exception);
  }

  # register exceptions
  while (@_) {
    my ($key, $exception) = splice @_, 0, 2;
    $EXCEPTION_LIST{"${caller}::${key}"} = [ ref $exception ? ref $exception eq 'ARRAY' ? @$exception : (map $exception->{$_}, qw(type message)) : ($exception, '') ] if $key;
  }
}

sub try (&$) {
  ## To be used as typical 'try' keyword
  my ($try, $catch) = @_;
  eval { &$try };
  if ($@) {
    local $_ = ref $@ && UNIVERSAL::isa($@, 'EnsEMBL::Web::Exception') ? $@ : EnsEMBL::Web::Exception->_new($@);
    local $@ = undef;
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
  ## If one argument is provided, it should be either a registered code or message; if two, they are considered to be type and message - OR preferrably provide hashref to avoid vagueness
  ## @param Hashref with keys:
  ##  - type    Exception type
  ##  - message Exception message
  ##  - data    Any extra data to be saved inside the exception object that needs to be retrieved while catching the exception
  ##  OR (String) Short code that was registered with the module against a particular exception while importing it
  ##  OR (String) Exception type
  ## @param (String) Exception message (only if first argument is a string for exception type)
  my ($type, $message) = @_;
  if (scalar @_ == 1 && $type) {
    if (ref $type eq 'HASH') {
      ($type, $message) = map {$type->{$_}} qw(type message);
    }
    elsif (exists $EXCEPTION_LIST{$type}) {
      ($type, $message) = @{$EXCEPTION_LIST{$type}};
    }
  }
  return EnsEMBL::Web::Exception->_new({'type' => $type, 'message' => $message});
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