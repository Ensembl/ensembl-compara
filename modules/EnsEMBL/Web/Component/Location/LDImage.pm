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

package EnsEMBL::Web::Component::Location::LDImage;

use strict;

use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object || $self->hub->core_object('location');
  
  return unless $hub->param('pop1');
  
  my $slice = $object->slice;
 
  my $limit = 75; #100
 
  if ($slice->length >= ($limit * 1000)) {
    return $self->_error(
      'Region too large', 
      "<p>The region you have selected is too large to display linkage data; a maximum region of ${limit}kb is allowed. Please change the region using the navigation controls above.<p>"
    );
  }
  
  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE     = $hub->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::VCF_BINARY_FILE = $hub->species_defs->ENSEMBL_LD_VCF_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH        = $hub->species_defs->ENSEMBL_TMP_TMP;
  
  my $image_config = $hub->get_imageconfig('ldview');
  my $parameters   = { 
    image_width     => $self->image_width || 800, 
    container_width => $slice->length
  };
  
  $image_config->init_slice($parameters);
  
  # Do images for first section
  my $containers_and_configs = [ $slice, $image_config ];
  
  # Do images for each population
  foreach my $pop_name (sort { $a cmp $b } map { $object->pop_name_from_id($_) || () } @{$object->current_pop_id}) {
    my $population_image_config = $hub->get_imageconfig({type => 'ldview', cache_code => $pop_name});
    $population_image_config->init_population($parameters, $pop_name);
    push @$containers_and_configs, $slice, $population_image_config;
  }

  my $image = $self->new_image($containers_and_configs, $object->highlights);
  
  return if $self->_export_image($image);
  
  $image->{'panel_number'}  = 'top';
  $image->imagemap          = 'yes';
  $image->{'export_params'} = ['pop1'];
  $image->set_button('drag', 'title' => 'Drag to select region');

  return $image->render;
}

1;
