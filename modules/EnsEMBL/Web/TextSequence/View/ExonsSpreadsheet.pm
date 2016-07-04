package EnsEMBL::Web::TextSequence::View::ExonsSpreadsheet;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::View);

use EnsEMBL::Web::TextSequence::Legend::ExonsSpreadsheet;

sub make_legend {
  return EnsEMBL::Web::TextSequence::Legend::ExonsSpreadsheet->new(@_);
}

sub interleaved { return 0; }

1;
