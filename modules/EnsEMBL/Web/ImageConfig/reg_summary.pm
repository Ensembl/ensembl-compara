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

package EnsEMBL::Web::ImageConfig::reg_summary;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    image_resizeable  => 1,
    sortable_tracks   => 'drag',
    opt_lines         => 1,
  });

  $self->create_menus(qw(
    sequence
    transcript
    prediction
    dna_align_rna
    simple
    misc_feature
    functional
    variation
    oligo
    repeat
    other
    information
  ));

  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }]
  );

  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'contig', { display => 'normal', strand => 'r' }]
  );

  $self->load_tracks;

  # $self->modify_configs(
  #   [ 'regulatory_features', 'functional_other_regulatory_regions' ],
  #   { display => 'normal' }
  # );

  $self->modify_configs(
    [ 'regulatory_features_core', 'regulatory_features_non_core' ],
    { display => 'off', menu => 'no' }
  );

  $self->modify_configs(
    [ 'crispr_WGE_CRISPR_sites'],
    { display => 'off' }
  );

  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'transcript_nolabel' }
  );

  my $menu = $self->get_node('seg_features');
  foreach my $node (@{$self->get_node('seg_features')->child_nodes}) {
    $self->modify_configs([$node->id],{ display => 'off' });
  }
}

1;
