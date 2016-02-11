=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  use Data::Dumper; warn Dumper($params);

  push @{$self->glyphs}, $self->Rect($params);
}

1;
