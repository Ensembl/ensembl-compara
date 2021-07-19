=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ImageConfig::Vmapview;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig::Vertical);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

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
                        shortnoncodingdensity
                        longnoncodingdensity
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
      'hide_empty'=> 1,
    }],
    [ 'VShortNonCodgenes', 'ShortNonCodGenes', 'Vdensity_features', {
      scale_all  => 1,
      display    => 'density_outline',
      colourset  => 'densities',
      keys       => [ 'shortnoncodingdensity' ],
      renderers  => [
        'off',             'Off',
        'density_outline', 'Bar chart - outline',
        'density_bar',     'Bar chart - filled',
        'density_line',    'Line graph',
      ],
      'hide_empty'=> 1,
    }],
    [ 'VLongNonCodgenes', 'LongNonCodGenes', 'Vdensity_features', {
      scale_all  => 1,
      display    => 'density_outline',
      colourset  => 'densities',
      keys       => [ 'longnoncodingdensity' ],
      renderers  => [
        'off',             'Off',
        'density_outline', 'Bar chart - outline',
        'density_bar',     'Bar chart - filled',
        'density_line',    'Line graph',
      ],
      'hide_empty'=> 1,
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
      'hide_empty'=> 1,
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
      'hide_empty'=> 1,
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

  $self->remove_extra_menu;
}

sub init_non_cacheable {
  ## @override
  my $self = shift;

  # Add user defined data sources
  $self->load_user_tracks;
  $self->display_threshold_message;
}

1;
