=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::box

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent a box.

=cut

package Bio::EnsEMBL::Glyph::Symbol::box;
use strict;
use Sanger::Graphics::Glyph::Rect;

sub draw {
    my ($class, $featuredata, $styledata) = @_;

    my $rowheight = $featuredata->{'row_height'};
    my $start = $featuredata->{'start'};
    my $end = $featuredata->{'end'};
    my $pix_per_bp = $featuredata->{'pix_per_bp'};
    my $y_offset = $featuredata->{'y_offset'};
   
    my $linecolour = $styledata->{'fgcolor'};
    my $fillcolour = $styledata->{'bgcolor'} || $styledata->{'colour'};
    $linecolour ||= $fillcolour;

    my $height = $styledata->{'height'};

    return new Sanger::Graphics::Glyph::Rect({
    	'x'          => $start-1,
	'y'          => $y_offset,
	'width'      => $end-$start+1,
	'height'     => $height,
	'colour'     => $fillcolour,
	'bordercolour' => $linecolour,
	'absolutey' => 1
    });
}

1;
