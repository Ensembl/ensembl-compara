package Bio::EnsEMBL::GlyphSet::missing;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;

use warnings;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    return;
}

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);
  my $tracks   = $self->{'config'}->{'missing_tracks'};
  my $Config        = $self->{'config'};
  my( $FONT,$FONTSIZE)  = $self->get_font_details( 'text' );

  #my $text_to_display = "All tracks are currently switched on";
  my $text_to_display= "";  # temporary measure to stop incorrect info on browser until fixed properly

  if( $tracks > 1 ) {
    $text_to_display =  "There are currently $tracks tracks switched off, use the menus above the image to turn them on." ;
  } elsif( $tracks == 1 ) {
    $text_to_display =  "There is currently one track switched off, use the menus above the image to turn this on." ;
  }

  my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $text_to_display, '', 'ptsize' => $FONTSIZE, 'font' => $FONT );
 
  $self->push( new Sanger::Graphics::Glyph::Text({
    'x'         => 0, 
    'y'         => 1,
    'height'    => $th,
    'font'      => $FONT,
    'ptsize'    => $FONTSIZE,
    'colour'    => 'black',
    'halign'    => 'left',
    'text'      => $text_to_display,
    'absolutey' => 1,
  }) );
}

1;
        
