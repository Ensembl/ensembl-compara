package Bio::EnsEMBL::Glyph::Symbol::box;
use strict;
use Sanger::Graphics::Glyph::Rect;

sub draw {
    my ($self, $rowheight, $start, $end, $pix_per_bp, $y_offset, $attribs) = @_;
    
    my $colour = $attribs->{'fgcolor'} || $attribs->{'colour'};
    my $height = $attribs->{'height'};

    return new Sanger::Graphics::Glyph::Rect({
    	'x'          => $start-1,
	'y'          => $y_offset,
	'width'      => $end-$start+1,
	'height'     => $height,
	'colour'     => $colour,
	'absolutey' => 1
    });
}

1;
