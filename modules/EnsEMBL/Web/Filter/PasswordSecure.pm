package EnsEMBL::Web::Filter::PasswordSecure;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Filter);

### Checks if a password is strong enough to satisfy minimum security standards
### Also, expects two copies of the password and checks they are identical

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'insecure' => 'Passwords must be at least 6 characters long and include both letters and numbers.',
    'mismatch' => 'Sorry, your passwords did not match. Please try again.',
  });
}

sub catch {
  my ($self) = @_;
  my $object = $self->object;
  my $password_1 = $object->param('new_password_1');
  my $password_2 = $object->param('new_password_2');

  if ($password_1 eq $password_2) {
    unless (length($password_1) > 5 && $password_1 =~ /[a-zA-Z]+/ && $password_1 =~ /[0-9]+/) {
      $self->set_error_code('insecure');
    }
  }
  else {
    $self->set_error_code('mismatch');
  }
}

}

1;
