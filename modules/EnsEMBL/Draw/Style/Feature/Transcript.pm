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

package EnsEMBL::Draw::Style::Feature::Transcript;

### Renders a track as a series of exons and introns 

use parent qw(EnsEMBL::Draw::Style::Feature::Structured);

sub draw_join {
  my ($self, $composite, %params) = @_;

  ## Now that we have used the correct coordinates, constrain to viewport
  if ($params{'x'} < 0) {
    $params{'x'}          = -1;
    $params{'width'}     += $params{'x'};
  }

  ## Draw the join as a horizontal line or a "hat"?
  if ($self->track_config->get('collapsed')) {
    $params{'y'} += $params{'height'}/2;
    $params{'height'} = 0;
    push @{$self->glyphs}, $self->Line(\%params);
  }
  elsif ($params{'x'} == 0 || ($params{'x'} + $params{'width'} >= $self->image_config->container_width)) {
    ## Join goes off edge of image, so draw a horizontal dotted line
    $params{'y'} += $params{'height'}/2;
    $params{'height'} = 0;
    $params{'dotted'} = 1;
    $composite->push($self->Line(\%params));
  }
  else {
    $composite->push($self->Intron(\%params));
  }
}

1;
