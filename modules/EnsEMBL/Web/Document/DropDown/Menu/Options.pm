package EnsEMBL::Web::Document::DropDown::Menu::Options;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );


sub new {
  my $class  = shift;
  my $self = $class->SUPER::new( 
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-options',
    'image_width' => 89,
    'alt'         => 'Decorations'
  ); 
  my @menu_entries = @{$self->{'config'}->get('_settings','options')||[]};
  return undef unless @menu_entries;
  foreach ( @menu_entries ) {
    $self->add_checkbox( @$_ ) if $self->{'config'}->is_available_artefact($_->[0]) ||
                                  $self->{'config'}->is_setting( $_->[0] ) || 
                                  $self->{'scriptconfig'}->is_option( $_->[0]);
  }
  $self->add_link( "Reset options", sprintf(
    qq(/%s/%s?%sreset=%s),
    $self->{'species'}, $self->{'script'}, $self->{'LINK'}, $self->{'config'}->{'type'}
  ), '' );

  return $self;
}

1;
