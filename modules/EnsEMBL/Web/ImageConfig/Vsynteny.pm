package EnsEMBL::Web::ImageConfig::Vsynteny;
use strict;
use EnsEMBL::Web::ImageConfig;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

$self->set_parameters({
    'title'           => 'Synteny panel',
    'label'           => 'above',     # margin
    'band_labels'     => 'off',
    'image_height'    => 500,
    'image_width'     => 550,
    'top_margin'      => 20,
    'band_links'      => 'no',
    'main_width'      => 30,
    'secondary_width' => 12,
    'padding'         => 4,
    'spacing'         => 20,
    'inner_padding'   => 140,
    'outer_padding'   => 20,
  });

  $self->create_menus( 'features' => 'Features' );

  $self->add_tracks( 'features',
    [ 'Vsynteny', 'Videogram', 'Vsynteny', {
      'display'   => 'normal',
      'renderers' => [qw(normal normal)],
      'colourset' => 'ideogram'
    } ],
  );

}

1;
