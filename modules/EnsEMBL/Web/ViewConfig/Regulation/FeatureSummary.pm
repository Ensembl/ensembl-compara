# $Id$

package EnsEMBL::Web::ViewConfig::Regulation::FeatureSummary;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('reg_summary');
}

1;
