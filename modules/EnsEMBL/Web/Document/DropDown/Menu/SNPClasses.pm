package EnsEMBL::Web::Document::DropDown::Menu::SNPClasses;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-snpclass',
    'image_width' => 84,
    'alt'         => 'SNP classes'
  );
  my @menu_entries = @{$self->{'config'}->get('_settings','classes')||[]};
  return undef unless @menu_entries;
  foreach ( @menu_entries ) {
    $self->add_checkbox( @$_ );
  }
  return $self;
}

1;
