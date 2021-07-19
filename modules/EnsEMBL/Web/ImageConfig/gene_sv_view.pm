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

package EnsEMBL::Web::ImageConfig::gene_sv_view;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    storable          => 0,
    image_resizeable  => 1,
    opt_lines         => 1, # draw registry lines
  });

  $self->create_menus(qw(
    sequence
    transcript
    prediction
    variation
    somatic
    functional
    external_data
    user_data
    other
    information
  ));

  $self->add_tracks('other',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }],
  );

  $self->add_tracks('sequence',
    [ 'contig', 'Contigs',  'contig', { display => 'normal', strand => 'r' }]
  );

  $self->load_tracks;

  $self->modify_configs(
    [ 'fg_regulatory_features_funcgen', 'transcript', 'prediction', 'variation' ],
    { display => 'off' }
  );

  $self->modify_configs(
    [ 'transcript_core_ensembl', 'transcript_core_sg' ],
    { display => 'transcript_label' }
  );


  # structural variations
  $self->modify_configs(
    ['variation_feature_structural_larger'],
    { display => 'compact', depth => 1 }
  );
  $self->modify_configs(
    ['variation_feature_structural_smaller'],
    { display => 'gene_nolabel', depth => 100 }
  );

  # Somatic structural variations
  $self->modify_configs(
    [ 'somatic_sv_feature' ],
    { display => 'gene_nolabel', depth => 50 }
  );
}

1;
