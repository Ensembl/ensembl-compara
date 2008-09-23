package EnsEMBL::Web::Configuration::Translation;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;

use EnsEMBL::Web::Configuration;

@EnsEMBL::Web::Configuration::Translation::ISA = qw( EnsEMBL::Web::Configuration );

## Function to configure protview

sub protview {
  my $self   = shift;
  my $obj    = $self->{object};
  my $params =  { 'db'     => $obj->get_db };
  $self->update_configs_from_parameter( 'protview', 'protview' );
  if( $obj->stable_id ) {
    $params->{'peptide'} = $obj->stable_id;
  } else {
    $params->{'transcript'} = $obj->transcript->stable_id;
  }
  my @common = ( 'object' => $obj, 'params' => $params );

  my $daspanel = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "dasinfo$self->{flag}",
    'caption' => 'Protein DAS Report', 
    @common,
    'object'  => $obj,
    'status'  => 'panel_das'
  );

  $daspanel->add_components(qw(
    das           EnsEMBL::Web::Component::Translation::das
  ));

  my $panel1 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "info$self->{flag}",
    'caption' => 'Ensembl Protein Report', 
    'object'  => $obj
  );
  $panel1->add_form( $self->{page}, 'markup_up_seq', 'EnsEMBL::Web::Component::Translation::marked_up_seq_form' );
  $self->initialize_zmenu_javascript;
  $panel1->add_components(qw(
    name        EnsEMBL::Web::Component::Gene::name
    stable_id   EnsEMBL::Web::Component::Gene::stable_id
    information EnsEMBL::Web::Component::Translation::information
    location    EnsEMBL::Web::Component::Gene::location
    description EnsEMBL::Web::Component::Gene::description
    method      EnsEMBL::Web::Component::Gene::method
    interpro    EnsEMBL::Web::Component::Transcript::interpro
    family      EnsEMBL::Web::Component::Transcript::family
    image       EnsEMBL::Web::Component::Translation::image
    sequence    EnsEMBL::Web::Component::Translation::marked_up_seq
    statistics  EnsEMBL::Web::Component::Translation::pep_stats
  ));
  $self->{page}->content->add_panel( $panel1 );

  $self->{page}->content->add_panel( $daspanel );

  if( $obj->stable_id ) {
  my $panel2 = new EnsEMBL::Web::Document::Panel::SpreadSheet( 
    'code'    => 'domain_panel',
    'caption' => 'Domains on '.($obj->stable_id || $obj->transcript->stable_id),
    @common,
    'status'  => 'panel_domain',
    'null_data' => "<p>No domains on this peptide</p>"
  );
  $panel2->add_components( qw(domains EnsEMBL::Web::Component::Translation::domain_list) );
  $self->{page}->content->add_panel( $panel2 );

  my $panel2a = new EnsEMBL::Web::Document::Panel::SpreadSheet(
    'code'    => 'other_panel',
    'caption' => 'Other features on '.($obj->stable_id || $obj->transcript->stable_id),
    @common,
    'status'  => 'panel_other',
    'null_data' => "<p>No other features on this peptide</p>"
  );
  $panel2a->add_components( qw(others EnsEMBL::Web::Component::Translation::other_feature_list) );
  $self->{page}->content->add_panel( $panel2a );
  }
  my $panel3 = new EnsEMBL::Web::Document::Panel::SpreadSheet( 
    'code'    => 'variation_panel',
    'caption' => 'Variations on '.($obj->stable_id || $obj->transcript->stable_id),
    @common,
    'status'  => 'panel_variation'
  );

  $panel3->add_components( qw(snp_list EnsEMBL::Web::Component::Translation::snp_list) );
  $self->{page}->content->add_panel( $panel3 );
  $self->{page}->set_title( 'Peptide Report for '.$obj->stable_id );
}

sub context_menu {
  my $self = shift;
  my $obj      = $self->{object};
  my $species  = $obj->species;
  my $q_string_g = $obj->gene ? sprintf( "db=%s;gene=%s" ,       $obj->get_db , $obj->gene->stable_id ) : undef; 
  my $q_string   = $obj->stable_id ?
    sprintf( "db=%s;peptide=%s" , $obj->get_db , $obj->stable_id ) :
    sprintf( "db=%s;transcript=%s", $obj->get_db, $obj->transcript->stable_id );
  my $flag     = "gene$self->{flag}";
  $self->{page}->menu->add_block( $flag, 'bulleted', $obj->stable_id || $obj->transcript->stable_id);
  if( $obj->get_db eq 'vega' ) {
    $self->add_entry( $flag,
      'code' => 'vega_link',
      'text'  => "Jump to Vega",
      'icon'  => '/img/vegaicon.gif',
      'title' => 'Vega - Information about peptide '.$obj->stable_id.' in Vega',
      'href' => "http://vega.sanger.ac.uk/$species/protview?peptide=".$obj->stable_id );
  }

  $self->add_entry( $flag,
    'code' => 'gene_info',
    'text' => "Gene information",
    'href' => "/$species/geneview?$q_string_g"
  ) if $q_string_g;

  $self->add_entry( $flag,
    'code'  => 'gene_reg_info',
    'text'  => "Gene regulation info.",
    'title' => 'GeneRegulationView - Regulatory factors for this gene'.$obj->stable_id,
    'href'  => "/$species/generegulationview?$q_string_g" 
  ) if $obj->species_defs->get_table_size({ -db => 'DATABASE_CORE', -table => 'regulatory_feature'}) && $obj->gene;

  if ( $q_string_g && $obj->get_db eq 'core' ) {
   $self->add_entry( $flag,
		      'code'  => 'genomic_seq_align',
		      'text'  => "Genomic sequence alignment",
		      'title' => 'GeneSeqAlignView - View marked up sequence of gene '.$obj->stable_id.' aligned to other species',
		      'href'  => "/$species/geneseqalignview?$q_string" );

    $self->add_entry( $flag,
		      'code'  => 'gene_splice_info',
		      'text'  => "Gene splice site image",
		      'title' => 'GeneSpliceView - Graphical diagram of alternative splicing of '.$obj->stable_id,
		      'href'  => "/$species/genespliceview?$q_string" );

    $self->add_entry( $flag,
		      'code'  => 'genetree',
		      'text'  => "Gene tree info",
		      'title' => 'GeneTreeView - View graphic display of the gene tree for gene '.$obj->stable_id,
		      'href'  => "/$species/genetreeview?$q_string" );

    $self->add_entry( $flag,
		      'coed' => 'gene_var_info',
		      'text' => "Gene variation info.",
		      'href' => "/$species/genesnpview?$q_string_g"
		    ) if $obj->species_defs->databases->{'DATABASE_VARIATION'};

    $self->add_entry( $flag,
		      'code'  => 'id_history',
		      'text'  => 'ID history',
		      'title' => 'ID history - Protein stable ID history for'. $obj->stable_id,
		      'href'  => "/$species/idhistoryview?$q_string") if $obj->species_defs->get_table_size({-db  => "DATABASE_CORE", -table => 'gene_archive'});
  }

  $self->add_entry( $flag,
    'code' => 'genomic_seq',
    'text' => "Genomic sequence",
    'href' => "/$species/geneseqview?$q_string_g"
  ) if $q_string_g;

  $self->add_entry( $flag,
    'code' => 'trans_info',
    'text' => "Transcript information",
    'href' => "/$species/transview?$q_string"
  );
  $self->add_entry( $flag,
    'code' => 'exon_info',
    'text' => "Exon information",
    'href' => "/$species/exonview?$q_string"
  );
  $self->add_entry( $flag,
    'code' => 'pep_info',
    'text' => 'Protein information',
    'href' => "/$species/protview?$q_string"
  ) if $obj->translation_object;
  $self->add_entry( $flag,
    'code' => 'exp_data',
    'text' => "Export protein data",
    'href' => "/$species/exportview?type1=peptide;anchor1=@{[$obj->stable_id]}"
  ) if $obj->stable_id;
}

1;
