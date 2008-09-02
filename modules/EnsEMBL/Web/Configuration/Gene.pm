package EnsEMBL::Web::Configuration::Gene;

use strict;
use EnsEMBL::Web::RegObj;

use base qw( EnsEMBL::Web::Configuration );

## Function to configure gene snp view

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Summary';
}

sub populate_tree {
  my $self = shift;
#  my $hash = $obj->get_summary_counts;

  $self->create_node( 'Summary', "Gene Summary",
    [qw(summary EnsEMBL::Web::Component::Gene::GeneSummary
        transcripts EnsEMBL::Web::Component::Gene::TranscriptsImage)],
    { 'availability' => 1, 'concise' => 'Summary' }
  );

##----------------------------------------------------------------------
## Compara menu: alignments/orthologs/paralogs/trees
  my $compara_menu = $self->create_submenu( 'Compara', 'Comparative genomics' );
  warn "... $self ... $compara_menu ....";
  $compara_menu->append( $self->create_node( 'Compara_Alignments', "Genomic alignments ([[counts::alignments]])",
    [qw(alignments  EnsEMBL::Web::Component::Gene::UnderConstruction)],
    { 'availability' => 'database:compara', , 'concise' => 'Genomic alignments' }
  ));

## Compara tree
  $compara_menu->append
      ( $self->create_node
        ( 'Compara_Tree', "Gene Tree",
          [qw(image        EnsEMBL::Web::Component::Gene::ComparaTree)],
          { 'availability' => 'database:compara' } ) );

  $compara_menu->append
      ( $self->create_node
        ( 'Compara_Tree_Text', "Gene Tree (text)",
          [qw(treetext        EnsEMBL::Web::Component::Gene::ComparaTreeText)],
          { 'availability' => 'database:compara' } ) );

  $compara_menu->append
      ( $self->create_node
        ( 'Compara_Tree_Align',       "Gene Tree (alignment)",
          [qw(treealign      EnsEMBL::Web::Component::Gene::ComparaTreeAlign)],
          { 'availability' => 'database:compara' } ) );

  $compara_menu->append
      ( $self->create_node
        ( 'Compara_Ortholog',   "Orthologues ([[counts::orthologs]])",
          [qw(orthologues EnsEMBL::Web::Component::Gene::ComparaOrthologs)],
          { 'availability' => 'database:compara', 
            'concise' => 'Orthologues' } ) );

  $compara_menu->append
      ( $self->create_node( 'HomologAlignment', '',
			    [qw(alignment EnsEMBL::Web::Component::Gene::HomologAlignment)],
			    {'no_menu_entry' => 1 }
			));

  $compara_menu->append
      ( $self->create_node
        ( 'Compara_Paralog',    "Paralogues ([[counts::paralogs]])",
          [qw(paralogues  EnsEMBL::Web::Component::Gene::ComparaParalogs)],
          { 'availability' => 'database:compara', 
            'concise' => 'Paralogues' } ) );


=pod
  my $user_menu = $self->create_submenu( 'User', 'User data' );
  $user_menu->append( $self->create_node( 'User_Notes', "User's gene based annotation",
    [qw(manual_annotation EnsEMBL::Web::Component::Gene::UserAnnotation)],
    { 'availability' => 1 }
  ));
=cut


  $self->create_node( 'Splice', "Alternative splicing ([[counts::exons]] exons)",
    [qw(image       EnsEMBL::Web::Component::Gene::GeneSpliceImage)],
    { 'availability' => 1, 'concise' => 'Alternative splicing' }
  );

  $self->create_node( 'Evidence', "Supporting evidence",
     [qw(evidence       EnsEMBL::Web::Component::Gene::SupportingEvidence)],
    { 'availability' => 1, 'concise' => 'Supporting evidence'}
  );

  $self->create_node( 'Sequence', "Marked-up sequence",
     [qw(sequence       EnsEMBL::Web::Component::Gene::GeneSeq)],
    { 'availability' => 1, 'concise' => 'Marked-up sequence'}
  );
  $self->create_node( 'Regulation', 'Regulation',
    [qw(
      regulation EnsEMBL::Web::Component::Gene::RegulationImage
      features EnsEMBL::Web::Component::Gene::RegulationTable
    )],
    { 'availability' => 'database:funcgen' }
  );
  $self->create_node( 'Family', 'Protein families ([[counts::families]])',
    [qw(
      family EnsEMBL::Web::Component::Gene::Family
      genes    EnsEMBL::Web::Component::Gene::FamilyGenes
    )],
    { 'availability' => 1, 'concise' => 'Protein families' }
  );

## Variation tree
  my $var_menu = $self->create_submenu( 'Variation', 'Variational genomics' );
  $var_menu->append($self->create_node( 'Variation_Gene',  'Gene variations',
    [qw(image       EnsEMBL::Web::Component::Gene::GeneSNPImage)],
    { 'availability' => 'database:variation' }
  ));
  $self->create_node( 'Idhistory', 'ID history',
    [qw(display     EnsEMBL::Web::Component::Gene::HistoryReport
        associated  EnsEMBL::Web::Component::Gene::HistoryLinked
        map         EnsEMBL::Web::Component::Gene::HistoryMap)],
        { 'availability' => 1, 'concise' => 'History' }
  );
  $self->create_node( 'Export',  'Export Data', [qw(blank      EnsEMBL::Web::Component:: >>>Location::UnderConstruction)] );
}

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }

sub ajax_zmenu      {
  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj  = $self->object;
  my( $disp_id, $X,$Y, $db_label ) = $obj->display_xref;
  $panel->{'caption'} = $disp_id ? "$db_label: $disp_id" : 'Novel transcript';

  $panel->add_entry({
    'type'     => 'Gene',
    'label'    => $obj->stable_id,
    'link'     => $obj->_url({'type'=>'Gene', 'action'=>'Summary'}),
    'priority' => 195
  });
  $panel->add_entry({
    'type'     => 'Location',
    'label'    => sprintf( "%s: %s-%s",
                    $obj->neat_sr_name($obj->seq_region_type,$obj->seq_region_name),
                    $obj->thousandify( $obj->seq_region_start ),
                    $obj->thousandify( $obj->seq_region_end )
                  ),
    'link' => $obj->_url({'type'=>'Location',   'action'=>'View'   })
  });
  $panel->add_entry({
    'type'     => 'Strand',
    'label'    => $obj->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });

## Protein coding transcripts only....
  return;
}


sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub geneseqview {
  my $self   = shift;
  $self->set_title( "Gene sequence for ".$self->{object}->stable_id );
  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Gene Sequence information for '.$self->{object}->stable_id,
  ) ) {
    $panel1->add_components(qw(
      name           EnsEMBL::Web::Component::Gene::name
      location       EnsEMBL::Web::Component::Gene::location
      markup_options EnsEMBL::Web::Component::Gene::markup_options
      sequence       EnsEMBL::Web::Component::Slice::sequence_display
    ));
    $self->add_panel( $panel1 );
  }
}

sub geneseqalignview {
  my $self   = shift;
  $self->set_title( "Gene sequence for ".$self->{object}->stable_id );
  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Gene Sequence information for '.$self->{object}->stable_id,
  ) ) {
    $panel1->add_components(qw(
      name           EnsEMBL::Web::Component::Gene::name
      location       EnsEMBL::Web::Component::Gene::location
      markup_options EnsEMBL::Web::Component::Gene::markup_options
      sequence       EnsEMBL::Web::Component::Slice::align_sequence_display
    ));
    $self->add_panel( $panel1 );
  }
}


sub sequencealignview {

  ### Calls methods in component to build the page
  ### Returns nothing

  my $self   = shift;
  my $strain =  $self->{object}->species_defs->translate( "strain" );
  $self->set_title( "Gene sequence for ".$self->{object}->stable_id );
  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    #'null_data' => "<p>No $strain data for this gene.</p>",
   'caption' => 'Gene Sequence information for '.$self->{object}->stable_id,
  ) ) {
    $panel1->add_components(qw(
     name           EnsEMBL::Web::Component::Gene::name
      location       EnsEMBL::Web::Component::Gene::location
      markup_options EnsEMBL::Web::Component::Gene::markup_options
      sequence       EnsEMBL::Web::Component::Slice::sequencealignview
    ));
   $self->add_panel( $panel1 );
  }
}


1;
