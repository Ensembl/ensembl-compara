# $Id$

package EnsEMBL::Web::ImageConfig::Vkaryotype;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::Vertical);

sub init {
  my $self = shift;

  $self->set_parameters({
    label           => 'below',
    band_labels     => 'off',
    top_margin      => 5,
    band_links      => 'no',
    all_chromosomes => 'yes'
  });

  $self->create_menus('ideogram', 'user_data');

  $self->add_tracks('ideogram',
    [ 'drag_left', '', 'Vdraggable', { display => 'normal', part => 0, menu => 'no' }],
    [ 'Videogram', 'Ideogram', 'Videogram', {
      display    => 'normal',
      renderers  => [ 'normal', 'normal' ],
      width      => 12,
      totalwidth => 18,
      padding    => 6,
      colourset  => 'ideogram',
      menu       => 'no',
    }],
    [ 'drag_right', '', 'Vdraggable', { display => 'normal', part => 1, menu => 'no' }],
  );
  
  $self->{'extra_menus'} = {};
}

1;
