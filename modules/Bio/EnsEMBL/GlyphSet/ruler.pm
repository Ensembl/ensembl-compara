package Bio::EnsEMBL::GlyphSet::ruler;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Poly;

sub init_label {
  my ($self) = @_;
  return if defined $self->{'config'}->{'_no_label'};
  return if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice"));
  $self->init_label_text('Length' );
}

sub _init {
  my ($self) = @_;

  my $type = $self->check();
  return unless defined $type;

  my $strand = $self->strand;

  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
      return if ($self->{'container'}->{'compara'} ne 'primary');
  }

  my $Config = $self->{'config'};
  my $strand_flag    = $Config->get($type, 'str');

  return if( $strand_flag eq 'r' && $strand != -1 || $strand_flag eq 'f' && $strand != 1 );

  my $len            = $self->{'container'}->length();
  my $global_start   = $self->{'container'}->start();
  my $global_end     = $self->{'container'}->end();
  my $highlights     = $self->highlights();
  my $im_width       = $Config->image_width();
  my $feature_colour = $Config->get('ruler','col');
  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );

  my $fontheight     = $res[3];
  my $fontwidth      = $res[2];

  my $con_strand     = $self->{'container'}->strand();

  my $pix_per_bp    = $Config->transform->{'scalex'};
  #####################################################################
  # The ruler has to be drawn in absolute x, because when the length is
  # too small the rounding errors screw everything
  #####################################################################

## let's work out what to draw...

##  |-forward strand----------length bp------------------------->
##  <-------------------------length bp----------reverse strand-|
  my( $right, $left, $righttext, $lefttext );
  if( $Config->get('ruler','notext') ) {
    $right     = 'arrow';
    $left      = 'arrow';
    $lefttext  = '',
    $righttext = '';
  } elsif( $strand > 0 ) {
    $right     = 'arrow';
    $left      = 'bar';
    $lefttext  = $con_strand > 0 ? 'Forward strand' : 'Reverse strand'; 
    $righttext = '';
  } else {
    $right     = 'bar';
    $left      = 'arrow';
    $righttext = $con_strand > 0 ? 'Reverse strand' : 'Forward strand';
    $lefttext  = '';
  }

# in AlignSlice strand does not really make sense as it can consist of multiple slices on different strands - hence we just remove the text
  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
      $righttext = $lefttext = '';
      $right = $left = 'bar';
  }
 #   unless( $Config->{'compara'} && $con_strand == 1 ) {
 #   unless( $Config->{'compara'} && $con_strand == -1 ) {
  my $length     = int( $global_end - $global_start + 1 );
  my $unit       = [qw( bp Kb Mb Gb Tb )]->[my $power = int( ( length( abs($length) ) - 1 ) / 3 )];
  my $centretext = $unit eq 'bp' ? "$length bp" : sprintf( "%.2f %s", $length / 1000**$power, $unit );

    ## First let's draw the blocksize in the middle....

  my @lines = ( 0 );
  my $O = 3; my $P = 20;
  my @common = (
    'z' => 1000, 'colour' => $feature_colour, 'absolutex' => 1, 'absolutey' => 1, 'absolutewidth' => 1
  );

  my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE;
  my $font = $ST->{'GRAPHIC_FONT'} || "arial";
  my $font_size = $ST->{'GRAPHIC_FONTSIZE'} || 8;


  my @common_text = ( 'height' => $fontheight, 'font' => $font, 'ptsize' => $font_size, @common, 'y' => 2 );
  if( $lefttext ) {
    my($text,$part,$W,$H) = $self->get_text_width( 0, $lefttext, '', @common_text );
    my $start        = $P;
    $self->push( new Sanger::Graphics::Glyph::Text({
      'x' => $start, 'text' => $lefttext, 'halign' => 'left', @common_text
    }));
    push @lines, $P-$O, $P+$O+$W;
  }
  if( $centretext ) {
    my($text,$part,$W,$H) = $self->get_text_width( 0, $centretext, '', @common_text );
    my $start        = $im_width/2;
    $self->push( new Sanger::Graphics::Glyph::Text({
      'x' => $start, 'text' => $centretext, 'halign' => 'center', @common_text
    }));
    push @lines, $im_width/2 - $O-$W/2, $im_width/2 + $O+$W/2;
  }
  if( $righttext ) {
    my($text,$part,$W,$H) = $self->get_text_width( 0, $righttext, '', @common_text );
    my $start        = $im_width - $P;
    $self->push( new Sanger::Graphics::Glyph::Text({
      'x' => $start, 'text' => $righttext, 'halign' => 'right', @common_text
    }));
    push @lines, $im_width - $P-$O-$W, $im_width -$P+$O;
  }
  push @lines, $im_width;

  while( my($start,$end) = splice( @lines, 0, 2 ) ) {
    $self->push( new Sanger::Graphics::Glyph::Rect({
      'x'         => $start,
      'y'         => 6,
      'width'     => $end-$start,
      'height'    => 0,
      @common
    }));
  }  
  if( $left eq 'arrow' ) {
    $self->push(new Sanger::Graphics::Glyph::Poly({
      'points'    => [0,6, ($fontwidth*2),3, ($fontwidth*2),9],
      @common
    }));
  } elsif( $left eq 'bar' ) {
    $self->push(new Sanger::Graphics::Glyph::Rect({
      'x'         => 0,
      'y'         => 3,
      'height'    => 6,
      'width'     => 0,
      @common
    }));
  } 
  # add the right arrow head....
  if( $right eq 'arrow' ) {
    $self->push(new Sanger::Graphics::Glyph::Poly({
      'points'    => [$im_width,6, ($im_width-$fontwidth*2),3, ($im_width-$fontwidth*2),9],
      @common
    }));
  } elsif( $right eq 'bar' ) {
    $self->push(new Sanger::Graphics::Glyph::Rect({
      'x'         => $im_width,
      'y'         => 3,
      'height'    => 6,
      'width'     => 0,
      @common
    }));
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
