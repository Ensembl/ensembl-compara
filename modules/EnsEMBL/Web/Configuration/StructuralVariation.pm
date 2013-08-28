# $Id$

package EnsEMBL::Web::Configuration::StructuralVariation;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = 'Explore';
}


sub populate_tree {
  my $self = shift;
  
  $self->create_node('Explore', 'Explore this SV',
    [qw(
      explore EnsEMBL::Web::Component::StructuralVariation::Explore
    )],
    { 'availability' => 'structural_variation' }
  );
  
  
  my $context_menu = $self->create_node('Context', 'Genomic context',
    [qw( context  EnsEMBL::Web::Component::StructuralVariation::Context)],
    { 'availability' => 'structural_variation', 'concise' => 'Context' }
  );

  $context_menu->append($self->create_node('Mappings', 'Genes and regulation',
    [qw( mappings EnsEMBL::Web::Component::StructuralVariation::Mappings )],
    { 'availability' => 'has_transcripts', 'concise' => 'Genes and regulation' }
  ));
  
  $self->create_node('Evidence', 'Supporting evidence ([[counts::supporting_structural_variation]])',
    [qw( evidence  EnsEMBL::Web::Component::StructuralVariation::SupportingEvidence)],
    { 'availability' => 'has_supporting_structural_variation', 'concise' => 'Supporting evidence' }
  );
  
  $self->create_node('Phenotype', 'Phenotype Data',
    [qw( 
        phenotype EnsEMBL::Web::Component::StructuralVariation::Phenotype  
        genes     EnsEMBL::Web::Component::StructuralVariation::LocalGenes 
    )],
    { 'availability' => 'has_phenotype', 'concise' => 'Phenotype Data' }
  );
  
}
1;
