package EnsEMBL::Web::Configuration::Transcript;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Document::Panel::Image;
use EnsEMBL::Web::Data::Release;
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
    if ($dest eq 'SupportingEvidence/Alignment') {
	$self->do_SE_align_menu($panel,$obj);
    } elsif ($dest =~ 'Idhistory_Node'){
      return $self->_ajax_zmenu_id_history_tree_node();
    } elsif ($dest =~ 'Idhistory_Branch'){
      return $self->_ajax_zmenu_id_history_tree_branch();
   } elsif ($dest =~ 'Idhistory_Label'){
      return $self->_ajax_zmenu_id_history_tree_label();
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
		'label'    => $obj->Obj->translation->stable_id || $obj->Obj->stable_id,
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

sub _ajax_zmenu_id_history_tree_node {
  # Specific zmenu for idhistory tree nodes
  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj = $self->object;
  my $a_id = $obj->param('node') || die( "No node value in params" );

  my $db    = $obj->param('db')  || 'core';
  my $db_adaptor = $obj->database($db);
  my $arch_adaptor = $db_adaptor->get_ArchiveStableIdAdaptor;
  my $db_name = $obj->param('db_name');
  my $arch_obj = $arch_adaptor->fetch_by_stable_id_dbname( $a_id, $db_name);
  my $id = $arch_obj->stable_id .".". $arch_obj->version;
  my $type = $arch_obj->type eq 'Translation' ? 'Protein' : $arch_obj->type;
  my $url = $id;
  my $link;
  unless ($arch_obj->release <= $obj->species_defs->EARLIEST_ARCHIVE){ $link = _archive_link($obj, $arch_obj, $obj->species_defs->ENSEMBL_ARCHIVES, $obj->species_defs->ENSEMBL_VERSION); }

  $panel->{'caption'} = $id;

  $panel->add_entry({
    'type'        => $type,
    'label_html'  => $id,
    'link'        => $link,
    'priority'    => 10,
  });
  $panel->add_entry({
    'type'      => 'Release',
    'label'     => $arch_obj->release,
    'priority'  => 9,
  });
  $panel->add_entry({
    'type'      => 'Assembly',
    'label'     => $arch_obj->assembly,
    'priority'  => 8,
  });
  $panel->add_entry({
    'type'      => 'Database',
    'label'     => $arch_obj->db_name,
    'priority'  => 7,
  });

  return;
}

sub _ajax_zmenu_id_history_tree_branch {
  # Specific zmenu for idhistory tree branch lines
  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj = $self->object;
  my $old_id = $obj->param('old') || die( "No old id  value in params" );
  my $new_id = $obj->param('new') || die( "No new id  value in params" );

  my $db    = $obj->param('db')  || 'core';
  my $db_adaptor = $obj->database($db);
  my $arch_adaptor = $db_adaptor->get_ArchiveStableIdAdaptor;

  my $old_arch_obj = $arch_adaptor->fetch_by_stable_id_dbname( $old_id, $obj->param('old_db'));
  my $new_arch_obj = $arch_adaptor->fetch_by_stable_id_dbname( $new_id, $obj->param('new_db') );

  my %types = ( 'Old' => $old_arch_obj, 'New' => $new_arch_obj);
  my $priority = 15;


  $panel->{'caption'} = 'Similarity Match';

  foreach ( sort { $types{$a} <=> $types{$b} } keys %types) {
    my $version = $_;
    my $object = $types{$_};
    my $id = $object->stable_id .".".$object->version;
    my $url = $id;
    my $link;
    unless ($old_arch_obj->release <= $obj->species_defs->EARLIEST_ARCHIVE){ $link = _archive_link($obj, $object); }

    $panel->add_entry({
      'type'        => $version." ".$object->type,
      'label_html'  => $object->stable_id .".".$object->version,
      'link'        => $link,
      'priority'    => $priority,
    });
    $panel->add_entry({
      'type'      => $version." ".'Release',
      'label'     => $object->release,
      'priority'  => $priority--,
    });
    $panel->add_entry({
      'type'      => $version." ".'Assembly',
      'label'     => $object->assembly,
      'priority'  => $priority--,
    });
    $panel->add_entry({
      'type'      => $version." ".'Database',
      'label'     => $object->db_name,
      'priority'  => $priority--,
    });
    $priority--;
  }

  my $score = $obj->param('score');
  if ($score ==0 ){$score = 'Unknown';}
  else { $score = sprintf("%.2f", $score);}

  $panel->add_entry({
      'type'      => 'Score',
      'label'     => $score,
      'priority'  => $priority--,
  });

  return
}

sub _ajax_zmenu_id_history_tree_label {
  # Specific zmenu for idhistory tree feature labels
  my $self = shift; warn $self;
  my $panel = $self->_ajax_zmenu; warn $panel;
  my $obj = $self->object;
  my $id = $obj->param('label') || die( "No label  value in params" );
  my $type = ucfirst($obj->param('feat_type'));
  my ($action, $p);

  if ($type eq 'Gene') {
      $p = 'g';
      $action = 'Idhistory';
    } elsif ($type eq 'Transcript'){
      $p = 't';
      $action = 'Idhistory';
    } else {
      $type = 'Transcript';
      $p = 'p';
      $action = 'Idhistory/Protein';
    }

  my $url = $obj->_url({'type' => $type, 'action' => $action, $p => $id });

  $panel->add_entry({
    'label_html'  => $id,
    'link'        => $url,
    'priority'    => 1,
  });


 return
}

sub _archive_link {
  my ($OBJ, $obj) = @_;

  my $type =  $obj->type eq 'Translation' ? 'peptide' : lc($obj->type);
  my $name = $obj->stable_id . "." . $obj->version;
  my $url;
  my $current =  $OBJ->species_defs->ENSEMBL_VERSION;

  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }

  my ($action, $p);
  ### Set parameters for new style URLs post release 50 
  if ($obj->release >= 51 ){
    if ($type eq 'gene') {
      $type = 'Gene';
      $p = 'g';
      $action = 'Summary';
    } elsif ($type eq 'transcript'){
      $type = 'Transcript';
      $p = 't';
      $action = 'Summary';
    } else {
      $type = 'Transcript';
      $p = 'p';
      $action = 'ProteinSummary';
    }
  }

  if ($obj->release == $current){
     $url = $OBJ->_url({'type' => $type, 'action' => $action, $p => $name });
     return $url;
  } else {
    my $release_info = EnsEMBL::Web::Data::Release->new($obj->release);
    my $archive_site = $release_info->archive;
    $url = "http://$archive_site.archive.ensembl.org";
    if ($obj->release >=51){
      $url .= $OBJ->_url({'type' => $type, 'action' => $action, $p => $name });
    } else {
      $url .= "/".$ENV{'ENSEMBL_SPECIES'};
      $url .= "/$view?$type=$name";
    }
  }  

  return $url;
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

