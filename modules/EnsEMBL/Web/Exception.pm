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

package EnsEMBL::Web::Exception;

### Exception object with type, message, stack trace and some optional extra data saved inside the blessed hash
### If used as a string, returns all information about the Exception object in formatted string
### Use this along with EnsEMBL::Web::Exceptions module to throw and catch exceptions using try catch syntax
### This class can be inherited, but is recommended only if the handle method needs to be overridden

### In Ideal conditions:
### Every exceptions thrown should have a message and at least one type tag specified
### Type should literally tell about the type of the exception eg. DOMException is a type of exception thrown in EnsEMBL::Web::DOM code
### Message should be informative message that can either be displayed on user screen, or saved in logs (depending upon how it's handled in catch statement)

use strict;
use warnings;

use overload qw("" to_string);

use HTML::Entities qw(encode_entities);

sub new {
  ## @constructor
  ## Creates a new exception object
  ## @note Use 'throw exception' syntax provided by EnsEMBL::Web::Exceptions instead of this method to throw an exception
  ## @param Hashref with keys: type, message and data
  my ($class, $params) = @_;

  $params = _normalize_exception_object($params || {});

  # build and save stack trace
  my $i = 0;
  my $stack = [];
  while (my @caller = caller($i++)) {
    next if $caller[0] eq 'EnsEMBL::Web::Exceptions' || $caller[3] =~ /^EnsEMBL::Web::Exceptions::/ || UNIVERSAL::isa($caller[0], __PACKAGE__);
    push @$stack, [splice @caller, 0, 4];
  }

  return bless {
    '_type'    => $params->{'type'}     || 'Unknown',
    '_message' => $params->{'message'}  || '',
    '_data'    => $params->{'data'}     || undef,
    '_stack'   => $stack
  }, $params->{'package'} || $class;
}

sub handle {
  ## Handles the exception in a desired way
  ## Override this in the child class to provide better exception handling
  ## @return Boolean true if exception handled successfully, false otherwise
  my $self = shift;

  warn sprintf "%s Exception:\n  %s  %s", $self->{'_type'}, $self->{'_message'} // 'No message', $self->stack_trace;

  return 0;
}

sub type {
  ## Gets/Sets the type of the Exception
  ## @param String (if setting)
  ## @return String
  my $self = shift;

  $self->{'_type'} = "$_[0]" if @_;

  return $self->{'_type'};
}

sub isa {
  ## Checks whether the exception belongs to a given type
  ## @param Type (or class) to be checked against
  ## @return True if the exception object contains the given type in its type string or if it is inherited from the given class, false otherwise
  my ($self, $type) = @_;
  return 1 if $self->type eq $type;
  return 1 if ref($self) =~ /::$type$/;
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
  ## Gets/Sets the data saved with the Exception
  ## @return whatever was saved in the 'data' key
  my $self = shift;

  $self->{'_data'} = $_[0] if @_;

  return $self->{'_data'};
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

  return sprintf("Uncaught exception '%s' with %smessage%s\n  %s",
    $self->{'_type'},
    $self->{'_message'} ? '' : 'no ',
    $self->{'_message'} ? sprintf(" '%s'", $self->{'_message'}) : '',
    $self->stack_trace
  );
}

sub _normalize_exception_object {
  ## @private
  ## Converts external exceptions caught by try/catch into arguments as excepted by EnsEMBL::Web::Exception->new
  ## @param Object, possible an external exception object
  ## @return Hashref (as excepted by EnsEMBL::Web::Exception->new)
  my $object  = shift;
  my $ref     = ref $object;

  # string only
  if (!$ref) {
    if ($object =~ /\n\-+\s*EXCEPTION\s*\-+\n/) {
      return {
        'type'    => 'APIException',
        'message' => $object
      };
    }

    return {
      'message' => $object
    };
  }

  # standard hash as expected
  if ($ref eq 'HASH') {
    return $object;
  }

  # ORM exceptions
  if (UNIVERSAL::isa($object, 'ORM::EnsEMBL::Utils::Exception')) {
    require EnsEMBL::Web::Exception::ORMException;
    return {
      'type'    => $object->type,
      'message' => $object->message,
      'package' => 'EnsEMBL::Web::Exception::ORMException',
    };
  }

  # any other exception for which we don't have a rule
  warn sprintf q(Recommendation: No rule found to convert exception of type %s to %s. To improve verbosity, add a rule to %2$s::_normalize_exception_object.%s), $ref, __PACKAGE__, "\n";
  return {'message' => "$object"};
}

1;
