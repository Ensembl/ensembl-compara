package Bio::EnsEMBL::Glyph::Symbol::farrow;
use strict;
use Sanger::Graphics::Glyph::Poly;

sub draw {
    my ($self, $rowheight, $start, $end, $pix_per_bp, $y_offset, $attribs) = @_;
    warn "($rowheight, $start, $end, $pix_per_bp, $y_offset, $attribs)";
    
    my $colour = $attribs->{'fgcolor'} || $attribs->{'colour'};
    my $height = $attribs->{'height'};

    my $slope = $height/2/$pix_per_bp;
    my $points = ( $end - $start + 1 > $slope ) ?
        [
          $start - 1,    $y_offset,
          $start - 1,    $y_offset + $height,
          $end - $slope, $y_offset + $height,
          $end,          $y_offset + $height/2,
          $end - $slope, $y_offset
        ] : [
          $start-1,      $y_offset,
          $start-1,      $y_offset + $height,
          $end,          $y_offset + $height/2
        ];
    return new Sanger::Graphics::Glyph::Poly({
        'points'    => $points,
        'colour'    => $colour,
        'absolutey' => 1
    });

}

1;
