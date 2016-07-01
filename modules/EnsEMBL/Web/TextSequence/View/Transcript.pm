package EnsEMBL::Web::TextSequence::View::Transcript;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::View);

use EnsEMBL::Web::TextSequence::Sequence::Transcript;

sub make_sequence {
  return
    EnsEMBL::Web::TextSequence::Sequence::Transcript->new(@_);
}

1;
