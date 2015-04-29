=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::SVTable;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Component::Shared);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;  
  my $slice   = $object->slice;
  my $html    = $self->structural_variation_table($slice, 'Structural variants',         'sv',  ['get_all_StructuralVariationFeatures','get_all_somatic_StructuralVariationFeatures'], 1);
     $html   .= $self->structural_variation_table($slice, 'Copy number variants probes', 'cnv', ['get_all_CopyNumberVariantProbeFeatures']);
  
  return $html;
}

1;
