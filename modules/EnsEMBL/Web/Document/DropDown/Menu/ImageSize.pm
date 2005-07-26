package EnsEMBL::Web::Document::DropDown::Menu::ImageSize;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class  = shift;
  my $self = $class->SUPER::new( 
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-imgsize',
    'image_width' => 81,
    'alt'         => 'Resize image'
  ); 
  my $LINK = sprintf qq(/%s/%s?%s), $self->{'species'}, $self->{'script'}, $self->{'LINK'};
  foreach( qw(700 900 1200 1500 2000 ) ) {
    $self->add_link( ($_==$self->{'scriptconfig'}->get('image_width') ? "* " : '' ). "Width $_".'px', $LINK."image_width=$_", '' );
  }
  return $self;
}

1;
