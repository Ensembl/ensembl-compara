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
  my $pops = $self->{'config'}{'Populations'};
  my @menu_entries = sort { $pops->{$a} cmp $pops->{$b} } keys %$pops;
  return undef unless @menu_entries;
  foreach my $m ( @menu_entries ) {
    $self->add_checkbox( "pop_$m", $pops->{$m} ); 
  }
  return $self;
}

1;
