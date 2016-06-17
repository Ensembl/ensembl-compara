package EnsEMBL::Web::TextSequence::View::TranscriptComparison;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::View);

use EnsEMBL::Web::TextSequence::Legend::TranscriptComparison;

sub make_legend {
  return EnsEMBL::Web::TextSequence::Legend::TranscriptComparison->new;
}

1;
