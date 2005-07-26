package EnsEMBL::Web::Document::DropDown::Menu::SNPTypes;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-snptype',
    'image_width' => 76,
    'alt'         => 'SNP types'
  );
  my @menu_entries = @{$self->{'config'}->get('_settings','types')||[]};
  return undef unless @menu_entries;
  foreach ( @menu_entries ) {
    $self->add_checkbox( @$_ );
  }
  return $self;
}

1;
