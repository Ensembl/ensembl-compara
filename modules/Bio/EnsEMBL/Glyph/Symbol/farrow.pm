=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::farrow

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent a forward-pointing arrow.

=cut

package Bio::EnsEMBL::Glyph::Symbol::farrow;
use strict;
use Sanger::Graphics::Glyph::Poly;

sub draw {
    my ($class, $rowheight, $start, $end, $pix_per_bp, $y_offset, $attribs) = @_;
    
    my $linecolour = $attribs->{'fgcolor'};
    my $fillcolour = $attribs->{'bgcolor'} || $attribs->{'colour'};

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
	'colour'     => $fillcolour,
	'bordercolour' => $linecolour,
        'absolutey' => 1
    });

}

1;
