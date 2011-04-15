# $Id$

package EnsEMBL::Web::ViewConfig::Gene::Summary;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    image_width   800
    das_sources), []
  );
  
  $self->add_image_configs({qw(
    gene_summary das
  )});
  
  $self->default_config = 'gene_summary';
  $self->storable = 1;
}

1;
