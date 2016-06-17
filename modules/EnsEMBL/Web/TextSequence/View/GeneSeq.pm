package EnsEMBL::Web::TextSequence::View::GeneSeq;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::View);

use EnsEMBL::Web::TextSequence::Legend::GeneSeq;

sub make_legend {
  return EnsEMBL::Web::TextSequence::Legend::GeneSeq->new;
}

1;
