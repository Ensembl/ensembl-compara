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

package EnsEMBL::Draw::GlyphSet::fg_motif_features_legend;

### Legend showing colours used in motif feature bigbed files 

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my $self = shift;
  my $Config         = $self->{'config'};

  my $entries     = $self->{'legend'}{'fg_motif_features_legend'}{'entries'} || {};
  return unless scalar keys %$entries;

  # Let them accumulate in structure if accumulating and not last
  return if ($self->my_config('accumulate') eq 'yes' &&
             $Config->get_parameter('more_slices'));
  # Clear features (for next legend)
  $self->{'legend'}{[split '::', ref $self]->[-1]} = {};

  $self->init_legend();

  foreach (sort keys %$entries) {
    $self->add_to_legend($entries->{$_});
  }

  $self->add_space;
}

1;
