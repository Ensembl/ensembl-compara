package EnsEMBL::Web::Controller::Command::Filter::PasswordValid;

use strict;
use warnings;

use EnsEMBL::Web::Object::Data::User;
use EnsEMBL::Web::Tools::Encryption;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub allow {
  my ($self) = @_;
  my $user = $self->SUPER::user($self->get_action->get_named_parameter('id'));
  warn "USER: " . $user->name;
  warn "PASSWORD: " . $user->password;
  my $input_password = $self->get_action->get_named_parameter('password');
  my $encrypted = EnsEMBL::Web::Tools::Encryption::encrypt_password($input_password, $user->salt);
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
