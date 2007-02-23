package EnsEMBL::Web::Controller::Command::Filter::Logging;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub footer {
  my $self = shift;
  my $footer = "This is the default footer"; 
  return $footer . $self->SUPER::allow();
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
