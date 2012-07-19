package EnsEMBL::Web::ViewConfig::Gene::VariationImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Gene::VariationTable);

sub init {
  my $self = shift;
  $self->SUPER::init;
  $self->add_image_config('gene_variation', 'nodas');
  $self->set_defaults({ context => 100 });
}

1;
