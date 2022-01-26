=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::legends;

### Draws all the legends stored in the image config

use strict;

use parent qw(EnsEMBL::Draw::GlyphSet);

sub can_json { return 1; }

sub render_normal {
  my $self = shift;
  my $legend_data = $self->{'config'}->legend;
  return unless scalar keys %$legend_data > 1;

  ## Grab settings and pass into track config
  my $settings = delete $legend_data->{'_settings'};
  $self->track_style_config->set('legend_settings', $settings);

  ## Add some generic settings
  $self->track_style_config->set('box_width', 8 / $self->scalex);
  $self->track_style_config->set('icon_height', );

  my @order = sort { $legend_data->{$a}{'priority'} <=> $legend_data->{$b}{'priority'} } keys %$legend_data;
 
  foreach my $key (@order) {
    my $legend = $legend_data->{$key};
    my $config = $self->track_style_config;
    ## Default to basic boxes with labels
    my $legend_style = 'EnsEMBL::Draw::Style::Legend';
    $legend_style   .= '::'.$legend->{'style'} if $legend->{'style'};
    my $style        = $legend_style->new($config, $legend);
    $self->push($style->create_glyphs);
  }
}

1;
