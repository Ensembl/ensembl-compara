# $Id$

package EnsEMBL::Web::ImageConfig::Vmapview;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::Vertical);

sub init {
  my $self = shift;

  $self->set_parameters({
    title         => 'Chromosome panel',
    label         => 'above',
    band_labels   => 'on',
    image_height  => 450,
    image_width   => 500,
    top_margin    => 40,
    band_links    => 'yes',
    spacing       => 10
  });

  $self->create_menus( 
    'features',  'Features', 
    'user_data', 'User attached data', # DAS/URL tracks/uploaded data/blast responses
  );

  $self->add_tracks('features',
    [ 'drag_left', '', 'Vdraggable', { display => 'normal', part => 0, menu => 'no' }],
    [ 'Videogram', 'Ideogram', 'Videogram', {
      display   => 'normal',
      colourset => 'ideogram',
      renderers => [ 'normal', 'normal' ],
    }],
    [ 'Vgenes', 'Genes', 'Vdensity_features', {
      same_scale => 1,
      display    => 'density_outline',
      colourset  => 'densities',
      keys       => [ 'geneDensity', 'knownGeneDensity' ],
      renderers  => [
        'off',             'Off',
        'density_outline', 'Bar chart',
        'density_graph',   'Lines'
      ],
    }],
    [ 'Vpercents', 'Percent GC/Repeats', 'Vdensity_features', {
      same_scale => 1,
      display    => 'density_mixed',
      colourset  => 'densities',
      keys       => [ 'PercentGC', 'PercentageRepeat' ],
      renderers  => [
        'off',           'Off', 
        'density_mixed', 'Histogram and line'
      ],
    }],
    [ 'Vsnps', 'Variations', 'Vdensity_features', {
      display   => 'density_outline',
      colourset => 'densities',
      maxmin    => 1,
      keys      => [ 'snpDensity' ],
      renderers => [
        'off',             'Off', 
        'density_line',    'Line graph', 
        'density_bar',     'Bar chart - filled',
        'density_outline', 'Bar chart - outline',
      ],
    }],
    [ 'drag_right', '', 'Vdraggable', { display => 'normal', part => 1, menu => 'no' }],
  );
}

1;
