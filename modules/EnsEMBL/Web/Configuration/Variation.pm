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

package EnsEMBL::Web::Configuration::Variation;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = 'Explore';
}

sub has_tabs { return 1; }

sub user_tree { return 1; }

sub tree_cache_key {
  my $self = shift;
  my $key  = $self->SUPER::tree_cache_key(@_);
     $key .= '::SOMATIC' if $self->object && $self->object->Obj->is_somatic;
  
  return $key;
}

sub populate_tree {
  my $self    = shift;
  my $somatic = $self->object ? $self->object->Obj->has_somatic_source : undef;

  $self->create_node('Explore', 'Explore this variant',
    [qw(
      explore EnsEMBL::Web::Component::Variation::Explore
    )],
    { 'availability' => 'variation' }
  );
  
  my $context_menu = $self->create_node('Context', 'Genomic context',
    [qw( context EnsEMBL::Web::Component::Variation::Context )],
    { 'availability' => 'variation has_locations database:compara has_alignments', 'concise' => 'Context' }
  );
  
  $context_menu->append($self->create_node('Mappings', 'Genes and regulation',
    [qw( mappings EnsEMBL::Web::Component::Variation::Mappings )],
    { 'availability' => 'variation has_features', 'concise' => 'Genes and regulation' }
  ));
  $context_menu->append($self->create_node('Sequence', 'Flanking sequence',
    [qw( flanking EnsEMBL::Web::Component::Variation::FlankingSequence )],
    { 'availability' => 'variation has_locations' }
  ));  
    
  $self->create_node('Population', 'Population genetics',
    [qw( 
      graphs  EnsEMBL::Web::Component::Variation::PopulationGraphs
      table   EnsEMBL::Web::Component::Variation::PopulationGenotypes 
    )],
    { 'availability' => 'variation has_populations not_somatic', 'concise' => 'Population genetics', 'no_menu_entry' => $somatic }
  );

  $self->create_node('Phenotype', 'Phenotype data',
    [qw( 
        phenotype EnsEMBL::Web::Component::Variation::Phenotype 
        genes     EnsEMBL::Web::Component::Variation::LocalGenes
    )],
    { 'availability' => 'variation has_locations has_ega', 'concise' => 'Phenotype Data' }
  );
  
  $self->create_node('Populations', 'Sample information',
    [qw( population EnsEMBL::Web::Component::Variation::PopulationGenotypes )],
    { 'availability' => 'variation has_populations is_somatic', 'concise' => 'Sample information', 'no_menu_entry' => !$somatic }
  );
  
  $self->create_node('Sample', 'Sample genotypes',
    [qw( 
      search EnsEMBL::Web::Component::Variation::SampleGenotypesSearch
      sample EnsEMBL::Web::Component::Variation::SampleGenotypes 
    )],
    { 'availability' => 'variation has_samples not_somatic', 'concise' => 'Sample genotypes', 'no_menu_entry' => $somatic }
  ); 
  
  $self->create_node('HighLD', 'Linkage disequilibrium',
    [qw( 
      pairwiseld EnsEMBL::Web::Component::Variation::PairwiseLD
      highld EnsEMBL::Web::Component::Variation::HighLD
    )],
    { 'availability' => 'variation has_ldpops variation has_samples not_somatic', 'concise' => 'Linkage disequilibrium', 'no_menu_entry' => $somatic }
  );
    

  $self->create_node('Compara_Alignments', 'Phylogenetic context',
    [qw(
      selector EnsEMBL::Web::Component::Compara_AlignSliceSelector
      alignment EnsEMBL::Web::Component::Variation::Compara_Alignments
    )],
    { 'availability' => 'variation has_variation_source_db database:compara has_alignments', 'concise' => 'Phylogenetic Context' }
  );
  $self->create_node('Citations', 'Citations',
    [qw( alignment EnsEMBL::Web::Component::Variation::Publication  )],
    { 'availability' => 'variation has_citation','concise' => 'Citations'  } 
  );  

  $self->create_node('LDPlot', 'Linkage disequilibrium plot',
    [qw(
      pop     EnsEMBL::Web::Component::Variation::SelectPopulation
      ld      EnsEMBL::Web::Component::Variation::LD
      ldplot  EnsEMBL::Web::Component::Variation::LDPlot
    )],
    { 'availability' => 'variation has_ldpops has_samples not_somatic', 'no_menu_entry' => 1 }
  );

  $self->create_node('PDB', '3D Protein model',
    [qw( alignment EnsEMBL::Web::Component::Variation::PDB )],
    { 'availability' => 'variation is_coding has_pdbe','concise' => '3D Protein model (PDBe)'}
  );

  $self->create_subnode(
    'Output', 'Export Variation Data',
    [qw( export EnsEMBL::Web::Component::Export::Output )],
    { 'availability' => 'variation', 'no_menu_entry' => 1 }
  );
}

1;
