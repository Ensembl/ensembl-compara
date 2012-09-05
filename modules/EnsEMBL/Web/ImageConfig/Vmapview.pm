# $Id$

package EnsEMBL::Web::ImageConfig::Vmapview;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::Vertical);

sub init {
  my $self = shift;

  $self->set_parameters({
    label        => 'above',
    band_labels  => 'on',
    image_height => 450,
    image_width  => 500,
    top_margin   => 40,
    band_links   => 'yes',
    spacing      => 10,
    scale_values => [qw(
                        codingdensity
                        noncodingdensity
                        pseudogenedensity)],
    active_menu  => 'other'
  });

  $self->create_menus('other', 'user_data');
  
  $self->get_node('other')->set('caption', 'Features');
  
  $self->add_tracks('other',
    [ 'drag_left', '', 'Vdraggable', { display => 'normal', part => 0, menu => 'no' }],
    [ 'Videogram', 'Ideogram', 'Videogram', {
      display   => 'normal',
      colourset => 'ideogram',
      menu      => 'no',
      renderers => [ 'normal', 'normal' ],
    }],
    [ 'Vcodgenes', 'CodGenes', 'Vdensity_features', {
      scale_all  => 1,
      display    => 'density_outline',
      colourset  => 'densities',
      keys       => [ 'codingdensity' ],
      renderers  => [
        'off',             'Off',
        'density_outline', 'Bar chart - outline',
        'density_bar',     'Bar chart - filled',
        'density_line',    'Line graph'
      ],
    }],
    [ 'VNonCodgenes', 'NonCodGenes', 'Vdensity_features', {
      scale_all  => 1,
      display    => 'density_outline',
      colourset  => 'densities',
      keys       => [ 'noncodingdensity' ],
      renderers  => [
        'off',             'Off',
        'density_outline', 'Bar chart - outline',
        'density_bar',     'Bar chart - filled',
        'density_line',    'Line graph',
      ],
    }],
     [ 'VPseudogenes', 'PseudoGenes', 'Vdensity_features', {
       scale_all  => 1,
       display    => 'density_outline',
       colourset  => 'densities',
       keys       => [ 'pseudogenedensity' ],
       renderers  => [
         'off',             'Off',
         'density_outline', 'Bar chart - outline',
         'density_bar',     'Bar chart - filled',
         'density_line',    'Line graph'],
     }],
     [ 'Vpercents', 'Percent GC/Repeats', 'Vdensity_features', {
       same_scale => 1,
       display    => 'density_mixed',
       colourset  => 'densities',
       keys       => [ 'percentgc', 'percentagerepeat' ],
       renderers  => [
         'off',           'Off', 
         'density_mixed', 'Histogram and line'
       ],
     }],
     $self->hub->species_defs->databases->{'DATABASE_VARIATION'} ? [ 'Vsnps', 'Variations', 'Vdensity_features', {
       same_scale => 1,
       display    => 'density_outline',
       colourset  => 'densities',
       maxmin     => 1,
       keys       => [ 'snpdensity' ],
       renderers  => [
         'off',             'Off', 
         'density_line',    'Line graph', 
         'density_bar',     'Bar chart - filled',
         'density_outline', 'Bar chart - outline',
       ],
     }] : (),
    [ 'drag_right', '', 'Vdraggable', { display => 'normal', part => 1, menu => 'no' }],
  );
  
  $self->{'extra_menus'} = {};
}

1;
