=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::rarrow

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent a reverse-pointing arrow.

=cut

package Bio::EnsEMBL::Glyph::Symbol::rarrow;
use strict;
use Sanger::Graphics::Glyph::Poly;

sub draw {
    my ($class,$rowheight, $start, $end, $pix_per_bp, $y_offset, $attribs) = @_;
    
    my $linecolour = $attribs->{'fgcolor'};
    my $fillcolour = $attribs->{'bgcolor'} || $attribs->{'colour'};

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
	'colour'     => $fillcolour,
	'bordercolour' => $linecolour,
        'absolutey' => 1
    });

}

1;
