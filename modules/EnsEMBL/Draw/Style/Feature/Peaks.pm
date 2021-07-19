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

package EnsEMBL::Draw::Style::Feature::Peaks;

=pod

Renders MultiBlocks with optional triangles to mark peaks, e.g.
for regulatory evidence tracks

=cut

use parent qw(EnsEMBL::Draw::Style::Feature::MultiBlocks);


sub draw_feature {
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, $position) = @_;

  my $total_height = $self->SUPER::draw_feature($feature, $position);

  my $length    = $self->image_config->container_width;
  my $midpoint  = $feature->{'midpoint'};
  if ($midpoint && $self->track_config->get('display_summit') && $length <= 20000) {
    $midpoint -= $self->track_config->get('slice_start');

    if ($midpoint > 0 && $midpoint < $length) {
      my $th  = 4;
      my $h   = $position->{'height'};
      my $y   = $position->{'y'};
      push @{$self->glyphs}, $self->Triangle({ # Upward pointing triangle
          width     => 4 / $self->{'pix_per_bp'},
          height    => $th,
          direction => 'up',
          mid_point => [ $midpoint, $h + $y ],
          colour    => 'black',
          absolutey => 1,
      }), $self->Triangle({ # Downward pointing triangle
          width     => 4 / $self->{'pix_per_bp'},
          height    => $th,
          direction => 'down',
          mid_point => [ $midpoint, $h + $y - 9 ],
          colour    => 'black',
          absolutey => 1,
      });
    }
    ## Increase total height regardless of whether there are triangles or not,
    ## otherwise it causes problems when some features are outside the viewport
    $total_height += ($th * 2);
  }
  return $total_height;
}

1;
