package EnsEMBL::Web::TextSequence::View::TranscriptComparison;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::View);

use EnsEMBL::Web::TextSequence::Legend::TranscriptComparison;
use EnsEMBL::Web::TextSequence::Sequence::Comparison;

sub make_legend {
  return EnsEMBL::Web::TextSequence::Legend::TranscriptComparison->new(@_);
}

sub make_sequence {
  return
    EnsEMBL::Web::TextSequence::Sequence::Comparison->new(@_);
}

1;
