package Bio::EnsEMBL::Glyph::Symbol::rarrow;
use strict;
use Sanger::Graphics::Glyph::Poly;

sub draw {
    my ($self,$rowheight, $start, $end, $pix_per_bp, $y_offset, $attribs) = @_;
    
    my $colour = $attribs->{'fgcolor'} || $attribs->{'colour'};
    my $height = $attribs->{'height'};

    my $slope = $height/2/$pix_per_bp;

    my $points = ( $end - $start + 1 > $slope ) ?
    [
      $end,                $y_offset,
      $end,                $y_offset + $height,
      $start - 1 + $slope, $y_offset + $height,
      $start - 1,          $y_offset + $height/2,
      $start - 1 + $slope, $y_offset
    ] : [
      $end,                $y_offset,
      $end,                $y_offset + $height,
      $start-1,            $y_offset + $height/2
    ];
    return new Sanger::Graphics::Glyph::Poly({
        'points'    => $points,
        'colour'    => $colour,
        'absolutey' => 1
    });

}

1;
