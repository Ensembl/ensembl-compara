# $Id$

package EnsEMBL::Web::ViewConfig::Location::Region;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('cytoview');
}

1;
