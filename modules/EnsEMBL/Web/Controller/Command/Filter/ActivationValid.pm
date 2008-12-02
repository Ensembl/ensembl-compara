package EnsEMBL::Web::Controller::Command::Filter::ActivationValid;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

### Checks if a given activation code matches the value stored in the database

{

sub allow {
  my ($self) = @_;
  my $cgi = $self->action->cgi;
  my $user;
  if ($cgi->param('user_id')) {
    $user = EnsEMBL::Web::Data::User->new($cgi->param('user_id'));
  } else {
    $user = EnsEMBL::Web::Data::User->find(email => $cgi->param('email'));
  }

  ## Strip all the non \w chars
  my $code = $cgi->param('code');
  $code =~ s/[^\w]//g;

  ## TO DO: Add email address to validation, once new link is standard
  if ($user->salt eq $code) {
    return 1;
  } else {
    return 0;
  }
}

sub message {
  my $self = shift;
  return 'Sorry, these details could not be validated.';
}

}

1;
