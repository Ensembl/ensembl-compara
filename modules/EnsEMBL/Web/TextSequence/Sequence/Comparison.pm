package EnsEMBL::Web::TextSequence::Sequence::Comparison;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Sequence);

sub ready {
  my ($self) = @_;

  $self->pre($self->padded_name.' ');
  $self->SUPER::ready;
}

1;
