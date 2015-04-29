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

package EnsEMBL::Web::Configuration::Variation;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = 'Explore';
}

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

  $self->create_node('Explore', 'Explore this variation',
    [qw(
      explore EnsEMBL::Web::Component::Variation::Explore
    )],
    { 'availability' => 'variation' }
  );
  
  my $context_menu = $self->create_node('Context', 'Genomic context',
    [qw( context EnsEMBL::Web::Component::Variation::Context )],
    { 'availability' => 'variation', 'concise' => 'Context' }
  );
  
  $context_menu->append($self->create_node('Mappings', 'Genes and regulation',
    [qw( mappings EnsEMBL::Web::Component::Variation::Mappings )],
    { 'availability' => 'variation has_transcripts', 'concise' => 'Genes and regulation' }
  ));
  $context_menu->append($self->create_node('Sequence', 'Flanking sequence',
    [qw( flanking EnsEMBL::Web::Component::Variation::FlankingSequence )],
    { 'availability' => 'variation' }
  ));  
    
  $self->create_node('Population', 'Population genetics',
    [qw( 
      graphs  EnsEMBL::Web::Component::Variation::PopulationGraphs
      table   EnsEMBL::Web::Component::Variation::PopulationGenotypes 
    )],
    { 'availability' => 'variation has_populations not_somatic', 'concise' => 'Population genetics', 'no_menu_entry' => $somatic }
  );
  
  $self->create_node('Populations', 'Sample information',
    [qw( population EnsEMBL::Web::Component::Variation::PopulationGenotypes )],
    { 'availability' => 'variation has_populations is_somatic', 'concise' => 'Sample information', 'no_menu_entry' => !$somatic }
  );
  
  $self->create_node('Individual', 'Individual genotypes',
    [qw( 
      search     EnsEMBL::Web::Component::Variation::IndividualGenotypesSearch
      individual EnsEMBL::Web::Component::Variation::IndividualGenotypes 
    )],
    { 'availability' => 'variation has_individuals not_somatic', 'concise' => 'Individual genotypes', 'no_menu_entry' => $somatic }
  ); 
  
  $self->create_node('HighLD', 'Linkage disequilibrium',
    [qw( highld EnsEMBL::Web::Component::Variation::HighLD )],
    { 'availability' => 'variation has_ldpops variation has_individuals not_somatic', 'concise' => 'Linkage disequilibrium', 'no_menu_entry' => $somatic }
  );
    
  $self->create_node('Phenotype', 'Phenotype Data',
    [qw( 
        phenotype EnsEMBL::Web::Component::Variation::Phenotype 
        genes     EnsEMBL::Web::Component::Variation::LocalGenes
    )],
    { 'availability' => 'variation has_ega', 'concise' => 'Phenotype Data' }
  );
  
  $self->create_node('Compara_Alignments', 'Phylogenetic Context',
    [qw(
      selector EnsEMBL::Web::Component::Compara_AlignSliceSelector
      alignment EnsEMBL::Web::Component::Variation::Compara_Alignments
    )],
    { 'availability' => 'variation database:compara has_alignments', 'concise' => 'Phylogenetic Context' }
  );
  $self->create_node('Citations', 'Citations',
    [qw( alignment EnsEMBL::Web::Component::Variation::Publication  )],
    { 'availability' => 'variation has_citation','concise' => 'Citations'  } 
  );  
  
  # External Data tree, including non-positional DAS sources
  my $external = $self->create_node('ExternalData', 'External Data',
    [qw( external EnsEMBL::Web::Component::Variation::ExternalData )],
    { 'availability' => 'variation' }
  );
  
  $self->create_subnode(
    'Output', 'Export Variation Data',
    [qw( export EnsEMBL::Web::Component::Export::Output )],
    { 'availability' => 'variation', 'no_menu_entry' => 1 }
  );
}

1;
