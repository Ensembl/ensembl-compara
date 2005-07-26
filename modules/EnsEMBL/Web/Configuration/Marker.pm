package EnsEMBL::Web::Configuration::Marker;

use strict;
use EnsEMBL::Web::Configuration;

## Function to configure marker view
our @ISA = qw( EnsEMBL::Web::Configuration );

sub markerview {
  my $self   = shift;
  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info$self->{flag}",
    'caption' => 'Chromosome Map Marker [[object->name]]',
  )) {
    $panel1->add_components(qw(
      name     EnsEMBL::Web::Component::Marker::name
      location EnsEMBL::Web::Component::Marker::location
      synonyms EnsEMBL::Web::Component::Marker::synonyms
      primers  EnsEMBL::Web::Component::Marker::primers
    ));
    $self->add_panel( $panel1 );
  }
  if( my $panel2 = $self->new_panel( 'SpreadSheet',
    'code'    => "loc$self->{flag}",
    'caption' => "Marker [[object->name]] map locations",
    'null_data' => undef,# '<p>This marker is not mapped to the genome</p>'
  ) ) {
    $panel2->add_components( qw(locations EnsEMBL::Web::Component::Marker::spreadsheet_markerMapLocations) );
    $self->add_panel( $panel2 );
  }
}

sub context_menu {
  my $self = shift;
  my $object = $self->{object};
  $self->add_block(
    "marker$self->{flag}", 'bulleted',
    ($object->source||'Marker').': '.$object->name
  );
  $self->add_entry(
    "marker$self->{flag}", 'text' => "Marker info.",
    'href' => "/@{[$object->species]}/markerview?marker=@{[$object->name]}"
  );
}

1;
