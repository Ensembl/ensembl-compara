# $Id$

package EnsEMBL::Web::ViewConfig::LRG::Summary;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    image_width   800
    das_sources), []
  );
  
  $self->add_image_configs({qw(
    lrg_summary das
  )});
  
  $self->default_config = 'lrg_summary';
  $self->storable       = 1;
}

1;
