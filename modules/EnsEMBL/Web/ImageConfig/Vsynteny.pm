# $Id$

package EnsEMBL::Web::ImageConfig::Vsynteny;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::Vertical);

sub init {
  my $self = shift;

  $self->set_parameters({
    title           => 'Synteny panel',
    label           => 'above',
    band_labels     => 'off',
    image_height    => 500,
    image_width     => 550,
    top_margin      => 20,
    band_links      => 'no',
    main_width      => 30,
    secondary_width => 12,
    padding         => 4,
    spacing         => 20,
    inner_padding   => 140,
    outer_padding   => 20,
  });

  $self->create_menus('features', 'Features');

  $self->add_tracks('features', [ 'Vsynteny', 'Videogram', 'Vsynteny', { display => 'normal', renderers => [ 'normal', 'normal' ], colourset => 'ideogram' } ]);
}

1;
