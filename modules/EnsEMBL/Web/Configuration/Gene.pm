package EnsEMBL::Web::Configuration::Gene;

use strict;

use EnsEMBL::Web::RegObj;

use base qw( EnsEMBL::Web::Configuration );

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub configurator   { return $_[0]->_configurator;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub set_default_action {
  my $self = shift;
  
  if (!ref $self->object) {
    $self->{'_data'}->{'default'} = 'Summary';
    return;
  }
  
  my $x = $self->object->availability || {};
  
  if ($x->{'gene'}) {
    $self->{'_data'}->{'default'} = 'Summary';
  } elsif ($x->{'idhistory'}) {
    $self->{'_data'}->{'default'} = 'Idhistory';
  } elsif ($x->{'family'}) {
    $self->{'_data'}->{'default'} = 'Family';
  }
}

sub _filename {
  my $self = shift;
  my $name = sprintf '%s-gene-%d-%s-%s',
          $self->species,
          $self->species_defs->ENSEMBL_VERSION,
          $self->get_db,
          $self->stable_id;
  $name =~ s/[^-\w\.]/_/g;
  return $name;
}

sub availability {
  my $self = shift;
  my $hub = $self->model->hub;

  if (!$self->{'_availability'}) {
    my $availability = $self->default_availability;
    my $gene = $self->model->object('Gene');
    my $g = $self->model->raw_object('Gene');

    if ($g->isa('Bio::EnsEMBL::ArchiveStableId')) {
      $availability->{'history'} = 1;
    } 
    elsif ($g->isa('Bio::EnsEMBL::Gene')) {
      my $counts      = $self->counts;
      my $rows        = $gene->table_info($gene->get_db, 'stable_id_event')->{'rows'};
      my $funcgen_res = $hub->database('funcgen') ? $gene->table_info('funcgen', 'feature_set')->{'rows'} ? 1 : 0 : 0;
      my $compara_db  = $hub->database('compara');
      my $gene_tree   = $gene->get_ProteinTree;
      my $res         = 0;
      my $has_gene_tree;

      if ($gene_tree) {
        eval { $has_gene_tree = !!$gene_tree->get_leaf_by_Member($self->{'_member_compara'}); }
      }
      
      if ($compara_db) {
        ($res) = $compara_db->get_MemberAdaptor->dbc->db_handle->selectrow_array(
          'select stable_id from family_member fm, member as m where fm.member_id=m.member_id and stable_id=? limit 1', {}, $g->stable_id
        );
      }
      $availability->{'history'}       = !!$rows;
      $availability->{'gene'}          = 1;
      $availability->{'core'}          = $gene->get_db eq 'core';
      $availability->{'alt_allele'}    = $gene->table_info($gene->get_db, 'alt_allele')->{'rows'};
      $availability->{'regulation'}    = !!$funcgen_res; 
      $availability->{'family'}        = !!$res;
      $availability->{'has_gene_tree'} = $has_gene_tree; # FIXME: Once compara get their act together, revert to $gene_tree && $gene_tree->get_leaf_by_Member($self->{'_member_compara'});
      $availability->{"has_$_"}        = $counts->{$_} for qw(transcripts alignments paralogs orthologs similarity_matches);
    } 
    elsif ($g->isa('Bio::EnsEMBL::Compara::Family')) {
      $availability->{'family'} = 1;
    }

    $self->{'_availability'} = $availability;
  }

  return $self->{'_availability'};
}

sub counts {
  my $self = shift;
  my $hub = $self->model->hub;
  my $gene = $self->model->object('Gene');
  my $g = $self->model->raw_object('Gene');

  return {} unless $g->isa('Bio::EnsEMBL::Gene');

  my $key = sprintf '::COUNTS::GENE::%s::%s::%s::', $hub->species, $hub->core_param('db'), $hub->core_param('g');
  my $counts = $self->{'_counts'};
  $counts ||= $hub->cache->get($key) if $hub->cache;

  if (!$counts) {
    $counts = {
      transcripts        => scalar @{$g->get_all_Transcripts},
      exons              => scalar @{$g->get_all_Exons},
      similarity_matches => $self->count_xrefs
    };

    my $compara_db = $hub->database('compara');

    if ($compara_db) {
      my $compara_dbh = $compara_db->get_MemberAdaptor->dbc->db_handle;

      if ($compara_dbh) {
        $counts = {%$counts, %{$self->count_homologues($compara_dbh)}};

        my ($res) = $compara_dbh->selectrow_array(
          'select count(*) from family_member fm, member as m where fm.member_id=m.member_id and stable_id=?',
          {}, $g->stable_id
        );

        $counts->{'families'} = $res;
      }

     $counts->{'alignments'} = $self->count_alignments->{'all'} if $gene->get_db eq 'core';
    }

    $counts = {%$counts, %{$self->_counts}};

    $hub->cache->set($key, $counts, undef, 'COUNTS') if $hub->cache;
    $self->{'_counts'} = $counts;
  }

  return $counts;
}

sub count_homologues {
  my ($self, $compara_dbh) = @_;

  my $counts = {};

  # TODO: re-add between_species_paralog
  my $res = $compara_dbh->selectall_arrayref(
    'select ml.type, h.description, count(*) as N
      from member as m, homology_member as hm, homology as h,
           method_link as ml, method_link_species_set as mlss
     where m.stable_id = ? and hm.member_id = m.member_id and
           h.homology_id = hm.homology_id and 
           mlss.method_link_species_set_id = h.method_link_species_set_id and
           ml.method_link_id = mlss.method_link_id and
           ( ml.type = "ENSEMBL_ORTHOLOGUES" or ml.type = "ENSEMBL_PARALOGUES" and h.description != "between_species_paralog" )
     group by description', {}, $self->model->raw_object('Gene')->stable_id
  );

  foreach (@$res) {
    if ($_->[0] eq 'ENSEMBL_PARALOGUES') {
      $counts->{'paralogs'} += $_->[2];
    } elsif ($_->[1] !~ /^UBRH|BRH|MBRH|RHS$/) {
      $counts->{'orthologs'} += $_->[2];
    }
  }

  return $counts;
}

sub count_xrefs {
  my $self = shift;
  my $gene = $self->model->object('Gene');
  my $type = $gene->get_db;
  my $dbc = $gene->database($type)->dbc;

  # xrefs on the gene
  my $xrefs_c = 0;
  my $sql = '
    SELECT x.display_label, edb.db_name, edb.status
      FROM gene g, object_xref ox, xref x, external_db edb
     WHERE g.gene_id = ox.ensembl_id
       AND ox.xref_id = x.xref_id
       AND x.external_db_id = edb.external_db_id
       AND ox.ensembl_object_type = "Gene"
       AND g.gene_id = ?';

  my $sth = $dbc->prepare($sql);
  $sth->execute($self->model->raw_object('Gene')->dbID);
  while (my ($label,$db_name,$status) = $sth->fetchrow_array) {
    #these filters are taken directly from Component::_sort_similarity_links
    #code duplication needs removing, and some of these may well not be needed any more
    next if ($status eq 'ORTH');                        # remove all orthologs
    next if (lc($db_name) eq 'medline');                # ditch medline entries - redundant as we also have pubmed
    next if ($db_name =~ /^flybase/i && $type =~ /^CG/ ); # Ditch celera genes from FlyBase
    next if ($db_name eq 'Vega_gene');                  # remove internal links to self and transcripts
    next if ($db_name eq 'Vega_transcript');
    next if ($db_name eq 'Vega_translation');
    next if ($db_name eq 'GO');
    next if ($db_name eq 'OTTP') && $label =~ /^\d+$/; #ignore xrefs to vega translation_ids
    next if ($db_name =~ /ENSG|OTTG/);
    $xrefs_c++;
  }
  return $xrefs_c;
}

sub count_gene_supporting_evidence {
  #count all supporting_features and transcript_supporting_features for the gene
  #- not used in the tree but keep the code just in case we change our minds again!
  my $self = shift;
  my $g = $self->model->raw_object('Gene');
  my $o_type = $self->get_db;
  my $evi_count = 0;
  my %c;
  foreach my $trans (@{$g->get_all_Transcripts()}) {
    foreach my $evi (@{$trans->get_all_supporting_features}) {
      my $hit_name = $evi->hseqname;
      $c{$hit_name}++;
    }
    foreach my $exon (@{$trans->get_all_Exons()}) {
      foreach my $evi (@{$exon->get_all_supporting_features}) {
        my $hit_name = $evi->hseqname;
        $c{$hit_name}++;
      }
    }
  }
  return scalar(keys(%c));
}


sub populate_tree {
  my $self = shift;
  my $availability = $self->object->availability;
  
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
    [qw(
      snptable EnsEMBL::Web::Component::Gene::GeneSNPTable
      snpinfo  EnsEMBL::Web::Component::Gene::GeneSNPInfo
    )],
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
