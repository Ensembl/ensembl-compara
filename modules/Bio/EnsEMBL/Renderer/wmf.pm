package Renderer::wmf;
use strict;
use WMF;
use lib "..";
use Renderer;
use vars qw(@ISA);
@ISA = qw(Renderer);

sub canvas {
    my ($self, $canvas) = @_;
   if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->wmf();
    }
}

sub render_Rect {
    my ($self, $glyph) = @_;

    my $bordercolour = $self->{'canvas'}->colorAllocate($self->{'colourmap'}->rgb_by_id($glyph->bordercolour() || $glyph->colour()));
    my $colour = $self->{'canvas'}->colorAllocate($self->{'colourmap'}->rgb_by_id($glyph->colour()));

    $glyph->transform($self->{'transform'});

    my $x1 = $glyph->pixelx();
    my $x2 = $glyph->pixelx() + $glyph->pixelwidth();
    my $y1 = $glyph->pixely();
    my $y2 = $glyph->pixely() + $glyph->pixelheight();

    $self->{'canvas'}->filledRectangle($x1,   $y1, $x2, $y2, $bordercolour) if(defined $bordercolour);
    #$self->{'canvas'}->filledRectangle($x1+1, $y1+1, $x2-1, $y2-1, $colour) 
	#	if(defined $bordercolour && defined $colour && $bordercolour != $colour);

}

sub render_Text {
}

sub render_Circle {
}

sub render_Ellipse {
}

sub render_Intron {
    my ($self, $glyph) = @_;

    my $colour = $self->{'canvas'}->colorAllocate($self->{'colourmap'}->rgb_by_id($glyph->colour()));

    $glyph->transform($self->{'transform'});

    my ($xstart, $xmiddle, $xend, $ystart, $ymiddle, $yend);

    if($self->{'transform'}->{'rotation'} == 90) {
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
    $self->{'canvas'}->line($xstart, $ystart, $xmiddle, $ymiddle, $colour);
    $self->{'canvas'}->line($xmiddle, $ymiddle, $xend, $yend, $colour);
}

1;
