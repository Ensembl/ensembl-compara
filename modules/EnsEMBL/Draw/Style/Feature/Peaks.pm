=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Renders a track as a series of rectangular blocks with
the peaks marked in a different colour

=cut

use parent qw(EnsEMBL::Draw::Style::Feature);


sub draw_feature {
### Create a glyph that's a filled rectangle with triangles indicating peaks
### and an optional "centre" marked in black
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, $position) = @_;

  return unless ($feature->{'colour'});
  my $total_height = $position->{'height'};

  ## Set parameters
  my $x = $feature->{'start'};
  $x    = 0 if $x < 0;
  my $params = {
                  x           => $x,
                  y           => $position->{'y'},
                  width       => $position->{'width'},
                  height      => $position->{'height'},
                  href        => $feature->{'href'},
                  title       => $feature->{'title'},
                  colour      => $feature->{'colour'},
                  absolutey   => 1,
                };
  #use Data::Dumper; warn Dumper($params);

  push @{$self->glyphs}, $self->Rect($params);

  ## Draw internal structure, e.g. motif features
  if ($feature->{'structure'} && $self->track_config->get('display_structure')) {
    foreach my $element (@{$feature->{'structure'}}) {
      push @{$self->glyphs}, $self->Rect({
          x         => $element->{'start'} - 1,
          y         => $position->{'y'},
          height    => $position->{'height'},
          width     => $element->{'end'} - $element->{'start'} + 1,
          absolutey => 1,
          colour    => 'black',
        });
    }
  }

  my $length    = $self->image_config->container_width;
  my $midpoint  = $feature->{'midpoint'};
  if ($length <= 20000 && $self->track_config->get('display_summit')) {
    my $th  = 4;
    if ($midpoint) {
      $midpoint -= $self->track_config->get('slice_start');
      my $h   = $position->{'height'};
      my $y   = $position->{'y'};

      if ($midpoint > 0 && $midpoint < $length) {
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
    }
    ## Increase total height regardless of whether there are triangles or not,
    ## otherwise it causes problems when some features are outside the viewport
    $total_height += ($th * 2);
  }
  return $total_height;
}

1;
