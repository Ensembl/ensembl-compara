package EnsEMBL::Web::Configuration::Transcript;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Document::Panel::Image;
use Data::Dumper;
use EnsEMBL::Web::Configuration;

@EnsEMBL::Web::Configuration::Transcript::ISA = qw( EnsEMBL::Web::Configuration );

## Function to configure transview

sub exonview {
  my $self   = shift;
  $self->{object}->param( 'oexon', 'no' ) unless $self->{object}->input_param( 'oexon' ) eq 'yes';
  $self->{object}->param( 'fullseq', 'no' ) unless $self->{object}->input_param( 'fullseq' ) eq 'yes';
  my @common = (
    'object' => $self->{object},
    'params' => { 'db' => $self->{object}->get_db, 'transcript' => $self->{object}->stable_id }
  );
  my $panel1 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "info$self->{flag}",
    'caption' => 'Ensembl Exon Report', 
    'object'  => $self->{object}
  );
  $self->add_form( $panel1,
    qw(exonview_options EnsEMBL::Web::Component::Transcript::exonview_options_form)
  );
  $panel1->add_components(qw(
    name        EnsEMBL::Web::Component::Gene::name
    stable_id   EnsEMBL::Web::Component::Gene::stable_id
    information EnsEMBL::Web::Component::Transcript::information
    location    EnsEMBL::Web::Component::Gene::location
    description EnsEMBL::Web::Component::Gene::description
    opts        EnsEMBL::Web::Component::Transcript::exonview_options
  ));
  $self->{page}->content->add_panel( $panel1 );

  my $panel2 = new EnsEMBL::Web::Document::Panel::SpreadSheet(
    'code'    => "exons$self->{flag}",
    'caption' => 'Exon Information',
    @common,
    'status'  => 'panel_exons'
  );
  $panel2->add_components(qw(
    exons       EnsEMBL::Web::Component::Transcript::spreadsheet_exons
  ));
  $self->{page}->content->add_panel( $panel2 );

  my $panel3 = new EnsEMBL::Web::Document::Panel::Image(
    'code'    => "exons$self->{flag}",
    'caption' => 'Supporting Evidence',
    @common,
    'status'  => 'panel_supporting'
  );
  $panel3->add_components(qw(
    image EnsEMBL::Web::Component::Transcript::supporting_evidence_image
  ));
  $self->{page}->content->add_panel( $panel3 );
  $self->{page}->set_title( 'Exon Report for '.$self->{object}->stable_id )
}

sub transview_tn {
  my $self = shift;
  $self->transview();
  if( $self->{object}->Obj->isa('Bio::EnsEMBL::PredictionTranscript') ) {
    if(my $panel = $self->{page}->content->panel("info$self->{flag}")) {
      $panel->add_component_after('interpro', qw(tn_external EnsEMBL::Web::Component::Transcript::tn_external));
    }
  }
}

sub transview {
  my $self   = shift;
  my $panel1 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "info$self->{flag}",
    'caption' => 'Ensembl Transcript Report',
    'object'  => $self->{object}
  );
  $panel1->add_form( $self->{page}, 'markup_up_seq', 'EnsEMBL::Web::Component::Transcript::marked_up_seq_form' );
  $panel1->add_components(qw(
    name        EnsEMBL::Web::Component::Gene::name
    stable_id   EnsEMBL::Web::Component::Gene::stable_id
    information EnsEMBL::Web::Component::Transcript::information
    location    EnsEMBL::Web::Component::Gene::location
    description EnsEMBL::Web::Component::Gene::description
    method      EnsEMBL::Web::Component::Gene::method
    similarity  EnsEMBL::Web::Component::Transcript::similarity_matches
    go          EnsEMBL::Web::Component::Transcript::go
    gkb         EnsEMBL::Web::Component::Transcript::gkb
    interpro    EnsEMBL::Web::Component::Transcript::interpro
    family      EnsEMBL::Web::Component::Transcript::family
    structure   EnsEMBL::Web::Component::Transcript::transcript_structure
    neighbourhood EnsEMBL::Web::Component::Transcript::transcript_neighbourhood
    sequence    EnsEMBL::Web::Component::Transcript::marked_up_seq
  ));
  $self->add_panel( $panel1 );
  $self->initialize_zmenu_javascript;
  $self->set_title( 'Transcript Report for '.$self->{object}->stable_id )
}


sub transcriptsnpview {
 my $self   = shift;
 my $obj    = $self->{'object'};

 # Info panel
 my $panel1 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "info$self->{flag}",
    'caption' => 'Ensembl Transcript Variation Report for '.$obj->stable_id,
    'object'  => $obj,
  );
  $panel1->add_form( $self->{page}, 'markup_up_seq', 'EnsEMBL::Web::Component::Transcript::marked_up_seq_form' );
  $panel1->add_components(qw(
    name        EnsEMBL::Web::Component::Gene::name
    stable_id   EnsEMBL::Web::Component::Gene::stable_id
    location    EnsEMBL::Web::Component::Gene::location
    description EnsEMBL::Web::Component::Gene::description
  ));
  $self->add_panel( $panel1 );
  $self->initialize_zmenu_javascript;
  $self->set_title( 'Transcript SNP Report for '.$obj->stable_id );

 if ( $obj->gene && $obj->gene->length >3000000){
   my $panel_return = new EnsEMBL::Web::Document::Panel(
	  'caption' => 'Exception: for '.$obj->stable_id,
          'object_type' => 'transcript',
     );
   $panel_return->add_components(qw(too_big EnsEMBL::Web::Component::Gene::too_big    ));
   $self->add_panel( $panel_return );
   return 1;
 }

## Panel 2 - the main image on the page showing variations plotted against the exons of the transcript
 # Set default sources
 my @sources = keys %{ $obj->species_defs->VARIATION_SOURCES || {} } ;
 my $default_source = $obj->get_source("default");
 my $script_config = $obj->get_scriptconfig();
 my $restore_default = 1;

 $self->update_configs_from_parameter( 'bottom', qw(TSV_context TSV_sampletranscript TSV_transcript) );
 foreach my $source ( @sources ) {
   # don't restore default if any sources are on
   $restore_default = 0 if $script_config->get(lc("opt_$source") ) eq 'on';
 }

 if( $restore_default && !$obj->param('bottom') ) { # if no spp sources are on
   foreach my $source ( @sources ) {
     my $switch;
     if (0) { # default is all sources on   $default_source) {
       $switch = $source eq $default_source ? 'on' : 'off' ;
     }
     else {
       $switch = 'on';
     }
     $script_config->set(lc("opt_$source"), $switch, 1);
   }
 }
 elsif ($obj->param('bottom')) {
   my $param_sources = join "|" , @sources;
   foreach( split /\|/, ($obj->param('bottom') ) ) {
     next unless $_ =~ /opt_($param_sources):(.*)/i;
     $script_config->set("opt_$1", $2, 1);
   }
   $script_config->save;
 }

 # Need this to make yellow dropdowns work
 # Populations/strains: Read in all in scriptconfig stuff
 my $use_default_strains = 1;
 foreach ($script_config->options) {
   next unless $_ =~ s/opt_pop_//;
   $use_default_strains = 0;
   last;
 }
 $use_default_strains = 1 if $obj->param('default') eq 'populations';

 if( $use_default_strains ) { # if none of species' sources are on
   map { $script_config->delete("opt_pop_$_") }  ($obj->get_samples) ;
 foreach ($script_config->options) {
   next unless $_ =~/anger|db/;
 }
   foreach my $sample ( $obj->get_samples("default") ) {
     $script_config->set("opt_pop_$sample", "on", 1);
   }
 }
 elsif ( $obj->param('bottom') ) {
   foreach( split /\|/, ($obj->param('bottom') ) ) {
     next unless $_ =~ /opt_pop_(.*):(.*)/;
     $script_config->set("opt_pop_$1", $2, 1);
   }
 }
 $script_config->save;

 $self->update_configs_from_parameter( 'bottom', qw(TSV_context TSV_sampletranscript TSV_transcript) );

 my $params = { 'transcript' => $obj->stable_id, 'db' => $obj->get_db  };
 if( my $panel2 = $self->new_panel( 'Image',
    'code'    => "image#",
    'caption' => 'SNPs and variations in region of transcript '.$obj->stable_id,
    'status'  => 'panel_image',
    'params'  => $params
  )) {
    $self->initialize_zmenu_javascript;
    $self->initialize_ddmenu_javascript;


    $panel2->add_components(qw(
      menu   EnsEMBL::Web::Component::Transcript::transcriptsnpview_menu
      image  EnsEMBL::Web::Component::Transcript::transcriptsnpview
     ));
    $self->add_panel( $panel2 );
  }

## Panel 3 - finally a set of spreadsheet tables showing the information from the image..
 my $counts = $obj->__data->{'sample'}{"snp_counts"};

 foreach my $sample ( $obj->get_samples() ) { #e.g. DBA/2J
   last unless $sample;
   last if (defined $counts->[1] && $counts->[1] == 0);
   if( my $panel_table = $self->new_panel( 'SpreadSheet',
      'code' => "variation#-$sample",
      'caption' => "Variations in $sample",
      'status'  => 'panel_sample',
      'object'  => $obj,
      'params'  => $params,
      'sample' =>  $sample,
   #   'null_data' => "<p>Where there is coverage, all alleles <em>observed</em> in sample $sample are the same as the reference.</p>",
 )) {
     $panel_table->add_components( qw(TSVvariations
        EnsEMBL::Web::Component::Transcript::spreadsheet_TSVtable
        ));
     $self->add_panel( $panel_table );
   }
 }


 # Form ---------------------------------------------------------------------
 if (
     my $form_panel = $self->new_panel("",
    'code'    => "info$self->{flag}",
    'caption' => "Dump data",
    'status'  => 'panel_options',
    'params'  => $params,
                                       )) {
    $form_panel->add_components(qw(
    dump  EnsEMBL::Web::Component::Transcript::dump
                                  ));

     $form_panel->add_form( $self->{page}, qw(dump_form EnsEMBL::Web::Component::Transcript::dump_form) );

     # finally, add the complete panel to the page object
     $self->add_panel( $form_panel );
   }

}

sub transcriptsnpdataview {
   my $self = shift;
   my $object = $self->{object};

#  # Description : table of values ------------------------------------
   if (
     my $form_panel = $self->new_panel('',
     'code'    => "info$self->{flag}",
     'caption' => "Variation data for strains on transcript ".$object->stable_id,
     'object'  => $object,
                                 )) {

     if ($self->{object}->param('dump') eq 'ashtml') {
       $form_panel->add_components(qw(
     html_data        EnsEMBL::Web::Component::Transcript::html_dump
                                   ));
     }
     elsif ($self->{object}->param('dump') eq 'astext') {
       $form_panel->add_components(qw(
     text_data        EnsEMBL::Web::Component::Transcript::text_dump
                                   ));
     }
#     elsif ($self->{object}->param('dump') eq 'asexcel') {
#       $form_panel->add_components(qw(
#     excel_data        EnsEMBL::Web::Component::LDtable::excel_data
#                                   ));
#     }
     $self->{page}->content->add_panel( $form_panel );
   }
}

sub context_menu {
  my $self = shift;
  my $obj      = $self->{object};
  my $species  = $obj->species;
  my $script_name = $self->{page}->script_name; 
  my $script = lc($script_name);
  my $q_string_g = $obj->gene ? sprintf( "db=%s;gene=%s" ,       $obj->get_db , $obj->gene->stable_id ) : undef;
  my $q_string   = sprintf( "db=%s;transcript=%s" , $obj->get_db , $obj->stable_id );
  my $flag     = "gene$self->{flag}";
  $self->add_block( $flag, 'bulleted', $obj->stable_id );
  if( $obj->get_db eq 'vega' ) {
    $self->add_entry( $flag,
      'code' => 'vega_link',
      'text'  => "Jump to Vega",
      'icon'  => '/img/vegaicon.gif',
      'title' => 'Vega - Information about transcript '.$obj->stable_id." in Vega $script_name",
      'href' => "http://vega.sanger.ac.uk/$species/$script?transcript=".$obj->stable_id );
  }
  $self->add_entry( $flag,
    'code' => 'gene_info',
    'text' => "Gene information",
    'href' => "/$species/geneview?$q_string_g"
  ) if $q_string_g;
  $self->add_entry( $flag,
    'code' => 'gene_splice_info',
    'text' => "Gene splice site image",
    'href' => "/$species/genespliceview?$q_string_g"
  ) if $q_string_g;


  if ( $obj->species_defs->get_table_size({ -db => 'ENSEMBL_DB', -table => 'regulatory_feature'}) && $obj->gene ) {
    $self->add_entry( $flag,
		      'code'  => 'gene_reg_info',
		      'text'  => "Gene regulation info.",
		      'title' => 'GeneRegulationView - Regulatory factors for this gene'.$obj->stable_id,
		      'href'  => "/$species/generegulationview?$q_string_g" 
		    );
  }

  $self->add_entry( $flag,
    'code' => 'genomic_seq',
    'text' => "Genomic sequence",
    'href' => "/$species/geneseqview?$q_string_g"
  ) if $q_string_g;

  unless ( $obj->get_db eq 'vega' ) {
  # Variation: GeneSNPView
  $self->add_entry( $flag,
    'coed' => 'gene_var_info',
    'text' => "Gene variation info.",
    'href' => "/$species/genesnpview?$q_string_g"
  ) if $obj->species_defs->databases->{'ENSEMBL_VARIATION'} && $q_string_g; 
  }
 $self->add_entry( $flag,
    'code'  => 'id_history',
    'text'  => 'ID history',
    'title' => 'ID history - Transcript stable ID history for'. $obj->stable_id,
    'href'  => "/$species/idhistoryview?$q_string") if $obj->species_defs->get_table_size({-db  => "ENSEMBL_DB", -table => 'gene_archive'});

  # Variation: TranscriptSNP view
  # if meta_key in variation meta table has default strain listed
  if ( $obj->species_defs->VARIATION_STRAIN &&  $obj->get_db ne 'vega' ) { 
    my $strain =  $obj->species_defs->translate( "strain" )."s";
    $self->add_entry( $flag,
		      'code'  => 'TSV',
		      'text'  => "Compare transcript SNPs",
		      'title' => "TranscriptSNPView - Compare variation in different $strain for this transcript ".$obj->stable_id,
		      'href'  => "/$species/transcriptsnpview?$q_string" 
		    );
  }


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
    'text' => "Export transcript data",
    'href' => "/$species/exportview?type1=transcript;anchor1=@{[$obj->stable_id]}"
  );
}

1;

