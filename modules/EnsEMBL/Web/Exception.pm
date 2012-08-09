package EnsEMBL::Web::Exception;

### Name: EnsEMBL::Web::Exception

### Description:
### Exception object with type, message, stack trace and some optional extra data saved inside the blessed hash
### If used as a string, returns all information about the Exception object in formatted string
### Used along with EnsEMBL::Web::Exceptions module to throw and catch exceptions
### This class can be inherited, but is recommended only if the handle method needs to be overridden

### In Ideal conditions:
### Every exceptions thrown should have a message and at least one type tag specified
### Type should literally tell about the type of the exception eg. DOMException is a type of exception thrown in EnsEMBL::Web::DOM code
### Message should be informative message that can either be displayed on user screen, or saved in logs (depending upon how it's handled in catch statement)


use strict;
use warnings;

use overload qw("" to_string);

use HTML::Entities qw(encode_entities);

sub handle {
  ## Handles the exception in a desired way
  ## Override this in the child class to provide better exception handling
  ## @return Boolean true if exception handled successfully, false otherwise
  return warn shift->to_string;
}

sub type {
  ## Gets the type tags of the Exception
  ## @return Arrayref
  return shift->{'_type'};
}

sub isa {
  ## Checks whether the exception belongs to a given type (ie. it contains the given type tag)
  ## @param Type (or class) to be checked against
  ## @return True if the exception object contains the given type tag or if it is inherited from the given class, false otherwise
  my ($self, $type) = @_;
  $type eq $_ and return 1 for @{$self->tags};
  return $self->SUPER::isa($type);
}

sub message {
  ## Gets the message passed in the exception object
  ## @param Flag if on will return the message without any encoding (use if message not being displayed) - Off by default
  ## @return Message string
  my $message = shift->{'_message'};
  return shift @_ ? $message : encode_entities($message);
}

sub data {
  ## Gets the data saved with the Exception
  ## @return whatever was saved in the 'data' key
  return shift->{'_data'};
}

sub stack_trace_array {
  ## Gets the stack trace for the exception
  ## @return Array of arrays
  return shift->{'_stack'};
}

sub stack_trace {
  ## Gets string representation of stack trace for printing purposes
  ## @return String stack trace
  my $stack = shift->stack_trace_array;
  return join "\n", map sprintf('%s by %5$s in module %s at %s on line %s', ($_ ? '  Called' : 'Thrown'), @{$stack->[$_]}), 0..scalar @$stack - 1;
}

sub to_string {
  ## Converts the Exception object into a human-readable string
  my $self = shift;
  return sprintf("Uncaught exception '%s' with message '%s'\n  %s", $self->{'_type'}, $self->{'_message'}, $self->stack_trace);
}

sub _new {
  ## @private
  ## @constructor
  ## Creates a new exception object
  ## Use 'throw exception' syntax provided by EnsEMBL::Web::Exceptions instead of this method
  my ($class, $params) = @_;

  $params = {'message' => $params} unless ref $params;

  # build and save stack trace
  my $i = 0;
  my $stack = [];
  while (my @caller = caller($i++)) { ## TODO - check rules followed by carp croak
    next if $caller[0] eq 'EnsEMBL::Web::Exceptions' || $caller[3] =~ /^EnsEMBL::Web::Exceptions::/;
    push @$stack, [splice @caller, 0, 4];
  }

  return bless {
    '_type'    => $params->{'type'} ? ref $params->{'type'} ? $params->{'type'} : [ $params->{'type'} ] : ['UnknownException'],
    '_message' => $params->{'message'}  || '',
    '_data'    => $params->{'data'}     || undef,
    '_stack'   => $stack
  }, $class;
}

1;