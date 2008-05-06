package EnsEMBL::Web::Configuration::Gene;

use strict;

use EnsEMBL::Web::Tools::Ajax;
use EnsEMBL::Web::RegObj;

use base qw( EnsEMBL::Web::Configuration );

## Function to configure gene snp view

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Structure';
}

sub local_context  { $_[0]->_local_context; }

sub populate_tree {
  my $self = shift;
#  my $hash = $obj->get_summary_counts;

  $self->create_node( 'Structure', "Transcripts ([[counts::transcripts]])",
    [qw(transcripts EnsEMBL::Web::Component::Gene::transcript_image)],
    { 'availability' => 1 }
  );
  $self->create_node( 'Splice', "Exons ([[counts::exons]])",
    [qw(menu        EnsEMBL::Web::Component::Gene::genespliceview_menu
       image       EnsEMBL::Web::Component::Gene::genespliceview)],
    { 'availability' => 1 }
  );

##----------------------------------------------------------------------
## Compara menu: alignments/orthologs/paralogs/trees
##----------------------------------------------------------------------
## Compara menu: alignments/orthologs/paralogs/trees
  my $compara_menu = $self->create_submenu( 'Compara', 'Comparative genomics' );
  $compara_menu->append( $self->create_node( 'Compara_Alignments', "Genomic alignments ([[counts::alignments]])",
    [qw(alignments  EnsEMBL::Web::Component::Gene::alignments)],
    { 'availability' => 'database:compara' }
  ));
## Compara tree
  $compara_menu->append( $self->create_node( 'Compara_Ortholog',   "Orthologues ([[counts::orthologs]])",
    [qw(orthologues EnsEMBL::Web::Component::Gene::orthologues)],
    { 'availability' => 'database:compara' }
  ));
  $compara_menu->append( $self->create_node( 'Compara_Paralog',    "Paralogues ([[counts::paralogs]])",
    [qw(paralogues  EnsEMBL::Web::Component::Gene::paralogues)],
    { 'availability' => 'database:compara' }
  ));

  $compara_menu->append( $self->create_node( 'Compara_Tree',       "Gene Trees",
    [qw(menu        EnsEMBL::Web::Component::Gene::genetreeview_menu
      image        EnsEMBL::Web::Component::Gene::genetreeview)],
    { 'availability' => 'database:compara' }
  ));
  my $user_menu = $self->create_submenu( 'User', 'User data' );
  $user_menu->append( $self->create_node( 'User_Notes', "User's gene based annotation",
    [qw(manual_annotation EnsEMBL::Web::Component::Gene::Annotation)],
    { 'availability' => 1 }
  ));
## DAS tree
  $self->create_node( 'Evidence',   'Supporting evidence', [qw()] );
  $self->create_node( 'Regulation', 'Regulation', 
    [qw(regulation EnsEMBL::Web::Component::Gene::regulation_factor)],
    { 'availability' => 'database:funcgen' }
  );
## Variation tree
  my $var_menu = $self->create_submenu( 'Variation', 'Variational genomics' );
  $var_menu->append($self->create_node( 'Variation_Gene',  'Gene variations',
    [qw(menu        EnsEMBL::Web::Component::Gene::genesnpview_menu
        image       EnsEMBL::Web::Component::Gene::genesnpview)],
    { 'availability' => 'database:variation' }
  ));
  $self->create_node( 'Idhistory', 'ID history', [qw()] );
  my $exp_menu = $self->create_submenu( 'Export', 'Export data' );
  $exp_menu->append( $self->create_node( 'Export_Features',  'Features', [qw()] ) );
}

sub global_context {
  my $self = shift;
  return $self->_global_context('Gene');
}

#sub local_context {
#  my $self = shift;
#  my $obj      = $self->{object};
#  my $species  = $obj->species;
#  my $q_string = sprintf( "db=%s;gene=%s" , $obj->get_db , $obj->stable_id );
#  my $flag     = "local#";
#  $self->add_block( $flag, 'bulleted', 'Gene: '.$obj->stable_id );
#  my $P = 0;
#}

sub context_panel {
  my $self   = shift;
  my $obj    = $self->{'object'};
  my $panel  = $self->new_panel( 'Summary', 
    'code'     => 'summary_panel',
    'object'   => $obj,
    'caption'  => "CAPTION:". $obj->core_objects->gene_long_caption
  );
  $panel->add_component( qw(gene_summary EnsEMBL::Web::Component::Gene::Summary) );
  $self->add_panel( $panel );
}

sub content_panel {
  my $self   = shift;
  my $obj    = $self->{'object'};

  my $action = $self->_get_valid_action( $ENV{'ENSEMBL_ACTION'} );
  warn ".... $action ....";
  my $node          = $self->get_node( $action );
  my $previous_node = $node->previous_leaf      ;
  my $next_node     = $node->next_leaf          ;

  my $panel = $self->new_panel( 'Navigation', 
    'object'   => $obj,
    'code'     => 'main',
    'current'  => { 'caption' => $node->data->{'name'} },
    'previous' => { 'caption' => $node->previous_leaf ? $node->previous_leaf->data->{'name'} : undef, 'url' => 'previous' } ,
    'next'     => { 'caption' => $node->next_leaf     ? $node->next_leaf->data->{'name'}     : undef, 'url' => 'next' }
  );
  if( $panel ) {
    $panel->add_components( @{$node->data->{'components'}} );
    $self->add_panel( $panel );
  }
}

sub genesnpview {
  my $self   = shift;
  my $obj    = $self->{'object'};
  $self->set_title( 'Gene Variation Report for '.$obj->stable_id );
  my $params = { 'gene' => $obj->stable_id, 'db' => $obj->get_db  };

## Panel 1 - the gene information table at the top of the page...

  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Ensembl Gene Variation Report for '.$obj->stable_id,
    'params'  => $params
  )) {
    $panel1->add_components(qw(
      name          EnsEMBL::Web::Component::Gene::name
      stable_id     EnsEMBL::Web::Component::Gene::stable_id
      location      EnsEMBL::Web::Component::Gene::location
      description   EnsEMBL::Web::Component::Gene::description
    ));
    $self->add_panel( $panel1 );
  }

  if ( $obj->gene->length >3000000){
    my $panel_return = new EnsEMBL::Web::Document::Panel(
	  'caption' => 'Exception: for '.$obj->stable_id,
          'object_type' => 'gene',
     );
    $panel_return->add_components(qw(too_big EnsEMBL::Web::Component::Gene::too_big    ));
    $self->add_panel( $panel_return );
    return 1;
  }


## Panel 2 - the main image on the page showing variations plotted against the exons of the gene
 # Set default sources
  my @sources = keys %{ $obj->species_defs->VARIATION_SOURCES || {} } ;
  my $default_source = $obj->get_source("default");
  my $script_config = $obj->get_scriptconfig();
  my $restore_default = 1;

  $obj->param('opt_db',$obj->param('db'));
  $self->update_configs_from_parameter( 'bottom','genesnpview_transcript', 'genesnpview_gene', 'genesnpview_context' );
  foreach my $source ( @sources ) {
    $restore_default = 0 if $script_config->get(lc("opt_$source") ) eq 'on';
  }

  if( $restore_default ) { # if none of species' sources are on
    foreach my $source ( @sources ) {
      my $switch = "on";

      # Switch on all by default for GSV
      #if ($default_source) {
      #  $switch = $source eq $default_source ? 'on' : 'off' ;
      #}
      $script_config->set(lc("opt_$source"), $switch, 1);
    }
  }

  $self->update_configs_from_parameter( 'bottom', 'genesnpview_transcript', 'genesnpview_gene', 'genesnpview_context' );

  # Drawing stuff
  if( my $panel2 = $self->new_panel( 'Image',
    'code'    => "image#",
    'caption' => 'SNPs and variations in region of gene '.$obj->stable_id,
    # 'status'  => 'panel_image',
    'params'  => $params
  )) {
    $self->initialize_zmenu_javascript;
    $self->initialize_ddmenu_javascript;
    $panel2->add_components(qw(
      menu   EnsEMBL::Web::Component::Gene::genesnpview_menu
      image  EnsEMBL::Web::Component::Gene::genesnpview
    ));
    $self->add_panel( $panel2 );
  }

## Panel 3 info
 if (my $panel_table_info = $self->new_panel('',
                    'code'    => "instructions",
                    'caption' => "Image data",
                                            )) {
   $panel_table_info->add_components( qw(
          table_info  EnsEMBL::Web::Component::Gene::table_info
                                        ));
   $self->add_panel($panel_table_info);
 }

## Panel 3 - finally a set of spreadsheet tables showing the information from the image..

  my @transcripts = sort{ $a->stable_id cmp $b->stable_id } @{ $self->{object}->get_all_transcripts };
  my $I = 0;
  foreach my $transcript ( @transcripts ) {
    my $tsid = $transcript->stable_id;
    if( my $panel = $self->new_panel( 'SpreadSheet',
      'code' => "variation#-$tsid",
      'caption' => "Variations in $tsid",
      'status'  => 'panel_transcript',
      'object'  => $transcript,
      'params'  => $params
    )) {
      $panel->add_components( qw(variations
        EnsEMBL::Web::Component::Transcript::spreadsheet_variationTable));
      $self->add_panel( $panel );
    }
  }
}

## Function to configure gene regulation view

sub generegulationview {
  my $self   = shift;
  my $obj    = $self->{'object'};
  $self->set_title( 'Gene Regulation Report for '.$obj->stable_id );
  my $params = { 'gene' => $obj->stable_id, 'db' => $obj->get_db  };
  $self->initialize_zmenu_javascript;

  ## Panel 1 - the gene information table at the top of the page...
  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Ensembl Gene Regulation Report for '.$obj->stable_id,
    'params' => $params
  )) {
    $panel1->add_components(qw(
      name          EnsEMBL::Web::Component::Gene::name
      stable_id     EnsEMBL::Web::Component::Gene::stable_id
      location      EnsEMBL::Web::Component::Gene::location
      description   EnsEMBL::Web::Component::Gene::description
      factor        EnsEMBL::Web::Component::Gene::factor
    ));
    $self->add_panel( $panel1 );
  }

  # Structure panel
  if ( my $structure_panel = $self->new_panel( 'Image',
     'code'    => "image_#",
     'caption' => "Gene structure",
     'status'  => 'panel_image',
     'params'  => $params,
                                        )) {
      $structure_panel->add_components(qw(
      structure   EnsEMBL::Web::Component::Gene::gene_structure
				     ));
      $self->{page}->content->add_panel( $structure_panel );
    }


  # Regulatory factor info panel
  if( my $panel2 = $self->new_panel( 'SpreadSheet',
    'code'    => "factors#",
    'status'  => 'panel_regulation_factors',
    'caption' => 'Regulatory factors for '.$obj->stable_id,
    'params' => $params,
  )) {
    $panel2->add_components(qw(
      description   EnsEMBL::Web::Component::Gene::regulation_factors
    ));
    $self->add_panel( $panel2 );
  }
}



## Function to configure gene splice view

sub genespliceview {
  my $self   = shift;
  my $obj    = $self->{'object'};
     $self->update_configs_from_parameter( 'bottom', qw(genesnpview_transcript genesnpview_gene genesnpview_context) );
     $self->set_title( 'Gene Splice Report for '.$obj->stable_id );
  my $params = { 'gene' => $obj->stable_id, 'db' => $obj->get_db  };

## Panel 1 - the gene information table at the top of the page...

  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Ensembl Gene Splice Report for '.$obj->stable_id,
    'params' => $params
  )) {
    $panel1->add_components(qw(
      name          EnsEMBL::Web::Component::Gene::name
      stable_id     EnsEMBL::Web::Component::Gene::stable_id
      location      EnsEMBL::Web::Component::Gene::location
      description   EnsEMBL::Web::Component::Gene::description
    ));
    $self->add_panel( $panel1 );
  }

## Exit panel if gene is too long ...
  if ( $obj->gene->length >3000000){
    my $panel_return = new EnsEMBL::Web::Document::Panel(
	  'caption' => 'Exception: for '.$obj->stable_id,
          'object_type' => 'gene',
     );
    $panel_return->add_components(qw(too_big EnsEMBL::Web::Component::Gene::too_big    ));
    $self->add_panel( $panel_return );
    return 1;
  }

## Panel 2 - the main image on the page showing exons of the gene

  if( my $panel2 = $self->new_panel( 'Image',
    'code'    => "image#",
    'caption' => 'Splice sites for region of gene '.$obj->stable_id,
    'params' => $params
  ) ) {
    $self->initialize_zmenu_javascript;
    $self->initialize_ddmenu_javascript;
    $panel2->add_components(qw(
      menu  EnsEMBL::Web::Component::Gene::genespliceview_menu
      image EnsEMBL::Web::Component::Gene::genespliceview
    ));
    $self->add_panel( $panel2 );
  }
}

sub geneview {
  my $self   = shift;
  my $obj    = $self->{'object'};
     $self->set_title( "Gene report for ".$self->{object}->stable_id );
     $self->update_configs_from_parameter( 'altsplice', 'altsplice' );
     $self->initialize_zmenu_javascript;
     $self->initialize_ddmenu_javascript;
     $self->{page}->add_body_attr( 'onload' => 'populate_info_fragments(); ');
     $self->{page}->javascript->add_source("/js/ajax_fragment.js");

  my $params = { 'gene' => $obj->stable_id, 'db' => $obj->get_db  };



## Panel 1 - the gene information table at the top of the page...

  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#", 'caption' => 'Ensembl Gene Report for [[object->stable_id]]', 'params' => $params, 'status'  => 'panel_gene'
  ) ) {
    $panel1->add_components(qw(
      name          EnsEMBL::Web::Component::Gene::name
      stable_id     EnsEMBL::Web::Component::Gene::stable_id
      location      EnsEMBL::Web::Component::Gene::location
      description   EnsEMBL::Web::Component::Gene::description
      method        EnsEMBL::Web::Component::Gene::method
      transcripts   EnsEMBL::Web::Component::Gene::transcripts
      alignments    EnsEMBL::Web::Component::Gene::alignments
      orthologues   EnsEMBL::Web::Component::Gene::orthologues
      paralogues    EnsEMBL::Web::Component::Gene::paralogues
      diseases      EnsEMBL::Web::Component::Gene::diseases
    ));
	if ($obj->get_db eq 'vega') {
	   $panel1->add_component_after(qw(
	     stable_id author EnsEMBL::Web::Component::Gene::author
	   ));
	   $panel1->add_component_after(qw(
	     author type EnsEMBL::Web::Component::Gene::type
	   ));
	   $panel1->add_component_after(qw(
	     location version_and_date  EnsEMBL::Web::Component::Gene::version_and_date
       ));
    }
    if (EnsEMBL::Web::Tools::Ajax::is_enabled()) {
      $panel1->load_asynchronously('transcripts');
    }
    $self->add_panel( $panel1 );
  }

## Bonus Panel - user annotations 

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  if ($user) {

    if( my $annotation_panel = $self->new_panel( 
                                     'Information',
                                     'code'    => "dasinfo#",
                                     'caption' => 'Notes',
                                     'params' => $params,
                                     'status'  => 'panel_annotation') )
    {
      $annotation_panel->add_components(qw(
        user_notes        EnsEMBL::Web::Component::Gene::user_notes
        group_notes        EnsEMBL::Web::Component::Gene::group_notes
      ));
      $self->add_panel($annotation_panel);
    }

  }

## Panel 2 - DAS configuration panel...

  if( my $panel2 = $self->new_panel( 'Information',
    'code'    => "dasinfo#", 'caption' => 'Gene DAS Report', 'params' => $params, 'status'  => 'panel_das'
  ) ) {
    $panel2->add_components(qw(
      das           EnsEMBL::Web::Component::Translation::das
    ));
    $self->add_panel( $panel2 );
  }
  my @transcripts = sort { $a->stable_id cmp $b->stable_id } @{ $self->{object}->get_all_transcripts };
  my $I = 0;

## Panel 3 - finally a set of info panels showing the information from about the transcripts

  foreach my $transcript ( @transcripts ) { 
    if( my $panel = $self->new_panel( 'Information',
      'code'    => "trans#-".$transcript->stable_id,
      'caption' => "Transcript ".$transcript->stable_id,
      'object'  => $transcript,
      'params'  => $params,
      'status'  => 'panel_transcript'
    ) ) {
      $panel->add_components(qw(
        name        EnsEMBL::Web::Component::Gene::name
        proteininfo EnsEMBL::Web::Component::Transcript::additional_info
        alternative EnsEMBL::Web::Component::Transcript::alternative_transcripts
        similarity  EnsEMBL::Web::Component::Transcript::similarity_matches
        arrays      EnsEMBL::Web::Component::Transcript::oligo_arrays
        literature  EnsEMBL::Web::Component::Transcript::literature
        go          EnsEMBL::Web::Component::Transcript::go
        gkb         EnsEMBL::Web::Component::Transcript::gkb
        intepro     EnsEMBL::Web::Component::Transcript::interpro
        family      EnsEMBL::Web::Component::Transcript::family
        trans_image EnsEMBL::Web::Component::Transcript::transcript_structure
        prot_image  EnsEMBL::Web::Component::Transcript::protein_features_geneview
      ));
	  if ($obj->get_db eq 'vega') {
		$panel->remove_component('similarity');
	    $panel->add_component_after(qw(
	      proteininfo class EnsEMBL::Web::Component::Transcript::class
       ));
      }
      $self->add_panel( $panel ); 
    }
  }
}

sub geneseqview {
  my $self   = shift;
  $self->set_title( "Gene sequence for ".$self->{object}->stable_id );
  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Gene Sequence information for '.$self->{object}->stable_id,
  ) ) {
    $self->add_form( $panel1,
      qw(markup_options EnsEMBL::Web::Component::Gene::markup_options_form)
    );
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
    $self->add_form( $panel1,
      qw(markup_options EnsEMBL::Web::Component::Gene::align_markup_options_form)
    );
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
    $self->add_form( $panel1,
      qw(markup_options EnsEMBL::Web::Component::Gene::sequence_markup_options_form)
    );
    $panel1->add_components(qw(
     name           EnsEMBL::Web::Component::Gene::name
      location       EnsEMBL::Web::Component::Gene::location
      markup_options EnsEMBL::Web::Component::Gene::markup_options
      sequence       EnsEMBL::Web::Component::Slice::sequencealignview
    ));
   $self->add_panel( $panel1 );
  }
}


###############################################################################
sub context_menu {
  my $self = shift;
  my $obj      = $self->{object};
  my $species  = $obj->species;
  my $q_string = sprintf( "db=%s;gene=%s" , $obj->get_db , $obj->stable_id );
  my $flag     = "gene#";
  $self->add_block( $flag, 'bulleted', $obj->stable_id );
  if( $obj->get_db eq 'vega' ) {
    $self->add_entry( $flag,
	  'code'  => 'vega_link',
      'text'  => "Jump to Vega",
      'icon'  => '/img/vegaicon.gif',
      'title' => 'Vega - Information about gene '.$obj->stable_id.' in Vega',
      'href' => "http://vega.sanger.ac.uk/$species/geneview?gene=".$obj->stable_id );
  }
  $self->add_entry( $flag,
	'code'  => "gene_info",
    'text'  => "Gene information",
    'title' => 'GeneView - Information about gene '.$obj->stable_id,
    'href'  => "/$species/geneview?$q_string" );

 $self->add_entry( $flag,
    'code'  => 'gene_reg_info',
    'text'  => "Gene regulation info.",
    'title' => 'GeneRegulationView - Regulatory factors for this gene'.$obj->stable_id,
    'href'  => "/$species/generegulationview?$q_string"
  ) if $obj->species_defs->get_table_size({ -db => 'ENSEMBL_FUNCGEN', -table => 'feature_set'}) && $obj->gene;

  $self->add_entry( $flag,
    'code'  => 'genomic_seq',
    'text'  => "Genomic sequence",
    'title' => 'GeneSeqView - View marked up sequence of gene '.$obj->stable_id,
    'href'  => "/$species/geneseqview?$q_string" );

  if ($obj->get_db eq 'core' ) {
    $self->add_entry( $flag,
		      'code'  => 'genomic_seq_align',
		      'text'  => "Genomic sequence alignment",
		      'title' => 'GeneSeqAlignView - View marked up sequence of gene '.$obj->stable_id.' aligned to other species',
		      'href'  => "/$species/geneseqalignview?$q_string" );

    if( $species =~ /^(Homo_sapiens|Mus_musculus|Rattus_norvegicus)$/ && $obj->species_defs->VARIATION_SOURCES ) {
      $self->add_entry( $flag,
						'code' => 'reseq_align',
						'text' => 'Resequencing alignment',
						'title' => "SequenceAlignView",
						'href' => "/$species/sequencealignview?$q_string" );
    }

    $self->add_entry( $flag,
		      'code'  => 'gene_splice_info',
		      'text'  => "Gene splice site image",
		      'title' => 'GeneSpliceView - Graphical diagram of alternative splicing of '.$obj->stable_id,
		      'href'  => "/$species/genespliceview?$q_string" );

    $self->add_entry( $flag,
		      'code'  => 'genetree',
		      'text'  => "Gene tree info.",
		      'title' => 'GeneTreeView - View graphic display of the gene tree for gene '.$obj->stable_id,
		      'href'  => "/$species/genetreeview?$q_string" );

    $self->add_entry( $flag,
		      'code'  => 'gene_var_info',
		      'text'  => "Gene variation info.",
		      'title' => 'GeneSNPView - View of consequences of variations on gene '.$obj->stable_id,
		      'href'  => "/$species/genesnpview?$q_string" ) if $obj->species_defs->databases->{'ENSEMBL_VARIATION'};
 
    $self->add_entry($flag,
                     'code'   => 'ld_info',
                     'text'   => 'LD info',
                     'title'  => 'Linkage disequilibrium data',
                     'href'    => "/$species/ldview?$q_string",) if $obj->species_defs->VARIATION_LD;

    $self->add_entry( $flag,
		      'code'  => 'id_history',
		      'text'  => 'ID history',
		      'title' => 'ID history - Gene stable ID history for'. $obj->stable_id,
		      'href'  => "/$species/idhistoryview?$q_string") if $obj->species_defs->get_table_size({-db  => "ENSEMBL_DB", -table => 'gene_archive'});
  }
  my @transcripts = 
      map { {
        'href'  => sprintf( '/%s/transview?db=%s;transcript=%s', $species, $obj->get_db, $_->stable_id ),
        'title' => "TransView - Detailed information about transcript ".$_->stable_id,
        'text'  => $_->stable_id
      } } sort{ $a->stable_id cmp $b->stable_id } @{ $obj->get_all_transcripts };

  if( @transcripts ) {

    # Variation: TranscriptSNP view
    # if meta_key in variation meta table has default strain listed
    if ( $obj->species_defs->VARIATION_STRAIN &&  $obj->get_db eq 'core'  ) { 
      my $strain =  $obj->species_defs->translate( "strain" )."s";
      # Transcript SNP View
      my @sample_links =
	map { {
	  'href'    => sprintf( '/%s/transcriptsnpview?db=%s;transcript=%s', $species, $obj->get_db, $_->stable_id ),
	    'text'  => $_->stable_id,
	  }} sort{ $a->stable_id cmp $b->stable_id } @{ $obj->get_all_transcripts };

      $self->add_entry( $flag,
			'code'  => 'compare_samples',
			'text'  => "Compare SNPs in transcript",
			'title' => "TranscriptSNP View - Compare transcript variation in different $strain",
			'href'  => $sample_links[0]{'href'},
			'options' => \@sample_links,
		      );
    }

    $self->add_entry( $flag,
		      'code'  => 'trans_info',
		      'text'  => "Transcript information",
		      'title' => "TransView - Detailed transcript information",
		      'href'  => $transcripts[0]{'href'},
		      'options' => \@transcripts
		    );


    my @exons = ();
    foreach( @transcripts ) { 
      push @exons, {
        'href'  => sprintf( '/%s/exonview?db=%s;transcript=%s', $species, $obj->get_db, $_->{'text'} ),
        'title' => "ExonView - Detailed exon information about transcript ".$_->{'text'},
        'text'  => $_->{'text'} };
    }
    $self->add_entry( $flag,
      'code'  => 'exon_info',
      'text'  => "Exon information",
      'href'  => $exons[0]{'href'},
      'title' => "ExonView - Detailed exon information",
      'options' => \@exons
    );
    my @peptides = 
      map { {
        'href' => sprintf( '/%s/protview?db=%s;peptide=%s', $species, $obj->get_db, $_->stable_id ),
        'title' => "ProtView - Detailed information about peptide ".$_->stable_id,
        'text' => $_->stable_id
      } }
      sort { $a->stable_id cmp $b->stable_id }
      map  { $_->translation_object ? $_->translation_object : () }
        @{ $obj->get_all_transcripts };
    if( @peptides ) {
      $self->add_entry( $flag,
        'code'  => 'pep_info', 
        'text'  => "Protein information",
        'href'  => $peptides[0]{'href'},
        'title' => 'ProtView - Detailed peptide information',
        'options' => \@peptides
      );
    }
  }
  $self->add_entry( $flag,
    'code'  => 'exp_data',
    'text'  => "Export gene data",
    'title' => "ExportView - Export information about gene ".$obj->stable_id,
    'href'  => "/$species/exportview?type1=gene;anchor1=@{[$obj->stable_id]}"
  );
}

sub genetreeview {
  my $self   = shift;
  my $obj    = $self->{'object'};
  
  $self->update_configs_from_parameter('image', qw(genetreeview genetreeview) );
  $self->set_title( 'Gene Tree for '.$obj->stable_id );
  my $params = { 'gene' => $obj->stable_id, 'db' => $obj->get_db  };

  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Gene information',
  ) ) {
    $panel1->add_components(qw(
      name           EnsEMBL::Web::Component::Gene::name
      stable_id      EnsEMBL::Web::Component::Gene::stable_id
      location       EnsEMBL::Web::Component::Gene::location
      description   EnsEMBL::Web::Component::Gene::description
      external_links EnsEMBL::Web::Component::Gene::external_links
     ));
    $self->add_panel( $panel1 );

  }

  ## Does this gene have orthologues from which we can build a tree?
  my @keys_orth = keys %{$obj->get_homology_matches('ENSEMBL_ORTHOLOGUES', 'ortholog')};
  my @keys_para = keys %{$obj->get_homology_matches('ENSEMBL_PARALOGUES',  'paralog')};
  if (@keys_orth || @keys_para) {
    if( my $panel2 = $self->new_panel( 'Image',
      'code'    => "image#",
      'caption' => 'Gene Tree for gene '.$obj->stable_id,
      'params' => $params
      ) ) {
      $self->initialize_zmenu_javascript;
      $self->initialize_ddmenu_javascript;
      $panel2->add_components(qw(
        menu  EnsEMBL::Web::Component::Gene::genetreeview_menu
        image EnsEMBL::Web::Component::Gene::genetreeview
      ));
      $self->add_panel( $panel2 );
    }
    if(@keys_orth) {
      if( my $panel3 = $self->new_panel( 'Information',
        'code'    => "orth#",
        'caption' => 'Gene Orthologues',
        ) ) {
        $panel3->add_components(qw(
          orthologues    EnsEMBL::Web::Component::Gene::orthologues
        ));
        $self->add_panel( $panel3 );
      }
    }
    if(@keys_para) {
      if( my $panel4 = $self->new_panel( 'Information',
        'code'    => "para#",
        'caption' => 'Gene Paralogues',
        ) ) {
        $panel4->add_components(qw(
          paralogues    EnsEMBL::Web::Component::Gene::paralogues
        ));
        $self->add_panel( $panel4 );
      }
    }
  } else {
    if( my $panel2 = $self->new_panel( 'Image',
      'code'    => "image#",
      'caption' => 'Gene Tree for gene '.$obj->stable_id,
      'params' => $params
      ) ) {
      $panel2->add_components(qw(
        notree  EnsEMBL::Web::Component::Gene::nogenetree
      ));
      $self->add_panel( $panel2 );
    }
  }
}

1;
