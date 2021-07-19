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

package EnsEMBL::Draw::GlyphSet::fg_methylation_legend;

### Legend showing yellow-blue gradient used in methylation heatmaps

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my $self = shift;

  ## Hide if corresponding tracks are all off
  my $node = $self->{'config'}->get_node('functional_dna_methylation');
  return unless $node;
  my $show = 0;
  foreach ($node->descendants) {
    if ($_->get('display') && $_->get('display') ne 'off') {
      $show = 1;
      last;
    }
  }
  return unless $show;

  # Let them accumulate in structure if accumulating and not last
  my $Config         = $self->{'config'};
  return if ($self->my_config('accumulate') eq 'yes' &&
             $Config->get_parameter('more_slices'));
  return unless $self->{'legend'}{[split '::', ref $self]->[-1]};
  # Clear features (for next legend)
  $self->{'legend'}{[split '::', ref $self]->[-1]} = {};
  
  $self->init_legend(2);

  $self->add_to_legend({
    legend => '% methylated reads',
    colour => [qw(yellow green blue)],
  }); 
  
  $self->add_space;
}

1;
