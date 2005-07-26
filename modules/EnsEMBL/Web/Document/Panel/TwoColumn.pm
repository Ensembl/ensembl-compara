package EnsEMBL::Web::Document::Panel::TwoColumn;

use strict;
use EnsEMBL::Web::Document::Panel;

@EnsEMBL::Web::Document::Panel::TwoColumn::ISA = qw(EnsEMBL::Web::Document::Panel);

sub content {
  my( $self ) = @_;
  return '<p>TwoColumn</p>';
}

return 1;
