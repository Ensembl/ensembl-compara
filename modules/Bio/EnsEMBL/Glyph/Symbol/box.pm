=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::box

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent a box.

=cut

package Bio::EnsEMBL::Glyph::Symbol::box;
use strict;
use Sanger::Graphics::Glyph::Rect;

sub draw {
    my ($class, $rowheight, $start, $end, $pix_per_bp, $y_offset, $attribs) = @_;
   
    my $linecolour = $attribs->{'fgcolor'};
    my $fillcolour = $attribs->{'bgcolor'} || $attribs->{'colour'};
    $linecolour ||= $fillcolour;

    my $height = $attribs->{'height'};

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
