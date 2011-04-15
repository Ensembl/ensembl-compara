# $Id$

package EnsEMBL::Web::ViewConfig::Location::Overview;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    context 10000
  ));
  
  $self->add_image_configs({qw(
    cytoview das
  )});
  
  $self->default_config = 'cytoview';
  $self->storable       = 1;
}

1;
