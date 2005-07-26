package EnsEMBL::Web::Document::DropDown::Menu::SNPValid;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-valid',
    'image_width' => 81,
    'alt'         => 'SNP Validation'
  );
  my @menu_entries = @{$self->{'config'}->get('_settings','validation')||[]};
  return undef unless @menu_entries;
  foreach ( @menu_entries ) {
    $self->add_checkbox( @$_ );
  }
  return $self;
}

1;
