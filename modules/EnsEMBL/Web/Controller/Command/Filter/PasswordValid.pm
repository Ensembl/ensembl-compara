package EnsEMBL::Web::Controller::Command::Filter::PasswordValid;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Tools::Encryption;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

### Checks if a password matches the encrypted value stored in the database

{

sub allow {
  my $self = shift;
  my $cgi = $self->action->cgi;

  ## TODO: proper error exception
  my $user = EnsEMBL::Web::Data::User->find(email => $cgi->param('email'));
  return 0 unless $user;
  
  my $input_password = $cgi->param('password');
  my $encrypted = EnsEMBL::Web::Tools::Encryption::encryptPassword($input_password, $user->salt);
  warn "INPUT = $encrypted, FETCHED = ".$user->password;
  if ($user->password eq $encrypted) {
    return 1;
  } else {
    return 0;
  }
}

sub message {
  my $self = shift;
  return qq(Sorry, your username or password was entered incorrectly and could not be validated.<br /><br /><a href="/Account/Login" class="cp-internal">Try again</a>.);
}

}

1;
