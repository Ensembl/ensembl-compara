package EnsEMBL::Web::Filter::PasswordValid;

### Checks if a password matches the encrypted value stored in the database

use strict;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Tools::Encryption qw(encrypt_password);

use base qw(EnsEMBL::Web::Filter);

sub init {
  my $self = shift;
  
  $self->messages = {
    empty_password   => 'You did not supply a password. Please try again.',
    invalid_password => "Sorry, the email address or password was entered incorrectly and could not be validated. Please try again.<br /><br />If you are unsure of your password, click the 'Lost Password' link in the lefthand menu to reactivate your account."
  };
}

sub catch {
  my $self     = shift;
  my $hub      = $self->hub;
  my $password = $hub->param('password');
  
  $self->redirect = sprintf '/Account/Login?then=%s;modal_tab=%s', $hub->param('then'), $hub->param('modal_tab');
  
  if ($password) {
    my $user = EnsEMBL::Web::Data::User->find(email => $hub->param('email'));
    
    if ($user) { 
      my $encrypted = encrypt_password($password, $user->salt);
      
      $self->error_code = 'invalid_password' if $user->password ne $encrypted;
    } else {
      # N.B. for security reasons, we do not distinguish between an invalid email address and an invalid password
      $self->error_code = 'invalid_password';
    }
  } else {
    $self->error_code = 'empty_password';
  }
}

1;
