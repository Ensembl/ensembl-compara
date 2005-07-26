package EnsEMBL::Web::Document::DropDown::Menu::THJumpTo;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA = qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class  = shift;
  my $self = $class->SUPER::new( 
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-jumpto',
    'image_width' => 66,
    'alt'         => 'Jump to'
  ); 
  my $FLAG = 0;
  foreach  my $l ( @{$self->{'locations'}||[]} ) {
    if( $l->{'location'} ) {
      $self->add_link( "Contigview ($l->{'species'})",
        sprintf( "/%s/contigview?c=%s:%s&w=%s", $l->{'species'}, $l->{'location'}->seq_region_name, $l->{'location'}->centrepoint, $l->{'location'}->length ),
        '' );
    }
    $FLAG = 1;
  }
  return $FLAG == 1 ? $self : undef;
}

1;
