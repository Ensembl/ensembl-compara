package EnsEMBL::Web::Controller::Command::Filter::ActivationValid;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

### Checks if a given activation code matches the value stored in the database

{

sub allow {
  my ($self) = @_;
  my $cgi = new CGI;
  my $user;
  if ($cgi->param('user_id')) {
    $user = EnsEMBL::Web::Data::User->new($cgi->param('user_id'));
  } else {
    $user = EnsEMBL::Web::Data::User->find(email => $cgi->param('email'));
  }

  ## TO DO: Add email address to validation, once new link is standard
  if ($user && ($user->salt eq $cgi->param('code'))) {
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
