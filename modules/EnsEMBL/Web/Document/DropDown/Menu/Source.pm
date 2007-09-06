package EnsEMBL::Web::Document::DropDown::Menu::Source;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-source',
    'image_width' => 63,
    'alt'         => 'Source'
  );
  my @menu_entries = keys %{ $self->{'config'}->species_defs->VARIATION_SOURCES || {} };
  return undef unless @menu_entries;
  foreach ( sort @menu_entries ) {
    $self->add_checkbox( lc("opt_$_"), $_ );
  }
  return $self;
}

1;
