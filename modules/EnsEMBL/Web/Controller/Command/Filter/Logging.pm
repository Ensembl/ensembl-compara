package EnsEMBL::Web::Controller::Command::Filter::Logging;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub allow {
  my $self = shift;
  warn "Checking for authorisation";
  return $self->SUPER::allow();
}

sub message {
  my $self = shift;
  return $self->SUPER::allow();
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
