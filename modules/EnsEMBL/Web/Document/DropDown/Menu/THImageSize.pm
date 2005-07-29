package EnsEMBL::Web::Document::DropDown::Menu::THImageSize;

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
  my $LINK = sprintf qq(/%s/%s?%s), $ENV{'ENSEMBL_SPECIES'}, $self->{'script'}, $self->{'LINK'};
  foreach( 6..20 ) {
    my $w = $_*100;
    $self->add_link( ($w==$self->{'config'}->get('_settings','width') ? "* " : '' ). "Width $w".'px', $LINK."width=$w", '' );
  }
  return $self;
}

1;
