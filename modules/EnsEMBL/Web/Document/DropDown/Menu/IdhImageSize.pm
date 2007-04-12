package EnsEMBL::Web::Document::DropDown::Menu::IdhImageSize;

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
  my $object = $self->{'object'};
  my $temp = $object->type; 
  my $type = $temp eq 'Translation' ? "peptide" : lc($temp);
  my $id = $object->stable_id ."." . $object->version;
  my $LINK = sprintf qq(/%s/%s?%s=%s), $self->{'species'}, $self->{'script'}, $type, $id;
  foreach( 6..20 ) {
    my $w = $_*100;
    $self->add_link( ($w==$self->{'scriptconfig'}->get('image_width') ? "* " : '' ). "Width $w".'px', $LINK.";image_width=$w", '' );
  }
  return $self;
}

1;
