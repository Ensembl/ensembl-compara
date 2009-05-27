package Bio::EnsEMBL::GlyphSet::preliminary;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == 1);
  return unless my $mod = $self->species_defs->ENSEMBL_PRELIM;
  my( $FONT,$FONTSIZE )  = $self->get_font_details( 'text' );
  my $top = 0;
  foreach my $line (split /\|/, $mod) { 
    my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $line, '', 'ptsize' => $FONTSIZE, 'font' => $FONT );
    $self->push( $self->Text({
      'x'         => int( ($self->{'container'}->length()+1)/2 ), 
      'y'         => $top,
      'height'    => $th,
      'font'      => $FONT,
      'ptsize'    => $FONTSIZE,
      'colour'    => 'red3',
      'text'      => $line,
      'absolutey' => 1,
    }) );
    $top += $th + 4;
  }
}

1;
        
