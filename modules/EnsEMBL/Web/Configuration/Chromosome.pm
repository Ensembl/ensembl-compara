package EnsEMBL::Web::Configuration::Chromosome;

use strict;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Configuration;

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



#-----------------------------------------------------------------------

## Function to configure karyoview

## This is a complex view that steps the user through two configuration
## pages before displaying the user's data on a karyotype

sub karyoview {
  my $self   = shift;

  # this is a three-step view, so we need 3 separate sections
  if (
    ($self->{object}->param('paste_file') || $self->{object}->param('upload_file') || $self->{object}->param('url_file') ) # user input present
    && $self->{object}->param('repeat') ne 'y') 
    { # Step 3 - display user data in required format
    if (my $panel3 = $self->new_panel ('InformationImage',
            'code'    => "info$self->{flag}",
            'caption' => '', 
            'object'  => $self->{object},
        ) ) {
        # do stuff here
        $panel3->add_components(qw(
            image           EnsEMBL::Web::Component::Chromosome::show_karyotype
        ));
        $self->add_panel($panel3);
    }
  }
  elsif ($self->{object}->param('display')) {
    # Step 2 - user has chosen display type
    if (my $panel2 = $self->new_panel ('Image',
        'code'    => "info$self->{flag}",
        'caption' => 'Select display options and data', 
        'object'  => $self->{object},
        ) ) {
        $panel2->add_components(qw(
            image_config           EnsEMBL::Web::Component::Chromosome::image_config
        ));
        ## Add the forms here so we can include JS validation in the page
        $self->add_form( $panel2, qw(image_config     EnsEMBL::Web::Component::Chromosome::image_config_form) );
        $self->add_panel($panel2);
    }
  }
  else {
    # Step 1 - initial page display
    if (my $panel1 =  $self->new_panel('Image',
        'caption' => 'Select a display type', 
        ) ) {
        $panel1->raw_component('EnsEMBL::Web::Component::Chromosome::image_choice');
        $self->add_panel($panel1);
    }
  }
}

#---------------------------------------------------------------------------

# Simple context menu specifically for KaryoView

sub context_karyoview {

  my $self = shift;
  my $species  = $self->{object}->species;
  
  my $flag     = "";
  $self->{page}->menu->add_block( $flag, 'bulleted', "Display your data" );


  $self->{page}->menu->add_entry( $flag, 'text' => "Select a location display",
                                  'href' => "/$species/karyoview?display=location" );
  $self->{page}->menu->add_entry( $flag, 'text' => "Select a density display",
                                  'href' => "/$species/karyoview?display=density" );

}

sub context_menu {
  my $self = shift;
  my $obj      = $self->{object};
  my $species  = $obj->species;
  my $chr_name = $obj->chr_name;
  
  my $flag     = "";
  $self->{page}->menu->add_block( $flag, 'bulleted', "Chromosome $chr_name" );

  # create synteny form if relevant
  my %hash  = $obj->species_defs->multi('SYNTENY');
  my @SPECIES = grep { @{ $obj->species_defs->other_species( $_, 'ENSEMBL_CHROMOSOMES' )||[]} } keys( %hash );
  
  if( $chr_name ) {
    $self->{page}->menu->add_entry( $flag, 'text' => "View @{[$obj->seq_region_type_and_name]}",
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

    $self->{page}->menu->add_entry($flag, 'href' => $array_ref->[0]->{'href'}, 'text'=>"View Chr $chr_name Synteny",
    'options' => $array_ref,
    );

  }

  $self->{page}->menu->add_entry( $flag, 'text' => "Map your data onto this chromosome",
                                  'href' => "/$species/karyoview?chr=$chr_name" );
}

1;
