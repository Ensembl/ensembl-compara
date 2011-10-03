package EnsEMBL::Web::Exception;

### Name:EnsEMBL::Web::Exception

### Description:
### Exception object with type, code, message and stack trace saved inside the blessed hash
### If used as a string, returns all information about the Exception object in formatted string
### Used along with EnsEMBL::Web::Exceptions module to throw and catch exceptions

### In Ideal conditions:
### Every exceptions thrown should have a type (disguised as namespace), a (unique) code and a message
### Code should be unique for every exception so that while 'catch'ing them, exception can be checked for specific code
### Type should literally tell about the type of the exception eg. DOMException is a type of exception thrown in EnsEMBL::Web::DOM code ('catch'ing can be done wrt exception type also)
### Message should be informative message that can either be displayed on user screen, or saved in logs (depending upon how it's handled in catch statement)

### NB. This class is (yet) not designed to be inherited. As a compensation, 'isa_type' method acts as a disguised 'isa' method by checking 'type' attribute's "namespace"
### eg. Any exception of type "URLException::InvalidSpeciesException" returns true for both isa_type('URLException') and isa_type('URLException::InvalidSpeciesException')

use strict;
use warnings;

use overload qw("" to_string);

use HTML::Entities qw(encode_entities);

sub type {
  ## Gets the type of the Exception
  ## @return Type string
  return shift->{'_type'};
}

sub isa_type {
  ## Checks whether the exception belongs to a given type
  ## @param Type to be checked against
  my ($self, $type) = @_;
  return "$self->{'_type'}::" =~ /^$type\:\:/;
}

sub code {
  ## Gets the code of the Exception
  ## @return Code string
  return shift->{'_code'};
}

sub message {
  ## Gets the message passed in the exception object
  ## @param Flag if on will return the message without any encoding (use if message not being displayed) - Off by default
  ## @return Message string
  my $message = shift->{'_message'};
  return shift @_ ? $message : encode_entities($message);
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
  return join "\n", map {sprintf('%s by %5$s in module %s at %s on line %s', ($_ ? '  Called' : 'Thrown'), @{$stack->[$_]})} 0..scalar @$stack - 1;
}

sub to_string {
  ## Converts the Exception object into a human-readable string
  my $self = shift;
  return sprintf("Uncaught exception '%s:%s' with message '%s'\n  %s", $self->{'_type'}, $self->{'_code'}, $self->{'_message'}, $self->stack_trace);
}

sub _new {
  ## @constructor
  ## Creates a new exception object
  ## Use EnsEMBL::Web::Exceptions::exception instead of this method
  my ($class, $params) = @_;

  $params = {'message' => $params} unless ref $params;

  # build and save stack trace
  my $i = 0;
  my $stack = [];
  while (my @caller = caller($i++)) {
    next if $caller[0] eq 'EnsEMBL::Web::Exceptions' || $caller[3] =~ /^EnsEMBL::Web::Exceptions::/ || !--$params->{'ignore'};
    push @$stack, [splice @caller, 0, 4];
  }

  return bless {
    '_type'    => $params->{'type'}     || 'UnknownException',
    '_code'    => $params->{'code'}     || '',
    '_message' => $params->{'message'}  || '',
    '_stack'   => $stack
  }, $class;
}

1;