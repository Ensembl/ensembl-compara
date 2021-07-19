=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::ruler;

### Draws an arrow showing the direction of the strand, labelled with
### the size of the current region (in kb) - by default, one is drawn at the 
### very top of the image and one at the very bottom

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my ($self) = @_;
  
  my $strand = $self->strand;

  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    return if $self->get_parameter('compara') ne 'primary';
  }

  my $strand_flag    = $self->my_config('strand');

  return if( $strand_flag eq 'r' && $strand != -1 || $strand_flag eq 'f' && $strand != 1 );

  my $len            = $self->{'container'}->length();
  my $global_start   = $self->{'container'}->start();
  my $global_end     = $self->{'container'}->end();
  my $highlights     = $self->highlights();
  my $im_width       = $self->image_width();
  my $feature_colour = $self->my_colour('default') || 'black';
  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );

  my $fontheight     = $res[3];
  my $fontwidth      = $res[2];

  my $con_strand     = $self->{'container'}->strand();

  my $pix_per_bp     = $self->scalex;
  #####################################################################
  # The ruler has to be drawn in absolute x, because when the length is
  # too small the rounding errors screw everything
  #####################################################################

## let's work out what to draw...

##  |-forward strand----------length bp------------------------->
##  <-------------------------length bp----------reverse strand-|
  my( $right, $left, $righttext, $lefttext ) 
    = $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice") ? ( 'bar',   'bar',   '', '' )
    : $self->my_config('notext')                                            ? ( 'arrow', 'arrow', '', '' )
    : $strand > 0                                                           ? ( 'arrow', 'bar',   $con_strand > 0 ? 'Forward strand' : 'Reverse strand', '' )
    :                                                                         ( 'bar',   'arrow', '', $con_strand < 0 ? 'Forward strand' : 'Reverse strand' )
    ;

  my $length     = $len;

  my $unit       = [qw( bp kb Mb Gb Tb )]->[my $power = int( ( length( abs($length) ) - 1 ) / 3 )];
  my $centretext = $unit eq 'bp' ? "$length bp" : sprintf( "%.2f %s", $length / 1000**$power, $unit );

    ## First let's draw the blocksize in the middle....

  my $O = 3; my $P = 20;
  my @common = ( 'z' => 1000, 'colour' => $feature_colour, 'absolutex' => 1, 'absolutey' => 1, 'absolutewidth' => 1 );

  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my($X_1,$X_2,$W,$H) = $self->get_text_width(0,'X','','font'=>$fontname,'ptsize'=>$fontsize);

  my @common_text = ( 'height' => $H, 'font' => $fontname, 'ptsize' => $fontsize, @common, 'y' => 0 );

## Now loop through the three blocks of text... Left text; centre text and right text....

  my @lines = (0);

## Left hand side text...
  if( $lefttext ) {
    my($text,$part,$W,$H) = $self->get_text_width( 0, $lefttext, '', @common_text );
    my $start        = $P;
    $self->push( $self->Text({ 'x' => $start, 'text' => $lefttext, 'halign' => 'left', @common_text }));
    push @lines, $P-$O, $P+$O+$W;
  }
## Centre text...
  if( $centretext ) {
    my($text,$part,$W,$H) = $self->get_text_width( 0, $centretext, '', @common_text );
    my $start        = ($im_width-$W)/2;
    $self->push( $self->Text({ 'x' => $start, 'text' => $centretext, 'width' => $W, 'halign' => 'center', @common_text, 'textwidth' => $W }));
    push @lines, $im_width/2 - $O-$W/2, $im_width/2 + $O+$W/2;
  }
## Right text...
  if( $righttext ) {
    my($text,$part,$W,$H) = $self->get_text_width( 0, $righttext, '', @common_text );
    my $start        = $im_width - $P - $W;
    $self->push( $self->Text({ 'x' => $start, 'text' => $righttext, 'halign' => 'right', 'width' => $W,  @common_text, 'textwidth' => $W }));
    push @lines, $im_width - $P-$O-$W, $im_width -$P+$O;
  }
  push @lines, $im_width;

## Loop through lines and draw them...
  while( my($start,$end) = splice( @lines, 0, 2 ) ) {
    $self->push( $self->Rect({ 'x' => $start, 'y' => 6, 'width' => $end-$start, 'height' => 0, @common }));
  }  
## Draw left hand decoration...
  if( $left eq 'arrow' ) {
    $self->push($self->Poly({ 'points'    => [0,6, ($fontwidth*2),3, ($fontwidth*2),9], @common }));
  } elsif( $left eq 'bar' ) {
    $self->push($self->Rect({ 'x' => 0, 'y' => 3, 'height' => 6, 'width' => 0, @common }));
  } 
## and right hand decoration...
  if( $right eq 'arrow' ) {
    $self->push($self->Poly({ 'points' => [$im_width,6, ($im_width-$fontwidth*2),3, ($im_width-$fontwidth*2),9], @common }));
  } elsif( $right eq 'bar' ) {
    $self->push($self->Rect({ 'x' => $im_width, 'y' => 3, 'height' => 6, 'width' => 0, @common }));
  }
}

1;
