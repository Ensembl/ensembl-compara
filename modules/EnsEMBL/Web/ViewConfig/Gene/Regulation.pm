# $Id$

package EnsEMBL::Web::ViewConfig::Gene::Regulation;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    image_width   800
    das_sources), []
  );
  
  $self->add_image_configs({qw(
    generegview nodas
  )});
  
  $self->default_config = 'generegview';
  $self->storable = 1;
}

1;
