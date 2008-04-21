package EnsEMBL::Web::Controller::Command::Filter::InvitationValid;

use strict;
use warnings;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

### Checks if a given invitation code matches the value stored in the database

{

sub allow {
  my ($self) = @_;
  my $cgi = new CGI;
  my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($cgi->param('id'));
  if ($invitation->code eq $cgi->param('code')) {
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
