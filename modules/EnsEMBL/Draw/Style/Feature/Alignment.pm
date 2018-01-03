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

package EnsEMBL::Draw::Style::Feature::Alignment;

### Renders a track as a series of align blocks

use parent qw(EnsEMBL::Draw::Style::Feature);

sub draw_feature {
### Create each alignment as a block
### @param feature Arrayref - data for a genomic alignment block
### @param position Hashref - information about the feature's size and position
  my ($self, $block, $position) = @_;

  ## We only need the alignment for the current species
  my $feature = $block->{$self->image_config->{'species'}};
  return unless $feature;
  #use Data::Dumper;
  #warn ">>> DRAWING FEATURE ".Dumper($feature);
  $position->{'width'} = $feature->{'end'} - $feature->{'start'};

  $self->SUPER::draw_feature($feature, $position);
}

1;
