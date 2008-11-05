package EnsEMBL::Web::Configuration::Transcript;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Document::Panel::Image;
use EnsEMBL::Web::Data::Release;
use EnsEMBL::Web::RegObj;
use Data::Dumper;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  unless( ref $self->object ) {
    $self->{_data}{default} = 'Summary';
    return;
  }

  my $x = $self->object->availability || {};
  if( $x->{'either'} ) {
    $self->{_data}{default} = 'Summary';
  } elsif( $x->{'idhistory'} ) {
    $self->{_data}{default} = 'Idhistory';
  }
}

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub ajax_zmenu      {
    my $self = shift;
    my $panel = $self->_ajax_zmenu;
    my $obj  = $self->object;
    my $dest = $obj->action().'/'.$obj->function();
    my $action = $obj->action;
    if ($dest eq 'SupportingEvidence/Alignment') {
      return $self->do_SE_align_menu($panel,$obj);
    } elsif ($action eq 'Idhistory_Node'){
      return $self->ajax_zmenu_id_history_tree_node();
    } elsif ($action eq 'Idhistory_Branch'){
      return $self->ajax_zmenu_id_history_tree_branch();
    } elsif ($action eq 'Idhistory_Label'){
      return $self->ajax_zmenu_id_history_tree_label();
    } elsif( $action eq 'Variation'){
      return $self->ajax_zmenu_variation($panel, $obj);
    } elsif( $action eq 'Variation_transcript'){
      return $self->ajax_zmenu_variation_transcript($panel, $obj);
    } elsif( $action eq 'Transcript_Variation'){
      return $self->_ajax_zmenu_transcript_variation($panel, $obj);
    } elsif( $action eq 'ref'){
      return $self->_ajax_zmenu_change_reference($panel, $obj);  
    } elsif( $action eq 'coverage'){
      return $self->_ajax_zmenu_transcript_coverage($panel, $obj);
    } else {
	my( $disp_id, $X,$Y, $db_label ) = $obj->display_xref;
	$panel->{'caption'} = $disp_id ? "$db_label: $disp_id"
                              : (! $obj->gene ) ? $obj->Obj->stable_id
                              : 'Novel transcript';
	$panel->add_entry({
	    'type'     => 'Transcript',
	    'label'    => $obj->stable_id, 
	    'link'     => $obj->_url({'type'=>'Transcript', 'action'=>'Summary'}),
	    'priority' => 195 
	});
	## Only if there is a gene (not Prediction transcripts)
	if( $obj->gene ) {
	    $panel->add_entry({
		'type'     => 'Gene',
		'label'    => $obj->gene->stable_id,
		'link'     => $obj->_url({'type'=>'Gene', 'action'=>'Summary'}),
		'priority' => 190 
	    });
	}
	$panel->add_entry({
	    'type'     => 'Location',
	    'label'    => sprintf( "%s: %s-%s",
				   $obj->neat_sr_name($obj->seq_region_type,$obj->seq_region_name),
				   $obj->thousandify( $obj->seq_region_start ),
				   $obj->thousandify( $obj->seq_region_end )
			       ),
	    'link'     => $obj->_url({'type'=>'Location', 'action'=>'View', 'r' => $obj->seq_region_name.':'.$obj->seq_region_start.'-'.$obj->seq_region_end })
	});
	$panel->add_entry({
	    'type'     => 'Strand',
	    'label'    => $obj->seq_region_strand < 0 ? 'Reverse' : 'Forward'
	});
	
	$panel->add_entry({
	    'type'     => 'Base pairs',
	    'label'    => $obj->thousandify( $obj->Obj->seq->length ),
	    'priority' => 50
	});


	## Protein coding transcripts only....
	if( $obj->Obj->translation ) {
	    $panel->add_entry({
		'type'     => 'Protein product',
		'label'    => $obj->Obj->translation->stable_id || $obj->Obj->stable_id,
		'link'     => $obj->_url({'type'=>'Transcript', 'action' => 'ProteinSummary'}),
		'priority' => 180
	    });
	    $panel->add_entry({
		'type'     => 'Amino acids',
		'label'    => $obj->thousandify( $obj->Obj->translation->length ),
		'priority' => 40 
	    });
	}
        if( $obj->analysis ) {
          $panel->add_entry({
            'type'     => 'Analysis',
            'label'    => $obj->analysis->display_label,
	    'priority' => 2
          });
          $panel->add_entry({
            'label_html'    => $obj->analysis->description,
	    'priority' => 1
          });
        }
    }
    return;
}

sub _ajax_zmenu_change_reference {
  my $self = shift;
  my $panel = shift;
  my $obj  = $self->object;
  return unless $obj->param('reference');

  
  $panel->add_entry({
    'type'        => 'Click to compare to ', 
    'label_html'  => $obj->param('reference'),
    'link'        => $obj->_url({'action' =>'Population/Image', 'reference' => $obj->param('reference') }), 
    'priority'    => 12,
  });

  return;
}

sub _ajax_zmenu_transcript_variation {
  my $self = shift;
  my $panel = shift;
  my $obj  = $self->object;

  return;
}

sub _ajax_zmenu_transcript_coverage {
  my $self = shift;
  my $panel = shift;
  my $obj  = $self->object;
  return unless $obj->param('disp_level');
  $panel->{'caption'} = "Resequencing read coverage: ". $obj->param('disp_level');
  $panel->add_entry({
      'type'     => 'bp:',
      'label'    => $obj->param('pos'),
      'priority' => 12,
  });
  $panel->add_entry({
      'type'     => 'Sample:',
      'label'    => $obj->param('sp'),
      'priority' => 8,
  });
  $panel->add_entry({
      'type'     => 'Source:',
      'label'    => "Sanger",
      'priority' => 4,
  });

  return; 
}

sub do_SE_align_menu {
    my $self = shift;
    my $panel = shift;
    my $obj  = $self->object;
    my $hit_name   = $obj->param('id');
    my $hit_db = $obj->get_sf_hit_db_name($hit_name);
    my $hit_length = $obj->param('hit_length');
    my $hit_url    = $obj->get_ExtURL_link( $hit_name, $hit_db, $hit_name );
    my $tsid       = $obj->param('t');
    if (my $esid = $obj->param('exon')) {
	my $exon_length = $obj->param('exon_length');
	#this is drawn for exons
	my $align_url = $obj->_url({'type'=>'Transcript', 'action' => 'SupportingEvidence', 'function' => 'Alignment'}).";sequence=$hit_name;exon=$esid";	
	$panel->{'caption'} = "$hit_name ($hit_db)";
	$panel->add_entry({
	    'type'     => 'View alignments',
	    'label'    => "$esid ($tsid)",
	    'link'     => $align_url,
	    'priority' => 180,
	});
	$panel->add_entry({
	    'type'     => 'View record',
	    'label'    => $hit_name,
	    'link'     => $hit_url,
	    'priority' => 100,
	    'extra'    => {'abs_url' => 1},
	});
	$panel->add_entry({
	    'type'     => 'Exon length',
	    'label'    => $exon_length.' bp',
	    'priority' => 50,
	});
	if (my $gap = $obj->param('five_end_mismatch')) {
	    $panel->add_entry({
		'type'     => '5\' mismatch',
		'label'    => $gap.' bp',
		'priority' => 40,
	    });
	}
	if (my $gap = $obj->param('three_end_mismatch')) {
	    $panel->add_entry({
		'type'     => '3\' mismatch',
		'label'    => $gap.' bp',
		'priority' => 35,
	    });
	}
    }
    else {
	$panel->{'caption'} = "$hit_name ($hit_db)";
	$panel->add_entry({
	    'type'     => 'View record',
	    'label'    => $hit_name,
	    'link'     => $hit_url,
	    'priority' => 100,
	    'extra'    => {'abs_url' => 1},
	});
    }
}


## either - prediction transcript or transcript
## domain - domain only (no transcript)
## history - IDHistory object or transcript
## database:variation - Variation database
sub populate_tree {
  my $self = shift;

  $self->create_node( 'Summary', "Transcript summary",
    [qw(image   EnsEMBL::Web::Component::Transcript::TranscriptImage
        summary EnsEMBL::Web::Component::Transcript::TranscriptSummary)],
    { 'availability' => 'either', 'concise' => 'Transcript summary'}
  );

#  $self->create_node( 'Structure', "Transcript Neighbourhood",
#    [qw(neighbourhood EnsEMBL::Web::Component::Transcript::TranscriptNeighbourhood)],
#    { 'availability' => 1}
#  );

  $self->create_node( 'Exons', "Exons  ([[counts::exons]])",
    [qw(exons       EnsEMBL::Web::Component::Transcript::ExonsSpreadsheet)],
    { 'availability' => 'either', 'concise' => 'Exons'}
  );

  my $T = $self->create_node( 'SupportingEvidence', "Supporting evidence  ([[counts::evidence]])",
   [qw(evidence       EnsEMBL::Web::Component::Transcript::SupportingEvidence)],
    { 'availability' => 'transcript', 'concise' => 'Supporting evidence'}
  );
  $T->append($self->create_subnode( 'SupportingEvidence/Alignment', '',
    [qw(alignment      EnsEMBL::Web::Component::Transcript::SupportingEvidenceAlignment)],
    { 'no_menu_entry' => 'transcript' }
  ));

  my $seq_menu = $self->create_submenu( 'Sequence', 'Sequence' );
  $seq_menu->append($self->create_node( 'Sequence_cDNA',  'cDNA',
    [qw(sequence    EnsEMBL::Web::Component::Transcript::TranscriptSeq)],
    { 'availability' => 'either', 'concise' => 'cDNA sequence' }
  ));
  $seq_menu->append($self->create_node( 'Sequence_Protein',  'Protein',
    [qw(sequence    EnsEMBL::Web::Component::Transcript::ProteinSeq)],
    { 'availability' => 'either', 'concise' => 'Protein sequence' }
  ));

  my $record_menu = $self->create_submenu( 'ExternalRecords', 'External References' );

  my $sim_node = $self->create_node( 'Similarity', "Similarity matches  ([[counts::similarity_matches]])",
    [qw(similarity  EnsEMBL::Web::Component::Transcript::SimilarityMatches)],
    { 'availability' => 'transcript', 'concise' => 'Similarity matches'}
  );
  $record_menu->append( $sim_node );
  $sim_node->append($self->create_subnode( 'Similarity/Align', '',
   [qw(alignment       EnsEMBL::Web::Component::Transcript::ExternalRecordAlignment)],
    { 'no_menu_entry' => 'transcript' }
  ));
  $record_menu->append($self->create_node( 'Oligos', "Oligo probes  ([[counts::oligos]])",
    [qw(arrays      EnsEMBL::Web::Component::Transcript::OligoArrays)],
    { 'availability' => 'transcript',  'concise' => 'Oligo probes'}
  ));
  $record_menu->append($self->create_node( 'GO', "Gene ontology  ([[counts::go]])",
    [qw(go          EnsEMBL::Web::Component::Transcript::Go)],
    { 'availability' => 'transcript', 'concise' => 'Gene ontology'}
  ));
  my $var_menu = $self->create_submenu( 'Variation', 'Genetic Variation' );
  $var_menu->append($self->create_node( 'Population',  'Population comparison',
    [qw(snpinfo       EnsEMBL::Web::Component::Transcript::TranscriptSNPInfo 
        snptable      EnsEMBL::Web::Component::Transcript::TranscriptSNPTable)],
    { 'availability' => 'either database:variation' }
  ));
  $var_menu->append($self->create_node( 'Population/Image',  'Comparison image',
    [qw(snps      EnsEMBL::Web::Component::Transcript::SNPView)],
    { 'availability' => 'either database:variation' }
  ));
  my $prot_menu = $self->create_submenu( 'Protein', 'Protein Information' );
  $prot_menu->append($self->create_node( 'ProteinSummary', "Protein summary",
    [qw(image       EnsEMBL::Web::Component::Transcript::TranslationImage
        statistics  EnsEMBL::Web::Component::Transcript::PepStats)],
    { 'availability' => 'either', 'concise' => 'Protein summary'}
  ));
  my $D = $self->create_node( 'Domains', "Domains & features  ([[counts::prot_domains]])",
    [qw(domains     EnsEMBL::Web::Component::Transcript::DomainSpreadsheet)],
    { 'availability' => 'transcript', 'concise' => 'Domains & features'}
  );
  $D->append($self->create_subnode( 'Domains/Genes', 'Genes in domain',
    [qw(domaingenes      EnsEMBL::Web::Component::Transcript::DomainGenes)],
    { 'availability' => 'transcript|domain', 'no_menu_entry' => 1 }
  ));
  $prot_menu->append($D);
  $prot_menu->append($self->create_node( 'ProtVariations', "Variations  ([[counts::prot_variations]])",
    [qw(protvars     EnsEMBL::Web::Component::Transcript::ProteinVariations)],
    { 'availability' => 'either database:variation', 'concise' => 'Variations'}
  ));
  
  # External Data tree, including non-positional DAS sources
  $self->create_node( 'ExternalData', 'External Data',
    [qw(external EnsEMBL::Web::Component::Transcript::ExternalData)],
    { 'availability' => 'transcript' }
  );
  
  my $history_menu = $self->create_submenu('History', "ID History");
  $history_menu->append($self->create_node( 'Idhistory', "Transcript history",
    [qw(
      display     EnsEMBL::Web::Component::Gene::HistoryReport
      associated  EnsEMBL::Web::Component::Gene::HistoryLinked
      map         EnsEMBL::Web::Component::Gene::HistoryMap)],
      { 'availability' => 'history', 'concise' => 'ID History' }
  ));
  $history_menu->append($self->create_node( 'Idhistory/Protein', "Protein history",
    [qw(
      display     EnsEMBL::Web::Component::Gene::HistoryReport/protein
      associated  EnsEMBL::Web::Component::Gene::HistoryLinked/protein
      map         EnsEMBL::Web::Component::Gene::HistoryMap/protein)],
      { 'availability' => 'history', 'concise' => 'ID History' }
  ));
  
  my $export_menu = $self->create_node( 'Export', "Export transcript data",
     [ "sequence", "EnsEMBL::Web::Component::Gene::GeneExport/transcript" ],
     { 'availability' => 'transcript' }
  );
  
  my $format = { fasta => 'FASTA' };
  
  foreach (keys %$format) {
    $export_menu->append($self->create_subnode( "Export/$_", "Export transcript data as $format->{$_}",
      [ "sequence", "EnsEMBL::Web::Component::Gene::GeneExport/transcript_$_" ], # TODO: UNHACK!
      { 'availability' => 'transcript', 'no_menu_entry' => 1 }
    ));
  }
}

sub user_populate_tree {
  my $self = shift;
  my $all_das  = $ENSEMBL_WEB_REGISTRY->get_all_das();
  my @active_das = qw(DS_549);
  my $ext_node = $self->tree->get_node( 'ExternalData' );
  for my $logic_name ( @active_das ) {
    my $source = $all_das->{$logic_name} || next;
    $ext_node->append($self->create_subnode( "ExternalData/$logic_name", $source->label,
      [qw(textdas EnsEMBL::Web::Component::Transcript::TextDAS)],
      { 'availability' => 'translation', 'concise' => $source->caption }
    ));	 
  }
}

# Transcript: BRCA2_HUMAN
# # Summary
# # Exons (28)
# # Peptide product
# # Similarity matches (32)
# # Oligos (25)
# # GO terms (5)
# # Supporting Evidence (40)
# # Variational genomics (123)
# #   Population comparison
# # Marked-up sequence
# #   cDNA (1,853 bps)
# #   Protein (589 aas)
# # ID History
# # Domain information (6)
# # Protein families (1)

1;

