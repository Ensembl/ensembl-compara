package EnsEMBL::Web::ImageConfig::Vmapview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Chromosome panel',
    'label'         => 'above',     # margin
    'band_labels'   => 'on',
    'image_height'  => 450,
    'image_width'   => 500,
    'top_margin'    => 40,
    'band_links'    => 'yes',
    'spacing'       => 10
  });

  $self->create_menus( 
      'features' => 'Features', 
      'user_data'  => 'User attached data', # DAS/URL tracks/uploaded data/blast responses
  );

  $self->add_tracks( 'features',
    [ 'drag_left', '', 'Vdraggable', { 'display' => 'normal', 'part' => 0, 'menu' => 'no' } ],
    [ 'Videogram', 'Ideogram', 'Videogram', {
      'display'   => 'normal',
      'colourset' => 'ideogram',
      'renderers' => [qw(normal normal)],
    } ],
    [ 'Vgenes',    'Genes',    'Vdensity_features', {
      'same_scale' => 1,
      'display'   => 'density_outline',
      'colourset' => 'densities',
      'renderers' => ['off' =>  'Off',
                      'density_outline' => 'Bar chart',
                      'density_graph'  =>  'Lines'],
      'keys'      => [qw(geneDensity knownGeneDensity)],
    }],
    [ 'Vpercents',  'Percent GC/Repeats',    'Vdensity_features', {
      'same_scale' => 1,
      'display'   => 'density_mixed',
      'colourset' => 'densities',
      'renderers' => ['off' => 'Off', 'density_mixed' => 'Histogram and line'],
      'keys'      => [qw(PercentGC PercentageRepeat)]
    }],
    [ 'Vsnps',      'Variations',    'Vdensity_features', {
      'display'   => 'density_outline',
      'colourset' => 'densities',
      'maxmin'    => 1,
      'renderers' => ['off' => 'Off', 
                      'density_line'    => 'Line graph', 
                      'density_bar'     => 'Bar chart - filled',
                      'density_outline' => 'Bar chart - outline',
                      ],
      'keys'      => [qw(snpDensity)],
    }],
    [ 'drag_right', '', 'Vdraggable', { 'display' => 'normal', 'part' => 1, 'menu' => 'no' } ],
  );
}


1;
