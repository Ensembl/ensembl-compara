package EnsEMBL::Web::Controller::Command::Filter::Authentication;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub allow {
  my $self = shift;
  if ($ENSEMBL_WEB_REGISTRY->get_user->id) {
    return 1;
  }
  #my $previous = $self->SUPER::allow(); 
  return 0;
}

sub message {
  my $self = shift;
  return "You must be logged in to view this page.";
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
