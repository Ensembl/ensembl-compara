package EnsEMBL::Web::Document::DropDown::Menu::Features;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;

our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-features',
    'image_width' => 71,
    'alt'         => 'Features'
  );
  my @menu_entries = @{$self->{'config'}->get('_settings','features')||[]};
  if( @{$self->{'configs'}||[]} ) {
    my %T = map { $_->[0] => 1 } @menu_entries;
    foreach my $C ( @{$self->{'configs'}} ) {
      foreach my $m ( @{$C->get('_settings','features')||[]} ) {
        push @menu_entries, $m unless $T{$m->[0]};
        $T{$m->[0]}=1;
      }
    }
  }
  return undef unless @menu_entries;
  foreach my $m ( @menu_entries ) {
    foreach my $c ( @{$self->{'configs'}||[]}, $self->{'config'} ) {
      if( $c->is_available_artefact($m->[0] ) ) {
        $self->add_checkbox( @$m, $c );
        last;
      }
    }
  }
  return $self;
}

1;
