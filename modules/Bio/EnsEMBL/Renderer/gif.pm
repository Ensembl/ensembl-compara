package Bio::EnsEMBL::Renderer::gif;
use strict;
use lib "..";
use Bio::EnsEMBL::Renderer;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Renderer);

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->gif();
    }
}

sub render_Rect {
    my ($self, $glyph) = @_;

	my $canvas = $self->{'canvas'};
	my $cmap = $self->{'colourmap'};

	my @col1 = $cmap->rgb_by_id($glyph->bordercolour() || $glyph->colour());
    my $bordercolour = $canvas->colorAllocate(@col1);
	#print STDERR "Foo: @col1\n";

	my @col2 = $cmap->rgb_by_id($glyph->colour());
    my $colour = $canvas->colorAllocate(@col2);
	#print STDERR "Foo: @col2\n";

    $glyph->transform($self->{'transform'});

    my $x1 = $glyph->pixelx();
    my $x2 = $glyph->pixelx() + $glyph->pixelwidth();
    my $y1 = $glyph->pixely();
    my $y2 = $glyph->pixely() + $glyph->pixelheight();

    $canvas->filledRectangle($x1,   $y1, $x2, $y2, $bordercolour) if(defined $bordercolour);
    $canvas->filledRectangle($x1+1, $y1+1, $x2-1, $y2-1, $colour) if(defined $bordercolour && defined $colour && $bordercolour != $colour);

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

sub render_Poly {
    my ($this, $glyph) = @_;

    my $gbordercolour = $glyph->bordercolour();
    my $gcolour = $glyph->colour();

    my ($colour, $bordercolour);

    $bordercolour = $this->{'canvas'}->colorAllocate($this->{'colourmap'}->rgb_by_id($gbordercolour)) if(defined $gbordercolour);
    $colour = $this->{'canvas'}->colorAllocate($this->{'colourmap'}->rgb_by_id($gcolour)) if(defined $gcolour);

    my $poly = new GD::Polygon;

    $glyph->transform($this->{'transform'});

    my @points = @{$glyph->pixelpoints()};
    my $pairs_of_points = (scalar @points)/ 2;

    for(my $i=0;$i<$pairs_of_points;$i++) {
	my $x = shift @points;
	my $y = shift @points;

	$poly->addPt($x,$y);
    }

    if(defined $colour) {
	$this->{'canvas'}->filledPolygon($poly, $colour);
    } else {
	$this->{'canvas'}->polygon($poly, $bordercolour);
    }
}

1;
