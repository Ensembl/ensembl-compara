package EnsEMBL::Web::Controller::Command::Filter::PasswordValid;

use strict;
use warnings;

use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::Tools::Encryption;
use EnsEMBL::Web::RegObj;
use CGI;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

### Checks if a password matches the encrypted value stored in the database

{

sub allow {
  my ($self) = @_;
    
  my $cgi = new CGI;
  my $email = $cgi->param('email');
  my$password = $cgi->param('password');

  my $user = EnsEMBL::Web::Object::User->new({
    adaptor   => $ENSEMBL_WEB_REGISTRY->userAdaptor,
    email     => $email,
  });
  my $input_password = $cgi->param('password');
  my $encrypted = EnsEMBL::Web::Tools::Encryption::encryptPassword($input_password, $user->salt);
  if ($user->password eq $encrypted) {
    return 1;
  } else {
    return 0;
  }
}

sub message {
  my $self = shift;
  return 'Sorry, these details could not be validated.';
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
