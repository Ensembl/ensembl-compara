=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::rarrow

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent a reverse-pointing arrow.

=cut

package Bio::EnsEMBL::Glyph::Symbol::rarrow;
use strict;
use Sanger::Graphics::Glyph::Poly;

sub draw {
    my ($class, $featuredata, $styledata) = @_;

    my $rowheight = $featuredata->{'row_height'};
    my $start = $featuredata->{'start'};
    my $end = $featuredata->{'end'};
    my $pix_per_bp = $featuredata->{'pix_per_bp'};
    my $y_offset = $featuredata->{'y_offset'};
    
    my $linecolour = $styledata->{'fgcolor'};
    my $fillcolour = $styledata->{'bgcolor'} || $styledata->{'colour'};

    my $height = $styledata->{'height'};

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
