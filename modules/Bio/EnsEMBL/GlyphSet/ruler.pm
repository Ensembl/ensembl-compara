package Bio::EnsEMBL::GlyphSet::ruler;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;

  my $strand = $self->strand;

  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    return if ($self->{'container'}->{'compara'} ne 'primary');
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

 #   unless( $Config->{'compara'} && $con_strand == 1 ) {
 #   unless( $Config->{'compara'} && $con_strand == -1 ) {
  my $length     = int( $global_end - $global_start + 1 );
  my $unit       = [qw( bp Kb Mb Gb Tb )]->[my $power = int( ( length( abs($length) ) - 1 ) / 3 )];
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

sub bp_to_nearest_unit {
  my $bp = shift;
  my @units = qw( bp Kb Mb Gb Tb );
    
  my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
  my $unit = $units[$power_ranger];
  my $unit_str;

  my $value = int( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
      
  if ( $unit eq "bp" ) {
    $unit_str = "$value bp";
  } else {
    $unit_str = sprintf( "%.2f%s", $bp / ( 10 ** ( $power_ranger * 3 ) ), " $unit" );
  }

  return $unit_str;
}
