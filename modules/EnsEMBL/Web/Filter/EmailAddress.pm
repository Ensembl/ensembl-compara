package EnsEMBL::Web::Filter::EmailAddress;

use strict;
use warnings;
use Class::Std;

use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Filter);

### Checks if an email address adheres to a valid format (no bogus characters!)

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'empty' => 'Please supply an email address',
    'invalid_email' => 'Sorry, the email address you entered was not valid. Please try again.',
  });
}

sub catch {
  my $self = shift;
  my $email = $self->object->param('email');
  if (!$email) {
    $self->set_error_code('empty');
  }
  elsif ($email !~ /^[^@]+@[^@.:]+[:.][^@]+$/) { 
    $self->set_error_code('invalid_email');
  }
}

}

1;
