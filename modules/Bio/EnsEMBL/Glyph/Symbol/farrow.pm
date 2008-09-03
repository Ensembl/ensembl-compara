=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::farrow

=head1 DESCRIPTION

Thin wrapper subclass around anchored_arrow, forcing forward orientation, and
setting full for default bar_style.

=cut

package Bio::EnsEMBL::Glyph::Symbol::farrow;
use strict;

use base qw(Bio::EnsEMBL::Glyph::Symbol::anchored_arrow);

sub default_bar_style {
  return 'full';
}

sub orientation {
  1;
}


1;
