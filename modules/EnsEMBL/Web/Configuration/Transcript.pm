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

package EnsEMBL::Web::Configuration::Transcript;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Summary';
}

sub user_tree { return 1; }

# either - prediction transcript or transcript
# domain - domain only (no transcript)
# history - IDHistory object or transcript
# database:variation - Variation database
sub populate_tree {
  my $self = shift;

  $self->create_node('Summary', 'Summary',
    [qw(
      image         EnsEMBL::Web::Component::Transcript::TranscriptImage
      trans_summary EnsEMBL::Web::Component::Transcript::TranscriptSummary
    )],
    { 'availability' => 'either' }
  );

  my $T = $self->create_node('SupportingEvidence', 'Supporting evidence',
   [qw( evidence EnsEMBL::Web::Component::Transcript::SupportingEvidence )],
    { 'availability' => 'transcript has_evidence', 'concise' => 'Supporting evidence' }
  );
  
  $T->append($self->create_subnode('SupportingEvidence/Alignment', 'Alignment of Supporting Evidence',
    [qw( alignment EnsEMBL::Web::Component::Transcript::SupportingEvidenceAlignment )],
    { 'no_menu_entry' => 'transcript' }
  ));
  
  my $seq_menu = $self->create_submenu('Sequence', 'Sequence');
  
  $seq_menu->append($self->create_node('Exons', 'Exons',
    [qw( exons EnsEMBL::Web::Component::Transcript::ExonsSpreadsheet )],
    { 'availability' => 'either has_exons', 'concise' => 'Exons' }
  ));
  
  $seq_menu->append($self->create_node('Sequence_cDNA', 'cDNA',
    [qw( sequence EnsEMBL::Web::Component::Transcript::TranscriptSeq )],
    { 'availability' => 'either', 'concise' => 'cDNA sequence' }
  ));
  
  $seq_menu->append($self->create_node('Sequence_Protein', 'Protein',
    [qw( sequence EnsEMBL::Web::Component::Transcript::ProteinSeq )],
    { 'availability' => 'either', 'concise' => 'Protein sequence' }
  ));
  
  my $record_menu = $self->create_submenu('ExternalRecords', 'External References');

  my $sim_node = $self->create_node('Similarity', 'General identifiers',
    [qw( similarity EnsEMBL::Web::Component::Transcript::SimilarityMatches )],
    { 'availability' => 'transcript has_similarity_matches', 'concise' => 'General identifiers' }
  );
  
  $sim_node->append($self->create_subnode('Similarity/Align', 'Alignment of External Feature',
   [qw( alignment EnsEMBL::Web::Component::Transcript::ExternalRecordAlignment )],
    { 'no_menu_entry' => 'transcript' }
  ));
  
  $record_menu->append($sim_node);
  
  $record_menu->append($self->create_node('Oligos', 'Oligo probes',
    [qw( arrays EnsEMBL::Web::Component::Transcript::OligoArrays )],
    { 'availability' => 'transcript database:funcgen has_oligos', 'concise' => 'Oligo probes' }
  ));
  
  my $go_menu = $self->create_submenu('GO', 'Ontology');
  $go_menu->append($self->create_node('Ontology/Image', 'GO graph',
    [qw( go EnsEMBL::Web::Component::Transcript::Goimage )],
    { 'availability' => 'transcript has_go', 'concise' => 'GO graph' }
  ));

  $go_menu->append($self->create_node('Ontology/Table', 'GO table',
    [qw( go EnsEMBL::Web::Component::Transcript::Go )],
    { 'availability' => 'transcript has_go', 'concise' => 'GO table' }
  ));

  my $var_menu = $self->create_submenu('Variation', 'Genetic Variation');

  $var_menu->append($self->create_node('Variation_Transcript/Table', 'Variation table',
    [qw( variationtable EnsEMBL::Web::Component::Transcript::VariationTable )],
    { 'availability' => 'transcript database:variation core' }
  ));

  $var_menu->append($self->create_node('Variation_Transcript/Image', 'Variation image',
    [qw( variationimage EnsEMBL::Web::Component::Transcript::VariationImage )],
    { 'availability' => 'transcript database:variation core' }
  ));
    
  $var_menu->append($self->create_node('Population', 'Population comparison',
    [qw( snptable EnsEMBL::Web::Component::Transcript::PopulationTable )],
    { 'availability' => 'strains database:variation core' }
  ));
  
  $var_menu->append($self->create_node('Population/Image', 'Comparison image',
    [qw( snps EnsEMBL::Web::Component::Transcript::PopulationImage )],
    { 'availability' => 'strains database:variation core' }
  ));
  
  my $prot_menu = $self->create_submenu('Protein', 'Protein Information');
  
  $prot_menu->append($self->create_node('ProteinSummary', 'Protein summary',
    [qw(
      moreinfo   EnsEMBL::Web::Component::Transcript::TranslationInfo
      image      EnsEMBL::Web::Component::Transcript::TranslationImage
      statistics EnsEMBL::Web::Component::Transcript::PepStats
    )],
    { 'availability' => 'either translation', 'concise' => 'Protein summary' }
  ));
  
  my $D = $self->create_node('Domains', 'Domains & features',
    [qw( domains EnsEMBL::Web::Component::Transcript::DomainSpreadsheet )],
    { 'availability' => 'transcript has_domains', 'concise' => 'Domains & features' }
  );
  
  $D->append($self->create_subnode('Domains/Genes', 'Genes in domain',
    [qw( domaingenes EnsEMBL::Web::Component::Transcript::DomainGenes )],
    { 'availability' => 'transcript|domain', 'no_menu_entry' => 1 }
  ));
  
  $prot_menu->append($D);
  
  $prot_menu->append($self->create_node('ProtVariations', 'Variations',
    [qw( protvars EnsEMBL::Web::Component::Transcript::ProteinVariations )],
    { 'availability' => 'either database:variation has_variations', 'concise' => 'Variations' }
  ));
  
  # External Data tree, including non-positional DAS sources
  my $external = $self->create_node('ExternalData', 'External data',
    [qw( external EnsEMBL::Web::Component::Transcript::ExternalData )],
    { 'availability' => 'transcript' }
  );
  
  if ($self->hub->users_available) {
    $external->append($self->create_node('UserAnnotation', 'Personal annotation',
      [qw( manual_annotation EnsEMBL::Web::Component::Transcript::UserAnnotation )],
      { 'availability' => 'logged_in transcript' }
    ));
  }
  
  my $history_menu = $self->create_submenu('History', 'ID History');
  
  $history_menu->append($self->create_node('Idhistory', 'Transcript history',
    [qw(
      display    EnsEMBL::Web::Component::Gene::HistoryReport
      associated EnsEMBL::Web::Component::Gene::HistoryLinked
      map        EnsEMBL::Web::Component::Transcript::HistoryMap
    )],
    { 'availability' => 'history', 'concise' => 'ID History' }
  ));
  
  $history_menu->append($self->create_node('Idhistory/Protein', 'Protein history',
    [qw(
      display    EnsEMBL::Web::Component::Gene::HistoryReport/protein
      associated EnsEMBL::Web::Component::Gene::HistoryLinked/protein
      map        EnsEMBL::Web::Component::Transcript::HistoryMap/protein
    )],
    { 'availability' => 'history_protein', 'concise' => 'ID History' }
  ));
  
  $self->create_subnode('Output', 'Export Transcript Data',
    [qw( export EnsEMBL::Web::Component::Export::Output )],
    { 'availability' => 'transcript', 'no_menu_entry' => 1 }
  );
}

1;

