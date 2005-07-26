package EnsEMBL::Web::Document::DropDown::Menu::THExport;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-exportas',
    'image_width' => 58,
    'alt'         => 'Export data'
  );
  foreach( qw(pdf svg postscript) ) {
    $self->add_checkbox( "format_$_", "Include @{[uc($_)]} links" );
  }
  return $self;
}

1;
