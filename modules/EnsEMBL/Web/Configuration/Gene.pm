# $Id$

package EnsEMBL::Web::Configuration::Gene;

use strict;

use EnsEMBL::Web::RegObj;

use base qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Summary';
}

sub populate_tree {
  my $self = shift;
  
  $self->create_node('Summary', 'Gene summary',
    [qw(
      summary     EnsEMBL::Web::Component::Gene::GeneSummary
      transcripts EnsEMBL::Web::Component::Gene::TranscriptsImage
    )],
    { 'availability' => 'gene', 'concise' => 'Gene summary' }
  );

  $self->create_node('Splice', 'Splice variants ([[counts::transcripts]])',
    [qw( image EnsEMBL::Web::Component::Gene::GeneSpliceImage )],
    { 'availability' => 'gene has_transcripts', 'concise' => 'Splice variants' }
  );

  $self->create_node('Evidence', 'Supporting evidence',
    [qw( evidence EnsEMBL::Web::Component::Gene::SupportingEvidence )],
    { 'availability' => 'gene', 'concise' => 'Supporting evidence' }
  );

  $self->create_node('Sequence', 'Sequence',
    [qw( sequence EnsEMBL::Web::Component::Gene::GeneSeq )],
    { 'availability' => 'gene', 'concise' => 'Marked-up sequence' }
  );

  $self->create_node('Matches', 'External references ([[counts::similarity_matches]])',
    [qw( matches EnsEMBL::Web::Component::Gene::SimilarityMatches )],
    { 'availability' => 'gene has_similarity_matches', 'concise' => 'External references' }
  );

  $self->create_node('Regulation', 'Regulation',
    [qw(
      regulation EnsEMBL::Web::Component::Gene::RegulationImage
      features   EnsEMBL::Web::Component::Gene::RegulationTable
    )],
    { 'availability' => 'regulation' }
  );
  
  my $compara_menu = $self->create_submenu('Compara', 'Comparative Genomics');
  
  $compara_menu->append($self->create_node('Compara_Alignments', 'Genomic alignments ([[counts::alignments]])',
    [qw(
      selector   EnsEMBL::Web::Component::Compara_AlignSliceSelector
      alignments EnsEMBL::Web::Component::Gene::Compara_Alignments
    )],
    { 'availability' => 'gene database:compara core has_alignments', 'concise' => 'Genomic alignments' }
  ));
  
  my $tree_node = $self->create_node('Compara_Tree', 'Gene Tree (image)',
    [qw( image EnsEMBL::Web::Component::Gene::ComparaTree )],
    { 'availability' => 'gene database:compara core has_gene_tree' }
  );
  
  $tree_node->append($self->create_subnode('Compara_Tree/Text', 'Gene Tree (text)',
    [qw( treetext EnsEMBL::Web::Component::Gene::ComparaTree/text )],
    { 'availability' => 'gene database:compara core has_gene_tree' }
  ));
  
  $tree_node->append($self->create_subnode('Compara_Tree/Align', 'Gene Tree (alignment)',
    [qw( treealign EnsEMBL::Web::Component::Gene::ComparaTree/align )],
    { 'availability' => 'gene database:compara core has_gene_tree' }
  ));
  
  $compara_menu->append($tree_node);

  my $ol_node = $self->create_node('Compara_Ortholog', 'Orthologues ([[counts::orthologs]])',
    [qw( orthologues EnsEMBL::Web::Component::Gene::ComparaOrthologs )],
    { 'availability' => 'gene database:compara core has_orthologs', 'concise' => 'Orthologues' }
  );
  
  $ol_node->append($self->create_subnode('Compara_Ortholog/Alignment', 'Ortholog Alignment',
    [qw( alignment EnsEMBL::Web::Component::Gene::HomologAlignment )],
    { 'availability'  => 'gene database:compara core has_orthologs', 'no_menu_entry' => 1 }
  ));
  
  $compara_menu->append($ol_node);
  
  my $pl_node = $self->create_node('Compara_Paralog', 'Paralogues ([[counts::paralogs]])',
    [qw(paralogues EnsEMBL::Web::Component::Gene::ComparaParalogs)],
    { 'availability' => 'gene database:compara core has_paralogs', 'concise' => 'Paralogues' }
  );
  
  $pl_node->append($self->create_subnode('Compara_Paralog/Alignment', 'Paralogue Alignment',
    [qw( alignment EnsEMBL::Web::Component::Gene::HomologAlignment )],
    { 'availability' => 'gene database:compara core has_paralogs', 'no_menu_entry' => 1 }
  ));
  
  $compara_menu->append($pl_node);
  
  my $fam_node = $self->create_node('Family', 'Protein families ([[counts::families]])',
    [qw( family EnsEMBL::Web::Component::Gene::Family )],
    { 'availability' => 'family', 'concise' => 'Protein families' }
  );
  
  my $sd   = ref $self->{'object'} ? $self->{'object'}->species_defs : undef;
  my $name = $sd ? $sd->get_config($self->{'object'}->species, 'SPECIES_COMMON_NAME') : '';
  
  $fam_node->append($self->create_subnode('Family/Genes', uc($name) . ' genes in this family',
    [qw( genes EnsEMBL::Web::Component::Gene::FamilyGenes )],
    { 'availability'  => 'family', 'no_menu_entry' => 1 }
  ));
  
  $fam_node->append($self->create_subnode('Family/Proteins', 'Proteins in this family',
    [qw(
      ensembl EnsEMBL::Web::Component::Gene::FamilyProteins/ensembl
      other   EnsEMBL::Web::Component::Gene::FamilyProteins/other
    )],
    { 'availability'  => 'family database:compara core', 'no_menu_entry' => 1 }
  ));
  
  $fam_node->append($self->create_subnode('Family/Alignments', 'Multiple alignments in this family',
    [qw( jalview EnsEMBL::Web::Component::Gene::FamilyAlignments )],
    { 'availability'  => 'family database:compara core', 'no_menu_entry' => 1 }
  ));
  
  $compara_menu->append($fam_node);
  
  my $var_menu = $self->create_submenu('Variation', 'Genetic Variation');

  $var_menu->append($self->create_node('Variation_Gene/Table', 'Variation Table',
    [qw( snptable EnsEMBL::Web::Component::Gene::GeneSNPTable )],
    { 'availability' => 'gene database:variation core' }
  ));
  
  $var_menu->append($self->create_node('Variation_Gene',  'Variation Image',
    [qw( image EnsEMBL::Web::Component::Gene::GeneSNPImage )],
    { 'availability' => 'gene database:variation' }
  ));

  # External Data tree, including non-positional DAS sources
  my $external = $self->create_node('ExternalData', 'External Data',
    [qw( external EnsEMBL::Web::Component::Gene::ExternalData )],
    { 'availability' => 'gene' }
  );
  
  if ($self->object->species_defs->ENSEMBL_LOGINS) {
    $external->append($self->create_node('UserAnnotation', 'Personal annotation',
      [qw( manual_annotation EnsEMBL::Web::Component::Gene::UserAnnotation )],
      { 'availability' => 'logged_in gene' }
    ));
  }
  
  my $history_menu = $self->create_submenu('History', 'ID History');
  
  $history_menu->append($self->create_node('Idhistory', 'Gene history',
    [qw(
      display    EnsEMBL::Web::Component::Gene::HistoryReport
      associated EnsEMBL::Web::Component::Gene::HistoryLinked
      map        EnsEMBL::Web::Component::Gene::HistoryMap
    )],
    { 'availability' => 'history', 'concise' => 'ID History' }
  ));
  
  $self->create_subnode('Export', 'Export Gene Data',
    [qw( export EnsEMBL::Web::Component::Export::Gene )],
    { 'availability' => 'gene', 'no_menu_entry' => 1 }
  );
}

sub user_populate_tree {
  my $self = shift;
  
  my $object = $self->object;
  
  return unless $object && ref $object;
  
  my $all_das    = $ENSEMBL_WEB_REGISTRY->get_all_das;
  my $vc         = $object->get_viewconfig(undef, 'ExternalData');
  my @active_das = grep { $vc->get($_) eq 'yes' && $all_das->{$_} } $vc->options;
  my $ext_node   = $self->tree->get_node('ExternalData');
  
  for my $logic_name (sort { lc($all_das->{$a}->caption) cmp lc($all_das->{$b}->caption) } @active_das) {
    my $source = $all_das->{$logic_name};
    
    $ext_node->append($self->create_subnode("ExternalData/$logic_name", $source->caption,
      [qw( textdas EnsEMBL::Web::Component::Gene::TextDAS )],
      {
        'availability' => 'gene', 
        'concise'      => $source->caption, 
        'caption'      => $source->caption, 
        'full_caption' => $source->label
      }
    ));	 
  }
}

1;
