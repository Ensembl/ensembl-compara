package EnsEMBL::Web::ImageConfig::Vkaryoblast;

## Alternative configuration for karyotype used in BlastView
use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Karyotype panel',
    'label'         => 'below',     # margin
    'band_labels'   => 'off',
    'image_height'  => 200,
    'image_width'   => 225,
    'top_margin'    => 5,
    'band_links'    => 'no',
    'rows'          => 2,
    'all_chromosomes' => 'yes'
  });

  $self->create_menus( 
    'ideogram' => 'Ideogram', # N.B. Karyotype not currently configurable
   );

  $self->add_tracks( 'ideogram',
    [ 'Videogram', 'Ideogram', 'Videogram', {
      'display'    => 'normal',
      'renderers'  => [qw(normal normal)],
      'width'      => 12,
      'totalwidth' => 18,
      'padding'    => 6,
      'colourset'  => 'ideogram'
    } ]
  );
}

1;
