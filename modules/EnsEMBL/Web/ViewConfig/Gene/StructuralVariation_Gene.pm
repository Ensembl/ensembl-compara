package EnsEMBL::Web::ViewConfig::Gene::StructuralVariation_Gene;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    image_width   800
    das_sources), []
  );
  
  $self->add_image_configs({qw(
    gene_sv_view das
  )});
  
  $self->default_config = 'gene_sv_view';
  $self->storable = 1;
}

1;
