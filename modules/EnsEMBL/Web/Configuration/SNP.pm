package EnsEMBL::Web::Configuration::SNP;

use strict;
use EnsEMBL::Web::Configuration;

### Function to configure snp view
our @ISA = qw( EnsEMBL::Web::Configuration );

sub snpview {
  my $self   = shift;
  my $obj    = $self->{'object'};

  my $params = { 'snp' => $obj->name };
     $params->{'c'} =  $obj->param('c') if  $obj->param('c');
     $params->{'w'} =  $obj->param('w') if  $obj->param('w');
     $params->{'source'} =  $obj->param('source') if  $obj->param('source');

  my @params = (
    'object' => $obj,
    'params' => $params
  );

  my $bad_mapping_flag = $obj->seq_region_data ? 0 : 1;
  if ($bad_mapping_flag) {
    my @tmp = ($obj->seq_region_data);
    $bad_mapping_flag = $tmp[3] || "incorrect";
  }

  # Description : prints a two col table with info abou the SNP
  if (my $info_panel = $self->new_panel('Information',
    'code'    => "info$self->{flag}",
    'caption' => 'SNP Report',
				       )) {

    $info_panel->add_components(qw(
    name       EnsEMBL::Web::Component::SNP::name
    synonyms   EnsEMBL::Web::Component::SNP::synonyms
    alleles    EnsEMBL::Web::Component::SNP::alleles
    status     EnsEMBL::Web::Component::SNP::status
    moltype    EnsEMBL::Web::Component::SNP::moltype
    ld_data    EnsEMBL::Web::Component::SNP::ld_data
    seq_region EnsEMBL::Web::Component::SNP::seq_region
				  ));

    $info_panel->remove_component("ld_data") if $bad_mapping_flag;
    $self->{page}->content->add_panel( $info_panel );
  }

  #  Description : genomic location of SNP
  my $caption = $bad_mapping_flag ? " has $bad_mapping_flag mappings" : " is located in the following transcripts";
  if ( my $mapping_panel = $self->new_panel('SpreadSheet',
    'code'    => "mappings $self->{flag}",
    'caption' => "SNP ". $obj->name.$caption,
     @params,
    'status'  => 'panel_locations',
    'null_data' => '<p>No mapping for this SNP. (SNP mappings are removed from Ensembl if none of their alleles match the reference sequence).</p>'
				    )) {
    $mapping_panel->add_components( qw(mappings EnsEMBL::Web::Component::SNP::mappings) );
    $self->{page}->content->add_panel( $mapping_panel );
  }

  return if $bad_mapping_flag;

  # prints a table of variation genotypes, alleles, their Population ids, genotypes, frequencies  etc. in spreadsheet format
if (
 my $frequency_panel = $self->new_panel('SpreadSheet',
    'code'    => "pop frequencies$self->{flag}",
    'caption' => "Population genotypes and allele frequencies",
    @params,
    'status'  => 'panel_frequencies',
    'null_data' => '<p>This SNP has no allele or genotype frequencies per population.</p>'
				      )) {

  $frequency_panel->add_components( qw(all_freqs EnsEMBL::Web::Component::SNP::all_freqs) );
  $self->{page}->content->add_panel( $frequency_panel );
}


  # Description : individual genotypes -----------------------------------
if (
  my $individual_panel = $self->new_panel('SpreadSheet',
    'code'    => "individual $self->{flag}",
    'caption' => "Individual genotypes for SNP ". $obj->name,
     @params,
    'status'  => 'panel_individual',
					 )) {
  $individual_panel->add_components( qw(individual EnsEMBL::Web::Component::SNP::individual) );
  $self->{page}->content->add_panel( $individual_panel );
}

# Neighbourhood image -------------------------------------------------------
  ## Now create the image panel
  my @context = $obj->seq_region_data;
  if (my $image_panel = $self->new_panel('Image',
     'code'    => "image_$self->{flag}",
     'caption' => "SNP Context - $context[-1] $context[0] $context[1]",
     'status'  => 'panel_bottom',  @params,
					)) {

 # Set default sources--------------
 my @sources = keys %{ $obj->species_defs->VARIATION_SOURCES || {} } ;
 my $default_source = $obj->source;  # source of SNP
 my $script_config = $obj->get_scriptconfig();
 my $restore_default = 1;

 $self->update_configs_from_parameter( 'snpview', 'snpview' );
 foreach my $source ( @sources ) {
   $restore_default = 0 if $script_config->get(lc("opt_$source") ) eq 'on';
 }

 if( $restore_default ) { # if none of species' sources are on
   foreach my $source ( @sources ) {
     my $switch;
     if ($default_source) {
       $switch = $source eq $default_source ? 'on' : 'off' ;
     }
     else {
       $switch = 'on';
     }
     $script_config->set(lc("opt_$source"), $switch, 1);
   }
 }#--------- end source


  $self->update_configs_from_parameter( 'snpview', 'snpview' );
  if( $obj->seq_region_data ) {
    ## Initialize the javascript for the zmenus and dropdown menus
    $self->initialize_zmenu_javascript;
    $self->initialize_ddmenu_javascript;

    $image_panel->add_components(qw(
      menu  EnsEMBL::Web::Component::SNP::snpview_image_menu
      image EnsEMBL::Web::Component::SNP::snpview_image
    ));
  } else {
    $image_panel->add_components(qw(
      no_image EnsEMBL::Web::Component::SNP::snpview_noimage
    ));
  }
  $self->{page}->content->add_panel( $image_panel );
}
}

sub context_menu {
  ### SNPview Lefthand side menu bar
  my $self = shift;
  my $obj  = $self->{'object'};
  my $species = $obj->species;
  my $name = $obj->name;
  $self->add_block( "snp$self->{flag}", 'bulleted',
                                  $obj->source.': '.$name );

  my @genes = @{ $obj->get_genes };
  foreach my $gene (@genes) {
	  my $name = scalar @genes > 1 ? $gene->stable_id." -" : "";
	  $self->add_entry(
        "snp$self->{flag}", 
        'code' => 'gene_snp_info',
        'text' => "$name GeneSNP info",
	"title" => "GeneSNPView - SNPs and their coding consequences",
	'href' => "/$species/genesnpview?gene=".$gene->stable_id
    );
  }

  my $snpview_href = "/$species/snpview?snp=$name";
  if ($obj->param('source')) {
    $snpview_href .= ';source='.$obj->param('source');
  }
  $self->add_entry(
        "snp$self->{flag}",
        'code' => 'snp_info',
        'text' => "$name - SNP info",
	"title" => "SNPView",
	'href' => $snpview_href
  );

  if ( $obj->species_defs->VARIATION_LD ) {
    $self->add_entry(
		     "snp$self->{flag}",
		     'code' => 'ld_info',
		     'text' => "$name - LD info",
		     "title" => "Linkage disequilibrium data",
		     'href' => "/$species/ldview?snp=$name"
		    );
  }
  
}


1;
