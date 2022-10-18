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

package EnsEMBL::Web::Configuration::Gene;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Summary';
}

sub has_tabs { return 1; }

sub user_tree { return 1; }

sub populate_tree {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $strain       = $species_defs->RELATED_TAXON; # species that are in a compara strain tree
  my $collapse     = $hub->is_strain ? 0 : 1; # check if species is a strain

  my $summary_menu = $self->create_node('Summary', 'Summary',
    [qw(
      gene_summary  EnsEMBL::Web::Component::Gene::GeneSummary
      navbar        EnsEMBL::Web::Component::ViewNav
      transcripts   EnsEMBL::Web::Component::Gene::TranscriptsImage
    )],
    { 'availability' => 'gene' }
  );

  $summary_menu->append($self->create_node('Splice', 'Splice variants',
    [qw( image EnsEMBL::Web::Component::Gene::SpliceImage )],
    { 'availability' => 'gene has_transcripts', 'concise' => 'Splice variants' }
  ));

  $summary_menu->append($self->create_node('TranscriptComparison', 'Transcript comparison',
    [qw(
      select EnsEMBL::Web::Component::Gene::TranscriptComparisonSelector
      seq    EnsEMBL::Web::Component::Gene::TranscriptComparison
    )],
    { 'availability' => 'gene multiple_transcripts not_rnaseq' }
  ));

  $summary_menu->append($self->create_node('Alleles', 'Gene alleles',
                     [qw(alleles EnsEMBL::Web::Component::Gene::Alleles)],
                     { 'availability' => 'core has_alt_alleles', 'concise' => 'Gene Alleles' }
                   ));

  my $seq_menu = $self->create_node('Sequence', 'Sequence',
    [qw( sequence EnsEMBL::Web::Component::Gene::GeneSeq )],
    { 'availability' => 'gene', 'concise' => 'Marked-up sequence' }
  );

  $seq_menu->append($self->create_node('SecondaryStructure', 'Secondary Structure',
    [qw(
      secondary EnsEMBL::Web::Component::Gene::RnaSecondaryStructure
    )],
   { 'availability' => 'gene can_r2r has_2ndary'}
  ));

  my $compara_menu = $self->create_node('Compara', 'Comparative Genomics',
    [qw(strain_button_panel EnsEMBL::Web::Component::Gene::Compara_Portal)],
    {'availability' => 'gene database:compara core not_strain'}
  );
  
  $compara_menu->append($self->create_node('Compara_Alignments', 'Genomic alignments',
    [qw(
      selector   EnsEMBL::Web::Component::Compara_AlignSliceSelector
      alignments EnsEMBL::Web::Component::Gene::Compara_Alignments
    )],
    { 'availability' => 'gene database:compara core has_alignments' }
  ));
  
  $compara_menu->append($self->create_node('Compara_Tree', 'Gene tree',
    [qw( image EnsEMBL::Web::Component::Gene::ComparaTree )],
    { 'availability' => 'gene database:compara core has_gene_tree not_strain' }
  ));
  
  $compara_menu->append($self->create_node('SpeciesTree', 'Gene gain/loss tree',
      [qw( image EnsEMBL::Web::Component::Gene::SpeciesTree )],
      { 'availability' => 'gene database:compara core has_species_tree not_strain' }
    ));
    
  my $ol_node = $self->create_node('Compara_Ortholog', 'Orthologues',
    [qw( orthologues EnsEMBL::Web::Component::Gene::ComparaOrthologs )],
    { 'availability' => 'gene database:compara core has_orthologs not_strain', 'concise' => 'Orthologues' }
  );
  
  $ol_node->append($self->create_subnode('Compara_Ortholog/Alignment', 'Orthologue alignment',
    [qw( alignment EnsEMBL::Web::Component::Gene::HomologAlignment )],
    { 'availability'  => 'gene database:compara core has_orthologs not_strain', 'no_menu_entry' => 1 }
  ));
  
  $compara_menu->append($ol_node);
  
  my $pl_node = $self->create_node('Compara_Paralog', 'Paralogues',
    [qw(paralogues EnsEMBL::Web::Component::Gene::ComparaParalogs)],
    { 'availability' => 'gene database:compara core has_paralogs not_strain', 'concise' => 'Paralogues' }
  );
  
  $pl_node->append($self->create_subnode('Compara_Paralog/Alignment', 'Paralogue alignment',
    [qw( alignment EnsEMBL::Web::Component::Gene::HomologAlignment )],
    { 'availability' => 'gene database:compara core has_paralogs not_strain', 'no_menu_entry' => 1 }
  ));
  
  $compara_menu->append($pl_node);
  
  
  # Compara menu for strain (strain menu available on main species but collapse, main menu not available/grey out/collapse on strain page)
  # The node key (Strain_) is used by Component.pm to determine if it is a strain link on the main species page, so be CAREFUL when changing this  
  if($strain || $self->hub->is_strain) {  
    my $strain_type = ucfirst $species_defs->STRAIN_TYPE;
    my $strain_compara_menu = $self->create_node('Strain_Compara', $strain_type.'s',
      [qw(strain_button_panel EnsEMBL::Web::Component::Gene::Compara_Portal)],
      {'availability' => 'gene database:compara core', 'closed' => $collapse }
    );

    $strain_compara_menu->append($self->create_node('Strain_Compara_Tree', 'Gene tree',
      [qw( image EnsEMBL::Web::Component::Gene::ComparaTree )],
      { 'availability' => 'gene database:compara core has_strain_gene_tree' }
    ));

    my $strain_ol_node = $self->create_node('Strain_Compara_Ortholog', 'Orthologues',
      [qw( orthologues EnsEMBL::Web::Component::Gene::ComparaOrthologs )],
      { 'availability' => 'gene database:compara core has_strain_orthologs', 'concise' => 'Orthologues' }
    );

    $strain_ol_node->append($self->create_subnode('Strain_Compara_Ortholog/Alignment', 'Orthologue alignment',
      [qw( alignment EnsEMBL::Web::Component::Gene::HomologAlignment )],
      { 'availability'  => 'gene database:compara core has_strain_orthologs', 'no_menu_entry' => 1 }
    ));

    $strain_compara_menu->append($strain_ol_node);
    
    my $strain_pl_node = $self->create_node('Strain_Compara_Paralog', 'Paralogues',
      [qw(paralogues EnsEMBL::Web::Component::Gene::ComparaParalogs)],
      { 'availability' => 'gene database:compara core has_strain_paralogs', 'concise' => 'Paralogues' }
    );
    
    $strain_pl_node->append($self->create_subnode('Strain_Compara_Paralog/Alignment', 'Paralogue alignment',
      [qw( alignment EnsEMBL::Web::Component::Gene::HomologAlignment )],
      { 'availability' => 'gene database:compara core has_strain_paralogs', 'no_menu_entry' => 1 }
    ));
    
    $strain_compara_menu->append($strain_pl_node);  
    $compara_menu->append($strain_compara_menu);  
  }  

  # get all ontologies mapped to this species
  my $go_menu = $self->create_submenu('Ontologies', 'Ontologies');
  my %olist   = map {$_ => 1} @{$species_defs->SPECIES_ONTOLOGIES || []};

  if (%olist) {
    # get all ontologies available in the ontology db
    my %clusters = $species_defs->multiX('ONTOLOGIES');

    # get all the clusters that can generate a graph
    my @clist = grep {$olist{$clusters{$_}->{db}}} sort {$clusters{$a}->{db} cmp $clusters{$b}->{db}} keys %clusters;    # Find if this ontology has been loaded into ontology db

    foreach my $oid (@clist) {
      my $cluster = $clusters{$oid};

      (my $desc2 = $cluster->{db}.": ".ucfirst($cluster->{description})) =~ s/_/ /g;

      $go_menu->append($self->create_node('Ontologies/'. $cluster->{description}, $desc2, [qw( go EnsEMBL::Web::Component::Gene::Go )], {'availability' => "gene has_go_$oid", 'concise' => $desc2 }));
    }
  }

  $self->create_node('Phenotype',  'Phenotypes',
    [qw(
      phenotype EnsEMBL::Web::Component::Gene::GenePhenotype
      variation EnsEMBL::Web::Component::Gene::GenePhenotypeVariation
      orthologue EnsEMBL::Web::Component::Gene::GenePhenotypeOrthologue
    )],
    { 'availability' => 'core' }  #can't be any cleverer than this since checking orthologs is too slow
  );
	
  my $var_menu = $self->create_submenu('Variation', 'Genetic Variation');

  $var_menu->append($self->create_node('Variation_Gene/Table', 'Variant table',
    [qw( snptable EnsEMBL::Web::Component::Gene::VariationTable )],
    { 'availability' => 'gene database:variation core not_patch' }
  ));
  
  $var_menu->append($self->create_node('Variation_Gene/Image',  'Variant image',
    [qw( 
        notice  EnsEMBL::Web::Component::Gene::RetirementNotice 
        image   EnsEMBL::Web::Component::Gene::VariationImage 
      )],
    { 'availability' => 'gene database:variation core not_patch' }
  ));
	
  $var_menu->append($self->create_node('StructuralVariation_Gene', 'Structural variants',
    [qw(
      svimage EnsEMBL::Web::Component::Gene::SVImage
      svtable EnsEMBL::Web::Component::Gene::SVTable
    )],
    { 'availability' => 'gene has_structural_variation core not_patch' }
  ));

  $self->create_node('ExpressionAtlas', 'Gene expression',
    [qw( atlas EnsEMBL::Web::Component::Gene::ExpressionAtlas )],
    { 'availability'  => 'gene has_gxa' }
  );

  $self->create_node('Regulation', 'Regulation',
    [qw(
      regulation EnsEMBL::Web::Component::Gene::RegulationImage
      features   EnsEMBL::Web::Component::Gene::RegulationTable
    )],
    { 'availability' => 'regulation not_patch not_rnaseq' }
  );

  $self->create_node('Matches', 'External references',
    [qw( 
      matches EnsEMBL::Web::Component::Gene::SimilarityMatches 
    )],
    { 'availability' => 'gene has_similarity_matches', 'concise' => 'External references' }
  );

  $self->create_node('Evidence', 'Supporting evidence',
    [qw( evidence EnsEMBL::Web::Component::Gene::SupportingEvidence )],
    { 'availability' => 'gene', 'concise' => 'Supporting evidence' }
  );

  $self->create_node('Evidence', 'Supporting evidence',
    [qw( evidence EnsEMBL::Web::Component::Gene::SupportingEvidence )],
    { 'availability' => 'gene', 'concise' => 'Supporting evidence' }
  );

  my $history_menu = $self->create_submenu('History', 'ID History');

  $history_menu->append($self->create_node('Idhistory', 'Gene history',
    [qw(
      display    EnsEMBL::Web::Component::Gene::HistoryReport
      associated EnsEMBL::Web::Component::Gene::HistoryLinked
      map        EnsEMBL::Web::Component::Gene::HistoryMap
    )],
    { 'availability' => 'history', 'concise' => 'ID History' }
  ));
  
  $self->create_subnode('Output', 'Export Gene Data',
    [qw( export EnsEMBL::Web::Component::Export::Output )],
    { 'availability' => 'gene', 'no_menu_entry' => 1 }
  );

  my $gxa = $self->get_node('ExpressionAtlas');
  my $pathway = $self->create_node('Pathway', 'Pathway',
    [qw( pathway EnsEMBL::Web::Component::Gene::Pathway )],
    { 'availability'  => 'gene has_pathway' }
  );
  $gxa->after($pathway);

}

1;
