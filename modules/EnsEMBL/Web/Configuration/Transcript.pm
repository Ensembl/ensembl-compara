package EnsEMBL::Web::Configuration::Transcript;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Document::Panel::Image;
use Data::Dumper;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Summary';
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
    if ($dest eq 'SupportingEvidence/Alignment') {
	$self->do_SE_align_menu($panel,$obj);
    } else {
	my( $disp_id, $X,$Y, $db_label ) = $obj->display_xref;
	$panel->{'caption'} = $disp_id ? "$db_label: $disp_id" : 'Novel transcript';
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
		'label'    => $obj->Obj->translation->stable_id,
		'link'     => $obj->_url({'type'=>'Transcript', 'action' => 'Peptide'}),
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

sub do_SE_align_menu {
    my $self = shift;
    my $panel = shift;
    my $obj  = $self->object;
    my $params   = $obj->[1]->{'_input'};
    my $hit_name = $params->{'sequence'}[0];
    my $hit_db   = $params->{'hit_db'}[0];
    my $hit_length = $params->{'hit_length'}[0];
    my $hit_url  = $obj->get_ExtURL_link( $hit_name, $hit_db, $hit_name );

    my $tsid     = $params->{'t'}->[0];
    if (my $esid     = $params->{'exon'}->[0] ) {
	my $exon_length = $params->{'exon_length'}[0];
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
	if (my $gap = $params->{'five_end_mismatch'}[0]) {
	    $panel->add_entry({
		'type'     => '5\' mismatch',
		'label'    => $gap.' bp',
		'priority' => 40,
	    });
	}
	if (my $gap = $params->{'three_end_mismatch'}[0]) {
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

sub populate_tree {
  my $self = shift;

  $self->create_node( 'Summary', "Summary",
    [qw(image   EnsEMBL::Web::Component::Transcript::TranscriptImage
        summary EnsEMBL::Web::Component::Transcript::TranscriptSummary)],
    { 'availability' => 1, 'concise' => 'Transcript summary'}
  );

#  $self->create_node( 'Structure', "Transcript Neighbourhood",
#    [qw(neighbourhood EnsEMBL::Web::Component::Transcript::TranscriptNeighbourhood)],
#    { 'availability' => 1}
#  );

  $self->create_node( 'Exons', "Exons  ([[counts::exons]])",
    [qw(exons       EnsEMBL::Web::Component::Transcript::ExonsSpreadsheet)],
    { 'availability' => 1, 'concise' => 'Exons'}
  );


  my $T = $self->create_node( 'SupportingEvidence', "Supporting evidence  ([[counts::evidence]])",
   [qw(evidence       EnsEMBL::Web::Component::Transcript::SupportingEvidence)],
    { 'availability' => 1, 'concise' => 'Supporting evidence'}
  );
  $T->append($self->create_subnode( 'SupportingEvidence/Alignment', '',
    [qw(alignment      EnsEMBL::Web::Component::Transcript::SupportingEvidenceAlignment)],
    { 'no_menu_entry' => 1 }
  ));

  my $seq_menu = $self->create_submenu( 'Sequence', 'Marked-up sequence' );
  $seq_menu->append($self->create_node( 'Sequence_cDNA',  'cDNA',
    [qw(sequence    EnsEMBL::Web::Component::Transcript::TranscriptSeq)],
    { 'availability' => 1, 'concise' => 'cDNA sequence' }
  ));
  $seq_menu->append($self->create_node( 'Sequence_Protein',  'Protein',
    [qw(sequence    EnsEMBL::Web::Component::Transcript::ProteinSeq)],
    { 'availability' => 1, 'concise' => 'Protein sequence' }
  ));

  my $record_menu = $self->create_submenu( 'ExternalRecords', 'External records' );
  $record_menu->append($self->create_node( 'Similarity', "Similarity matches  ([[counts::similarity_matches]])",
    [qw(similarity  EnsEMBL::Web::Component::Transcript::SimilarityMatches)],
    { 'availability' => 1, 'concise' => 'Similarity matches'}
  ));
  $record_menu->append($self->create_node( 'ExternalRecordAlignment', '',
   [qw(alignment       EnsEMBL::Web::Component::Transcript::ExternalRecordAlignment)],
    { 'no_menu_entry' => 1 }
  ));
  $record_menu->append($self->create_node( 'Oligos', "Oligo matches  ([[counts::oligos]])",
    [qw(arrays      EnsEMBL::Web::Component::Transcript::OligoArrays)],
    { 'availability' => 1,  'concise' => 'Oligo matches'}
  ));

  my $var_menu = $self->create_submenu( 'Variation', 'Variational genomics' );
  $var_menu->append($self->create_node( 'Population',  'Population comparison',
   # [qw(snps      EnsEMBL::Web::Component::Transcript::TranscriptSNPImage
   #     snptable      EnsEMBL::Web::Component::Transcript::TranscriptSNPTable)],
    [qw(snps       EnsEMBL::Web::Component::Transcript::UnderConstruction)], 
    { 'availability' => 'database:variation' }
  ));

  my $prot_menu = $self->create_submenu( 'Protein', 'Protein Information' );
  $prot_menu->append($self->create_node( 'ProteinSummary', "Summary",
    [qw(image       EnsEMBL::Web::Component::Transcript::TranslationImage
        statistics  EnsEMBL::Web::Component::Transcript::PepStats)],
    { 'availability' => 1, 'concise' => 'Protein summary'}
  ));
  my $D = $self->create_node( 'Domains', "Domains  ([[counts::prot_domains]])",
    [qw(domains     EnsEMBL::Web::Component::Transcript::DomainSpreadsheet)],
    { 'availability' => 1, 'concise' => 'Protein domains'}
  );
  $D->append($self->create_subnode( 'Domain/Genes', '',
    [qw(domaingenes      EnsEMBL::Web::Component::Transcript::DomainGenes)],
    { 'no_menu_entry' => 1 }
  ));
  $prot_menu->append($D);
  $prot_menu->append($self->create_node( 'ProtVariations', "Variation features  ([[counts::prot_variations]])",
    [qw(protvars     EnsEMBL::Web::Component::Transcript::ProteinVariations)],
    { 'availability' => 1, 'concise' => 'Protein variation features'}
  ));
  $prot_menu->append($self->create_node( 'GO', "GO terms  ([[counts::go]])",
    [qw(go          EnsEMBL::Web::Component::Transcript::Go)],
    { 'availability' => 1, 'concise' => 'GO terms'}
  ));

  $self->create_node( 'idhistory', "ID history",
    [qw(display     EnsEMBL::Web::Component::Gene::HistoryReport
        associated  EnsEMBL::Web::Component::Gene::HistoryLinked
        map         EnsEMBL::Web::Component::Gene::HistoryMap)],
        { 'availability' => 1, 'concise' => 'ID History' }
  );
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

