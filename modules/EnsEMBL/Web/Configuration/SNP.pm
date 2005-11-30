package EnsEMBL::Web::Configuration::SNP;

use strict;
use EnsEMBL::Web::Configuration;

## Function to configure snp view
our @ISA = qw( EnsEMBL::Web::Configuration );

sub snpview {
  my $self   = shift;

  my $params = { 'snp' => $self->{object}->name };
     $params->{'c'} =  $self->{object}->param('c') if  $self->{object}->param('c');
     $params->{'w'} =  $self->{object}->param('w') if  $self->{object}->param('w');
     $params->{'source'} =  $self->{object}->param('source') if  $self->{object}->param('source');
     
  my @params = (
    'object' => $self->{object},
    'params' => $params
  );

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
    tagged_snp EnsEMBL::Web::Component::SNP::tagged_snp
    seq_region EnsEMBL::Web::Component::SNP::seq_region
  ));
  $self->{page}->content->add_panel( $info_panel );
}

# prints a table of variation genotypes, their Population ids, genotypes, frequencies  etc. in spreadsheet format
if (
 my $genotype_panel = $self->new_panel('SpreadSheet',
    'code'    => "pop genotypes$self->{flag}",
    'caption' => "Genotype frequencies per population",
    @params,
    'status'  => 'panel_genotypes',
    'null_data' => '<p>This SNP has not been genotyped</p>'
				      )) {

  $genotype_panel->add_components( qw(genotype_freqs EnsEMBL::Web::Component::SNP::genotype_freqs) );
  $self->{page}->content->add_panel( $genotype_panel );
}

# prints a table of alleles, their Population ids, frequencies as a spreadsheet
if (
 my $allele_panel = $self->new_panel('SpreadSheet',
    'code'    => "pop alleles$self->{flag}",
    'caption' => "Allele frequencies per population",
    @params,
    'status'  => 'panel_alleles',
    'null_data' => '<p>This SNP has not been genotyped</p>'
				    )) {
  $allele_panel->add_components( qw(allele_freqs EnsEMBL::Web::Component::SNP::allele_freqs)  );
  $self->{page}->content->add_panel( $allele_panel );
}

#  Description : genomic location of SNP
if ( 
my $mapping_panel = $self->new_panel('SpreadSheet',
    'code'    => "mappings $self->{flag}",
    'caption' => "SNP ". $self->{object}->name." is located in the following transcripts",
     @params,
    'status'  => 'panel_locations',
    'null_data' => '<p>There are no transcripts that contain this SNP.</p>'
				    )) {
  $mapping_panel->add_components( qw(mappings EnsEMBL::Web::Component::SNP::mappings) );
  $self->{page}->content->add_panel( $mapping_panel );
}

# Neighbourhood image -------------------------------------------------------
  ## Now create the image panel
  my @context = $self->{object}->seq_region_data;
  if (my $image_panel = $self->new_panel('Image',
     'code'    => "image_$self->{flag}",
     'caption' => "SNP Context - $context[-1] $context[0] $context[1]",
     'status'  => 'panel_bottom',  @params,
					)) {

  $self->update_configs_from_parameter( 'snpview', 'snpview' );
  if( $self->{object}->seq_region_data ) {
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
  # Description : individual genotypes -----------------------------------
if (
  my $individual_panel = $self->new_panel('SpreadSheet',
    'code'    => "individual $self->{flag}",
    'caption' => "Individual genotypes for SNP ". $self->{object}->name,
     @params,
    'status'  => 'panel_individual',
					 )) {
  $individual_panel->add_components( qw(individual EnsEMBL::Web::Component::SNP::individual) );
  $self->{page}->content->add_panel( $individual_panel );
}
}

sub context_menu {
  my $self = shift;
  my $obj  = $self->{object};
  my $species = $obj->species;
  my $name = $obj->name;
  my $menu = $self->{page}->menu;
  return unless $menu;
  $menu->add_block( "snp$self->{flag}", 'bulleted',
                                  $obj->source.': '.$name );

  my @genes = @{ $obj->get_genes };
  foreach my $gene (@genes) {
    $menu->add_entry(
        "snp$self->{flag}", 
        'code' => 'gene_snp_info',
        'text' => "Gene SNP info",
	"title" => "GeneSNPView - SNPs and their coding consequences",
	'href' => "/$species/genesnpview?gene=".$gene->stable_id
    );
  }
  
  my $snpview_href = "/$species/snpview?snp=$name";
  if ($self->{object}->param('source')) {
    $snpview_href .= ';source='.$self->{object}->param('source');
  }
  $menu->add_entry(
        "snp$self->{flag}",
        'code' => 'snp_info',
        'text' => "$name - SNP info",
	"title" => "SNPView",
	'href' => $snpview_href
  );
  
  $menu->add_entry(
        "snp$self->{flag}",
        'code' => 'ld_info',
        'text' => "$name - LD info",
	"title" => "Linkage disequilibrium data",
        'href' => "/$species/ldview?snp=$name"
  );

}


1;
