package EnsEMBL::Web::Document::DropDown::Menu::Strains;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-strains',
    'image_width' => 59,
    'alt'         => 'Strains'
  );
  my @menu_entries = @{ $self->{'config'}{'Populations'} || [] };
  return undef unless scalar @menu_entries;

  $self->add_link( "Reset options", sprintf(
    qq(/%s/%s?%sdefault=%s),
    $self->{'species'}, $self->{'script'}, $self->{'LINK'}, "populations" ), '' );
  foreach my $pop (  @menu_entries ) {
    $self->add_checkbox( "opt_pop_$pop", $pop ); 
  }
  return $self;
}

1;
