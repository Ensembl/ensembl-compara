package EnsEMBL::Web::Exceptions;

### Name: EnsEMBL::Web::Exceptions

### Status: Under development

### Description:
### Module gives Exceptions based error handling features using try, catch, throw and exception keywords

### 'return' inside the try or catch blocks behaves as a 'break' to the code block but does not return
### 'throw' inside catch always throws the exception being caught in the catch block irrespective of any argument to throw

use strict;
use warnings;

use EnsEMBL::Web::Exception;

use Exporter qw(import);

our @EXPORT = qw(try catch throw exception register_exception);
our %EXCEPTION_LIST;

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
  ## @param Exception code - ideally short and alphanumeric only including underscore (OR a Hashref containing keys: 'code', 'type', 'message', 'ignore')
  ## @param Exception type - ideally alphanumeric including colon in camel case - similar to namespace
  ## @param Exception message
  ## @param Flag if on will ignore the immediate method that threw the exception in stack trace (useful for library methods) - defaults to false
  my ($code, $type, $message, $ignore) = @_;
  if (ref $code eq 'HASH') {
    ($code, $type, $message, $ignore) = map {$code->{$_}} qw(code type message ignore);
  }
  else {
    if (scalar @_ == 1) {
      if ($code && exists $EXCEPTION_LIST{$code}) {  # if it's code
        ($type, $message) = @{$EXCEPTION_LIST{$code}};
      }
      else {  # if it's message
        ($message, $code) = @_;
      }
    }
    elsif (scalar @_ == 2) {
      ($type, $message, $code) = @_;
    }
  }
  return EnsEMBL::Web::Exception->_new({'code' => $code, 'type' => $type, 'message' => $message, 'ignore' => $ignore});
}

sub register_exception {
  ## Registers an exception type and message against a code that can be provided as an argument to &exception to throw the exception with same type and message
  ## It is not mandatory to register an exception. Registeration only makes it easy if exception with same code, message and type is thrown multiple times
  ## Optional use only
  ## @param Exception code
  ## @param Exception type
  ## @param Exception message
  my ($code, @params) = @_;
  $EXCEPTION_LIST{$code} = \@params;
}

1;

### Example:
### 
### package EnsEMBL::Web::XYZ;
### 
### use strict;
### 
### use EnsEMBL::Web::Exceptions;
### 
### register_exception('NUMERIC_ARGUMENTS_ONLY', 'IllegalArgument::TypeMismatch', 'Arguments are expected to be numeric');
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
###     throw exception('NUMERIC_ARGUMENTS_ONLY');
###   }
###   if ($b == 0) {
###     throw exception('DBO_DIVIDE', 'DivisionByZero', 'Division by zero');
###   }
###   return $a / $b;
### }