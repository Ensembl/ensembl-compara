package EnsEMBL::Web::TextSequence::View::ComparaAlignments;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::View);

use EnsEMBL::Web::TextSequence::Sequence::Comparison;

sub make_sequence {
  return
    EnsEMBL::Web::TextSequence::Sequence::Comparison->new(@_);
}

1;
