=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::ex

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent an X.

=cut

package Bio::EnsEMBL::Glyph::Symbol::ex;
use strict;
use Sanger::Graphics::Glyph::Line;

use vars qw(@ISA);
use Bio::EnsEMBL::Glyph::Symbol;
@ISA = qw(Bio::EnsEMBL::Glyph::Symbol);

sub draw {
    my $self = shift;
    my $style = $self->style;
    my $feature = $self->feature;

    my $y_offset = $feature->{'y_offset'};
    my $pix_per_bp = $feature->{'pix_per_bp'};
    
    # Point feature, so just use start
    my $start = $feature->{'start'};
   
    my $linecolour = $style->{'fgcolor'};
    my $fillcolour = $style->{'bgcolor'} || $style->{'colour'};
    $linecolour ||= $fillcolour;

    my $height = $style->{'height'};
    my $width =  $style->{'linewidth'} || $height;
    $width /= $pix_per_bp;  # remember, x in bp, y in pixels

    return (new Sanger::Graphics::Glyph::Line({
	    'x'          => $start -1 -$width/2,
	    'y'          => $y_offset,
	    'width'      => $width,
	    'height'     => $height,
	    'colour'     => $linecolour,
	    'absolutey' => 1
	}),
	new Sanger::Graphics::Glyph::Line({
	    'x'          => $start-1 + $width/2,
	    'y'          => $y_offset,
	    'width'      => -$width,
	    'height'     => $height,
	    'colour'     => $linecolour,
	    'absolutey' => 1
	})
	);
}


1;
