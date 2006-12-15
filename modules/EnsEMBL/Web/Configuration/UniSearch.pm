package EnsEMBL::Web::Configuration::UniSearch;

use strict;
use EnsEMBL::Web::Configuration;
our @ISA = qw( EnsEMBL::Web::Configuration );
use EnsEMBL::Web::SpeciesDefs;

sub unisearch {
  my $self  = shift;
  my $obj   = $self->{'object'};
  my $results = $obj->Obj;
  $self->set_title( "EnsEMBL UniSearch results" );
  if( my $panel1 = $self->new_panel( '',
    'code'    => "info#",
    'caption' => "Search results for @{[$obj->species]} $results->{idx}"
  )) {
    if( $results->{'q'} ) {
      if( keys %{$results->{'results'}} ) {
        $panel1->add_components(qw(
          results     EnsEMBL::Web::Component::Search::results
        ));
      } else {
        $panel1->add_components(qw(
          results     EnsEMBL::Web::Component::Search::no_results
        ));
      }
    } else {
      $panel1->add_components(qw(
        results     EnsEMBL::Web::Component::Search::search_instructions
      ));
    }
    $self->add_panel( $panel1 );
  }
}

sub context_menu {
  my $self  = shift;
  my $obj   = $self->{'object'};
  our $SD = EnsEMBL::Web::SpeciesDefs->new();
  $self->add_block( 'help' , 'bulleted', 'Searching' );
  if ($SD->ENSEMBL_SITETYPE ne 'Archive EnsEMBL') {
    $self->add_entry( 'help',  'href'=>"/@{[$obj->species]}/blastview", 'text' => 'Sequence search' );
  }
  my $species = $obj->species =~ /^multi$/i ? $obj->species_defs->ENSEMBL_PRIMARY_SPECIES : $obj->species;
  $self->add_entry( 'help',  'href'=>"/$species/unisearch",  'text' => 'Full text search' );
  $self->add_entry( 'help',  'href'=>"/biomart/martview",  'icon' => '/img/biomarticon.gif', 'text' => 'BioMart data mining' );
  return 1;
}
1;
