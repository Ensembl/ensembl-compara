package EnsEMBL::Web::Controller::Command::Filter::ActivationValid;

use strict;
use warnings;

use EnsEMBL::Web::Object::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub allow {
  my ($self) = @_;
  warn "Getting named: " . $self->get_action->get_named_parameter('code');
  my $user = $self->SUPER::user($self->get_action->get_named_parameter('id'));
  warn "USER: " . $user->name;
  warn "SALT: " . $user->salt;
  if ($user->salt eq $self->get_action->get_named_parameter('code')) {
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
