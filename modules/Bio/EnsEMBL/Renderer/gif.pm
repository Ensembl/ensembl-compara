package Bio::EnsEMBL::Renderer::gif;
use strict;
use lib "..";
use Bio::EnsEMBL::Renderer;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Renderer);

sub canvas {
    my ($this, $canvas) = @_;
    if(defined $canvas) {
	$this->{'canvas'} = $canvas;
    } else {
	return $this->{'canvas'}->gif();
    }
}

sub render_Rect {
    my ($this, $glyph) = @_;

    my $bordercolour = $this->{'canvas'}->colorAllocate($this->{'colourmap'}->rgb_by_id($glyph->bordercolour() || $glyph->colour()));
    my $colour = $this->{'canvas'}->colorAllocate($this->{'colourmap'}->rgb_by_id($glyph->colour()));

    $glyph->transform($this->{'transform'});

    my $x1 = $glyph->pixelx();
    my $x2 = $glyph->pixelx() + $glyph->pixelwidth();
    my $y1 = $glyph->pixely();
    my $y2 = $glyph->pixely() + $glyph->pixelheight();

    $this->{'canvas'}->filledRectangle($x1,   $y1, $x2, $y2, $bordercolour) if(defined $bordercolour);
    $this->{'canvas'}->filledRectangle($x1+1, $y1+1, $x2-1, $y2-1, $colour) if(defined $bordercolour && defined $colour && $bordercolour != $colour);

}

sub render_Text {
}

sub render_Circle {
}

sub render_Ellipse {
}

sub render_Intron {
    my ($this, $glyph) = @_;

    my $colour = $this->{'canvas'}->colorAllocate($this->{'colourmap'}->rgb_by_id($glyph->colour()));

    $glyph->transform($this->{'transform'});

    my ($xstart, $xmiddle, $xend, $ystart, $ymiddle, $yend);

    if($this->{'transform'}->{'rotation'} == 90) {
	$xstart  = $glyph->pixelx() + int($glyph->pixelwidth()/2);
	$xend    = $xstart;
	$xmiddle = $glyph->pixelx() + $glyph->pixelwidth();

	$ystart  = $glyph->pixely();
	$yend    = $glyph->pixely() + $glyph->pixelheight();
	$ymiddle = $glyph->pixely() + int($glyph->pixelheight() / 2);

    } else {
	$xstart  = $glyph->pixelx();
	$xend    = $glyph->pixelx() + $glyph->pixelwidth();
	$xmiddle = $glyph->pixelx() + int($glyph->pixelwidth() / 2);

	$ystart  = $glyph->pixely() + int($glyph->pixelheight() / 2);
	$yend    = $ystart;
	$ymiddle = $glyph->pixely();
    }
    $this->{'canvas'}->line($xstart, $ystart, $xmiddle, $ymiddle, $colour);
    $this->{'canvas'}->line($xmiddle, $ymiddle, $xend, $yend, $colour);
}

1;
