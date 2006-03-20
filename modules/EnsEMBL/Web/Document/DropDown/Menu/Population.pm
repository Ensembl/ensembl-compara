package EnsEMBL::Web::Document::DropDown::Menu::Population;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-pops',
    'image_width' => 85,
    'alt'         => 'Populations'
  );
  my @menu_entries = @{ $self->{'config'}{'Populations'} || [] };
  return undef unless scalar @menu_entries;
  foreach my $pop (  @menu_entries ) {
    $self->add_checkbox( "opt_pop_$pop", $pop ); 
  }
  return $self;
}

1;
