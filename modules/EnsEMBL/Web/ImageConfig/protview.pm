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

package EnsEMBL::Web::ImageConfig::protview;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({ sortable_tracks => 'drag' });

  $self->create_menus(qw(
    domain
    feature
    variation
    somatic
    external_data
    other
    information
  ));

  $self->load_tracks;

  $self->modify_configs(
    [ 'variation', 'somatic' ],
    { menu => 'no' }
  );

  $self->modify_configs(
    [ 'variation_feature_variation', 'somatic_mutation_COSMIC' ],
    { menu => 'yes', glyphset => 'P_variation', display => 'normal', strand => 'r', colourset => 'protein_feature', depth => 1e5 }
  );
}

sub init_non_cacheable {
  ## @override
  my $self        = shift;
  my $hub         = $self->hub;
  my $translation = $hub->core_object('transcript') ? $hub->core_object('transcript')->Obj->translation : undef;
  my $id;
  if ($translation && $translation->stable_id) {
    $id = $translation->version ? $translation->stable_id.'.'.$translation->version : $translation->stable_id;
  } 
  else {
    $id = $hub->species_defs->ENSEMBL_SITETYPE.' Protein';
  }

  $self->SUPER::init_non_cacheable(@_);

  $self->add_tracks('other',
    [ 'scalebar',       'Scale bar', 'P_scalebar', { display => 'normal', strand => 'r' }],
    [ 'exon_structure', $id, 'P_protein',  { display => 'normal', strand => 'f', colourset => 'protein_feature', menu => 'no' }],
  );
}

1;
