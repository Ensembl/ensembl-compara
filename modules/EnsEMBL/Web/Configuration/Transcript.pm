package EnsEMBL::Web::Configuration::Transcript;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Document::Panel::Image;
use EnsEMBL::Web::Data::Release;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Configuration);

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
  
  if ($x->{'either'}) {
    $self->{'_data'}->{'default'} = 'Summary';
  } elsif ($x->{'idhistory'}) {
    $self->{'_data'}->{'default'} = 'Idhistory';
  }
}

# either - prediction transcript or transcript
# domain - domain only (no transcript)
# history - IDHistory object or transcript
# database:variation - Variation database
sub populate_tree {
  my $self = shift;

  $self->create_node('Summary', 'Transcript summary',
    [qw(
      image   EnsEMBL::Web::Component::Transcript::TranscriptImage
      summary EnsEMBL::Web::Component::Transcript::TranscriptSummary
    )],
    { 'availability' => 'either', 'concise' => 'Transcript summary' }
  );

  my $T = $self->create_node('SupportingEvidence', 'Supporting evidence ([[counts::evidence]])',
   [qw( evidence EnsEMBL::Web::Component::Transcript::SupportingEvidence )],
    { 'availability' => 'transcript has_evidence', 'concise' => 'Supporting evidence' }
  );
  
  $T->append($self->create_subnode('SupportingEvidence/Alignment', '',
    [qw( alignment EnsEMBL::Web::Component::Transcript::SupportingEvidenceAlignment )],
    { 'no_menu_entry' => 'transcript' }
  ));
  
  my $seq_menu = $self->create_submenu('Sequence', 'Sequence');
  
  $seq_menu->append($self->create_node('Exons', 'Exons ([[counts::exons]])',
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

  my $sim_node = $self->create_node('Similarity', 'General identifiers ([[counts::similarity_matches]])',
    [qw( similarity EnsEMBL::Web::Component::Transcript::SimilarityMatches )],
    { 'availability' => 'transcript has_similarity_matches', 'concise' => 'General identifiers' }
  );
  
  $sim_node->append($self->create_subnode('Similarity/Align', '',
   [qw( alignment EnsEMBL::Web::Component::Transcript::ExternalRecordAlignment )],
    { 'no_menu_entry' => 'transcript' }
  ));
  
  $record_menu->append($sim_node);
  
  $record_menu->append($self->create_node('Oligos', 'Oligo probes ([[counts::oligos]])',
    [qw( arrays EnsEMBL::Web::Component::Transcript::OligoArrays )],
    { 'availability' => 'transcript database:funcgen has_oligos', 'concise' => 'Oligo probes' }
  ));
  
  $record_menu->append($self->create_node('GO', 'Gene ontology ([[counts::go]])',
    [qw( go EnsEMBL::Web::Component::Transcript::Go )],
    { 'availability' => 'transcript has_go', 'concise' => 'Gene ontology' }
  ));
  
  my $var_menu = $self->create_submenu('Variation', 'Genetic Variation');
  
  $var_menu->append($self->create_node('Population', 'Population comparison',
    [qw(
      snptable EnsEMBL::Web::Component::Transcript::TranscriptSNPTable
      snpinfo  EnsEMBL::Web::Component::Transcript::TranscriptSNPInfo
    )],
    { 'availability' => 'strains database:variation' }
  ));
  
  $var_menu->append($self->create_node('Population/Image', 'Comparison image',
    [qw( snps EnsEMBL::Web::Component::Transcript::SNPView )],
    { 'availability' => 'strains database:variation' }
  ));
  
  my $prot_menu = $self->create_submenu('Protein', 'Protein Information');
  
  $prot_menu->append($self->create_node('ProteinSummary', 'Protein summary',
    [qw(
      image      EnsEMBL::Web::Component::Transcript::TranslationImage
      statistics EnsEMBL::Web::Component::Transcript::PepStats
    )],
    { 'availability' => 'either', 'concise' => 'Protein summary' }
  ));
  
  my $D = $self->create_node('Domains', 'Domains & features ([[counts::prot_domains]])',
    [qw( domains EnsEMBL::Web::Component::Transcript::DomainSpreadsheet )],
    { 'availability' => 'transcript has_domains', 'concise' => 'Domains & features' }
  );
  
  $D->append($self->create_subnode('Domains/Genes', 'Genes in domain',
    [qw( domaingenes EnsEMBL::Web::Component::Transcript::DomainGenes )],
    { 'availability' => 'transcript|domain', 'no_menu_entry' => 1 }
  ));
  
  $prot_menu->append($D);
  
  $prot_menu->append($self->create_node('ProtVariations', 'Variations ([[counts::prot_variations]])',
    [qw( protvars EnsEMBL::Web::Component::Transcript::ProteinVariations )],
    { 'availability' => 'either database:variation has_variations', 'concise' => 'Variations' }
  ));
  
  # External Data tree, including non-positional DAS sources
  my $external = $self->create_node('ExternalData', 'External Data',
    [qw( external EnsEMBL::Web::Component::Transcript::ExternalData )],
    { 'availability' => 'transcript' }
  );
  
  if ($self->object->species_defs->ENSEMBL_LOGINS) {
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
      map        EnsEMBL::Web::Component::Gene::HistoryMap
    )],
    { 'availability' => 'history', 'concise' => 'ID History' }
  ));
  
  $history_menu->append($self->create_node('Idhistory/Protein', 'Protein history',
    [qw(
      display    EnsEMBL::Web::Component::Gene::HistoryReport/protein
      associated EnsEMBL::Web::Component::Gene::HistoryLinked/protein
      map        EnsEMBL::Web::Component::Gene::HistoryMap/protein
    )],
    { 'availability' => 'history_protein', 'concise' => 'ID History' }
  ));
  
  $self->create_subnode('Export', '',
    [qw( export EnsEMBL::Web::Component::Export::Transcript )],
    { 'availability' => 'transcript', 'no_menu_entry' => 1 }
  );
}

sub user_populate_tree {
  my $self = shift;
  
  return unless $self->object && ref $self->object;
  
  my $all_das    = $ENSEMBL_WEB_REGISTRY->get_all_das;
  my $vc         = $self->object->get_viewconfig(undef, 'ExternalData');
  my @active_das = grep { $vc->get($_) eq 'yes' && $all_das->{$_} } $vc->options;
  my $ext_node   = $self->tree->get_node('ExternalData');

  for my $logic_name (sort { lc($all_das->{$a}->caption) cmp lc($all_das->{$b}->caption) } @active_das) {
    my $source = $all_das->{$logic_name};
    
    $ext_node->append($self->create_subnode("ExternalData/$logic_name", $source->caption,
      [qw( textdas EnsEMBL::Web::Component::Transcript::TextDAS )],
      { 
        'availability' => 'transcript',
        'concise'      => $source->caption,
        'caption'      => $source->caption,
        'full_caption' => $source->label
      }
    ));
  }
}

sub short_caption {
  my $self = shift;
  my $transcript = $self->model->object('Transcript');
  return 'Transcript-based displays';
}

sub caption {
  my $self = shift;
  my $transcript = $self->model->object('Transcript');
  my ($disp_id) = $transcript->display_xref;
  my $caption = $self->model->hub->species_defs->translate('Transcript') . ': ';
  if ($disp_id) {
    $caption .= "$disp_id (" . $transcript->stable_id . ")";
  } else {
    $caption .= $transcript->stable_id;
  }
  return $caption;
}

sub availability {
  my $self = shift;
  my $hub = $self->model->hub;
  my $transcript = $self->model->object('Transcript');

  if (!$self->{'_availability'}) {
    my $availability = $self->default_availability;
    my $obj = $transcript->Obj;

    if ($obj->isa('EnsEMBL::Web::Fake')) {
      $availability->{$self->feature_type} = 1;
    } elsif ($obj->isa('Bio::EnsEMBL::ArchiveStableId')) {
      $availability->{'history'} = 1;
      my $trans_id = $hub->param('p') || $hub->param('protein');
      my $trans = scalar @{$obj->get_all_translation_archive_ids};
      $availability->{'history_protein'} = 1 if $trans_id || $trans >= 1;
    } elsif( $obj->isa('Bio::EnsEMBL::PredictionTranscript') ) {
      $availability->{'either'} = 1;
    } else {
      my $counts = $self->counts;
      my $rows   = $transcript->table_info($transcript->get_db, 'stable_id_event')->{'rows'};

      $availability->{'history'}         = !!$rows;
      $availability->{'history_protein'} = !!$rows;
      $availability->{'core'}            = $transcript->get_db eq 'core';
      $availability->{'either'}          = 1;      
      $availability->{'transcript'}      = 1;
      $availability->{'domain'}          = 1;
      $availability->{'translation'}     = !!$obj->translation;
      $availability->{'strains'}         = !!$hub->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} if $hub->species_defs->databases->{'DATABASE_VARIATION'};
      $availability->{'history_protein'} = 0 unless $transcript->translation_object;
      $availability->{'has_variations'}  = $counts->{'prot_variations'};
      $availability->{'has_domains'}     = $counts->{'prot_domains'};
      $availability->{"has_$_"}          = $counts->{$_} for qw(exons evidence similarity_matches oligos go);
    }
    $self->{'_availability'} = $availability;
  }
  return $self->{'_availability'};
}

sub counts {
  my $self = shift;
  my $hub = $self->model->hub;
  my $sd = $hub->species_defs;
  my $transcript = $self->model->object('Transcript');

  my $key = sprintf(
    '::COUNTS::TRANSCRIPT::%s::%s::%s::', 
    $hub->species, 
    $hub->core_param('db'), 
    $hub->core_param('t')
  );
  
  my $counts = $self->{'_counts'};
  $counts ||= $hub->cache->get($key) if $hub->cache;

  if (!$counts) {
    return unless $self->model->api_object('Transcript')->isa('Bio::EnsEMBL::Transcript');

    $counts = {
      exons              => scalar @{$transcript->Obj->get_all_Exons},
      evidence           => $transcript->count_supporting_evidence,
      similarity_matches => $transcript->count_similarity_matches,
      oligos             => $transcript->count_oligos,
      prot_domains       => $transcript->count_prot_domains,
      prot_variations    => $transcript->count_prot_variations,
      go                 => $transcript->count_go,
      %{$self->_counts}
    };

    $hub->cache->set($key, $counts, undef, 'COUNTS') if $hub->cache;
    $self->{'_counts'} = $counts;
  }
  return $counts;
}

1;

