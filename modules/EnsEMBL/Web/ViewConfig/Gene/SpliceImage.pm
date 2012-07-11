package EnsEMBL::Web::ViewConfig::Gene::SpliceImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('gene_splice', 'nodas');
  $self->title = 'Splice variants';
}

1;
