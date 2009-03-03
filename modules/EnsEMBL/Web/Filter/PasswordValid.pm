package EnsEMBL::Web::Filter::PasswordValid;

### Checks if a password matches the encrypted value stored in the database

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Tools::Encryption;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Filter);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'empty_password'    => 'You did not supply a password. Please try again.',
    'invalid_password'  => qq(Sorry, the email address or password was entered incorrectly and could not be validated. Please try again.<br /><br />If you are unsure of your password, click the 'Lost Password' link in the lefthand menu to reactivate your account.),
  });
}

sub catch {
  my $self = shift;
  my $object = $self->object;
  $self->set_redirect('/Account/Login');
  if ($object->param('password')) {
    my $user = EnsEMBL::Web::Data::User->find(email => $object->param('email'));
    if ($user) { 
      my $input_password = $object->param('password');
      my $encrypted = EnsEMBL::Web::Tools::Encryption::encryptPassword($input_password, $user->salt);
      if ($user->password ne $encrypted) {
        $self->set_error_code('invalid_password');
      } 
    }
    else {
      ## N.B. for security reasons, we do not distinguish between 
      ## an invalid email address and an invalid password
      $self->set_error_code('invalid_password');
    }
  }
  else {
    $self->set_error_code('empty_password');
  }
}

}

1;
