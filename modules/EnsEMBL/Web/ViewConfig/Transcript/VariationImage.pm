package EnsEMBL::Web::ViewConfig::Transcript::VariationImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Transcript::VariationTable);

sub init {
  my $self = shift;
  $self->SUPER::init;
  $self->add_image_config('TranscriptSNPView', 'nodas');
}

1;
