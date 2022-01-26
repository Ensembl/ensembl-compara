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

package EnsEMBL::Draw::Style::Graph::Barcode;

### Uses the Barcode glyph to render histogram-type data
### as a continuous run of equal-sized rectangles 

use parent qw(EnsEMBL::Draw::Style::Graph);

sub draw_wiggle {
  my ($self, $c, $features) = @_;

  my $height = $c->{'height'} || 8;
  
  my $params = {
    values    => $features,
    x         => 1,
    y         => $c->{'y_offset'} || 0,
    height    => $height,
    unit      => $c->{'unit'},
    max       => $c->{'max_score'},
    colours   => $c->{'colours'},
  };
  push @{$self->glyphs}, $self->Barcode($params);
  $self->draw_hidden_bgd($height);
}

1;
