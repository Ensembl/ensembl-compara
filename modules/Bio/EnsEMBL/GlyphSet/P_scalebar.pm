package Bio::EnsEMBL::GlyphSet::P_scalebar;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);


sub _init {
  my ($self) = @_;
    
  my $h            = 0;
  my $pix_per_bp   = $self->scalex;
  my $font_details = $self->get_text_simple( undef, 'innertext' );
  my $colour       = 'black';
  my $len          = $self->{'container'}->length();
    
## Compute divisons...
  my $num_of_digits = length( int( $len / 10 ) );
     $num_of_digits--;
  my $division = 10**$num_of_digits;
  my $first_division = $division;

  my $num_of_divs = int( $len / $division );
  my $i           = 2;

  while ( $num_of_divs >= 12 ) {
    $division    = $first_division * $i;
    $num_of_divs = int( $len / $division );
    $i          += 2;
  }

  $self->push( $self->Rect({
    'x'         => 0,
    'y'         => 4,
    'width'     => $len,
    'height'    => $h,
    'colour'    => $colour,
    'absolutey' => 1,
  }));
    
  my $last_end = 0;
  for (my $i=0;$i<int($len/$division); $i++){
    $self->push($self->Rect({
      'x'         => $i * $division,
      'y'         => 4,
      'width'     => 0,
      'height'    => 2,
      'colour'    => $colour,
      'absolutey' => 1,
    }),$self->Text({
      'x'         => $i * $division,
      'y'         => 6,
      'height'    => $font_details->{'height'},
      'font'      => $font_details->{'font'},
      'ptsize'    => $font_details->{'fontsize'},
      'halign'    => 'left',
      'colour'    => $colour,
      'text'      => $i * $division,
      'absolutey' => 1,
    }));
  }
    # label first tick
  $self->push($self->Text({
    'x'           => 0,
    'y'           => 6,
    'height'      => $font_details->{'height'},
    'font'        => $font_details->{'font'},
    'ptsize'      => $font_details->{'fontsize'},
    'halign'      => 'left',
    'colour'      => $colour,
    'text'        => '0',
    'absolutey'   => 1,
  }));
    
  my $im_width = $self->image_width;
    
    # label last tick
  my @res = $self->get_text_width( 0, $len,'', 'font'=>$font_details->{'font'}, 'ptsize' => $font_details->{'fontsize'} );
  my $tmp_width = $res[2]/$pix_per_bp;
  $self->push( $self->Text({
    'x'           => $im_width-$res[2],
    'width'       => $res[2],
    'textwidth'   => $res[2],
    'y'           => 6,
    'height'      => $font_details->{'height'},
    'font'        => $font_details->{'font'},
    'ptsize'      => $font_details->{'fontsize'},
    'halign'      => 'right',

    'colour'      => $colour,
    'text'        => $len,
    'absolutex'   => 1,
    'absolutewidth'  => 1,
    'absolutey'   => 1,
  }),$self->Rect({
    'x'           => $im_width,
    'y'           => 4,
    'width'       => 0,
    'height'      => 2,
    'colour'      => $colour,
    'absolutex'   => 1,
    'absolutey'   => 1,
  }));
}

1;
