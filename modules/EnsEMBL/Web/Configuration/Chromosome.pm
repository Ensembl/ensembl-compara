package EnsEMBL::Web::Configuration::Chromosome;

use strict;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Wizard::Chromosome;

our @ISA = qw( EnsEMBL::Web::Configuration );

#-----------------------------------------------------------------------

## Function to configure map view

## MapView uses a single panel to display a chromosome image plus 
## table rows containing basic information and 'navigation' forms

sub mapview {
  my $self   = shift;
  if (my $panel1 = $self->new_panel( 'InformationImage',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    ) ) {
    $panel1->add_components(qw(
        image           EnsEMBL::Web::Component::Chromosome::chr_map
        stats           EnsEMBL::Web::Component::Chromosome::stats
        change_chr      EnsEMBL::Web::Component::Chromosome::change_chr
        jump_to_contig  EnsEMBL::Web::Component::Chromosome::jump_to_contig
    ));
  
    ## Add the forms here so we can include JS validation in the page
    $self->add_form( $panel1, qw(change_chr     EnsEMBL::Web::Component::Chromosome::change_chr_form) );
    $self->add_form( $panel1, qw(jump_to_contig EnsEMBL::Web::Component::Chromosome::jump_to_contig_form) );

    # finally, add the complete panel to the page object
    $self->add_panel( $panel1 );
    $self->{page}->set_title( 'Overview of '.$self->{object}->neat_sr_name(
        $self->{object}->seq_region_type,
        $self->{object}->seq_region_name
    ) );
  }
}

#-----------------------------------------------------------------------
                                                                                
## Function to configure synteny view
                                                                                
## SyntenyView uses a single panel to display a chromosome image plus
## table rows containing basic information and 'navigation' forms
                                                                                
sub syntenyview {
  my $self   = shift;
  if (my $panel1 = $self->new_panel( 'InformationImage',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    ) ) {
       
    $panel1->add_components(qw(
        image           EnsEMBL::Web::Component::Chromosome::synteny_map
        syn_matches     EnsEMBL::Web::Component::Chromosome::syn_matches
        nav_homology    EnsEMBL::Web::Component::Chromosome::nav_homology
        change_chr      EnsEMBL::Web::Component::Chromosome::change_chr
    ));
                                                                                
    ## Add the forms here so we can include JS validation in the page
    $self->add_form( $panel1, qw(change_chr     EnsEMBL::Web::Component::Chromosome::change_chr_form) );
    
    # finally, add the complete panel to the page object
    $self->add_panel( $panel1 );
    $self->initialize_zmenu_javascript;
    $self->{page}->set_title('Synteny');
  }
}



#---------------------------------------------------------------------------

## Configuration for karyoview wizard

sub karyoview {
  my $self   = shift;
  my $object = $self->{'object'};

  $self->initialize_zmenu_javascript;
                                                                                
  ## the "karyoview" wizard uses 5 nodes: add data, check data is present, configure tracks
  ## configure karyotype, and display karyotype
  my $wizard = EnsEMBL::Web::Wizard::Chromosome->new($object);
  $wizard->add_nodes([qw(kv_add kv_datacheck kv_tracks kv_layout kv_display)]);
  $wizard->default_node('kv_add');
                                                                                
  ## chain the static nodes together
  $wizard->chain_nodes([
          ['kv_add'=>'kv_datacheck'],
          ['kv_datacheck'=>'kv_add'],
          ['kv_tracks'=>'kv_layout'],
          ['kv_layout'=>'kv_display'],
          ['kv_display'=>'kv_tracks'],
  ]);
          
  $self->add_wizard($wizard);
  $self->wizard_panel('Karyoview');
}

sub assemblyconverter {
  my $self   = shift;
  my $object = $self->{'object'};

  $self->initialize_zmenu_javascript;
                                                                                
  ## the "assemblyconverter" wizard uses 4 nodes: add data, check data is present, convert features to new assembly
  ## and display preview
  my $wizard = EnsEMBL::Web::Wizard::Chromosome->new($object);
  $wizard->add_nodes([qw(kv_add kv_datacheck ac_convert ac_preview)]);
  $wizard->default_node('kv_add');
                                                                                
  ## chain the static nodes together
  ## NB Unlike karyoview, it doesn't allow upload of multiple files
  $wizard->chain_nodes([
          ['kv_add'=>'kv_datacheck'],
          ['kv_datacheck'=>'ac_convert'],
          ['ac_convert'=>'ac_preview'],
  ]);
          
  $self->add_wizard($wizard);
  $self->wizard_panel('Assembly Converter');
}

#---------------------------------------------------------------------------

# Simple context menu specifically for KaryoView

sub context_karyoview {

  my $self = shift;
  my $species  = $self->{object}->species;
  
  my $flag     = "";
  $self->{page}->menu->add_block( $flag, 'bulleted', "Display your data" );


  $self->{page}->menu->add_entry( $flag, 'text' => "Input new data",
                                  'href' => "/$species/karyoview" );

  $self->{page}->menu->add_entry( $flag, 
    'href'=>"/info/data/external_data/index.html",
    'text'=>'How to upload your data'
  );


}

sub context_menu {
  my $self = shift;
  my $obj      = $self->{object};
  my $species  = $obj->species;
  my $chr_name = $obj->chr_name;
  
  my $flag     = "chromosome";
  $self->{page}->menu->add_block( $flag, 'bulleted', "Chromosome $chr_name" );
  # create synteny form if relevant
  my %hash  = $obj->species_defs->multi('SYNTENY');
  my @SPECIES = grep { @{ $obj->species_defs->other_species( $_, 'ENSEMBL_CHROMOSOMES' )||[]} } keys( %hash );
  if( $chr_name ) {
    $self->{page}->menu->add_entry( $flag, code => 'name', 'text' => "View @{[$obj->seq_region_type_and_name]}",
                                    'href' => "/$species/mapview?chr=$chr_name" );
  }
  if( @SPECIES ){
    my $array_ref; 
    foreach my $next (@SPECIES) {
        my $bio_name = $obj->species_defs->other_species($next, "SPECIES_BIO_NAME");
        my $common_name = $obj->species_defs->other_species($next, "SPECIES_COMMON_NAME");
        my $hash_ref = {'text'=>"vs $common_name (<i>$bio_name</i>)", 'href'=>"/$species/syntenyview?otherspecies=$next;chr=$chr_name", 'raw'=>1} ;
        push (@$array_ref, $hash_ref);
    }

    $self->{page}->menu->add_entry($flag, code => 'syntview', 'href' => $array_ref->[0]->{'href'}, 'text'=>"View Chr $chr_name Synteny",
    'options' => $array_ref,
    );

  }
  $self->{page}->menu->add_entry( $flag, code => 'karview', 'text' => "Map your data onto this chromosome",
                                  'href' => "/$species/karyoview?chr=$chr_name" );
}

1;
