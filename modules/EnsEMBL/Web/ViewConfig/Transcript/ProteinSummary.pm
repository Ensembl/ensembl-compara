# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::ProteinSummary;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    das_sources), []
  );
  
  $self->add_image_configs({qw(
    protview das
  )});
  
  $self->default_config = 'protview';
  $self->storable       = 1;
}

1;
