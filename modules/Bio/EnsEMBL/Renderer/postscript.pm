
package Bio::EnsEMBL::Renderer::postscript;
use strict;

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

sub add_string {
    my ($self,$string) = @_;

    $self->{'_postscript_string'} .= $string;
}


sub postscript_string {
    my ($self) = @_;

    # we separate out postscript commands from header so that we can
    # do EPS at some future time.

    my $header = "%!PS-Adobe-2.0\n% Created by Bio::EnsEMBL::Renderer::postscript\n%  ensembl-draw cvs module\n%  Contact www.ensembl.org>\n";
    
    # should make this configurable somehow. Hmmmm.
    $header .= "/Helvetica findfont $font scalefont setfont\n";

    
    return $header.$self->{'_postscript_string'};
}
    


sub colour {
    my ($this, $id) = @_;
  
    die "postscript currently has not implemented colour routine. Not sure how to roll it in yet";
   
    return $colour;
}


sub render_Rect {
    my ($self, $glyph) = @_;
#print STDERR qq(drawing rect $glyph\n);

    my $canvas = $self->{'canvas'};

    my $gcolour      = $glyph->colour();
    my $gbordercolor = $glyph->colour();

    # we don't do colours yet!
    #my $bordercolour = $self->colour($gcolour || $gbordercolor);
    #my $colour       = $self->colour($gcolour);

    $glyph->transform($self->{'transform'});

    my $x1 = $glyph->pixelx();
    my $x2 = $glyph->pixelx() + $glyph->pixelwidth();
    my $y1 = $glyph->pixely();
    my $y2 = $glyph->pixely() + $glyph->pixelheight();

    

    $self->add_string("$x1 $y1 moveto $x1 $y2 stroke $x2 $y2 stroke $x2 $y1 stroke closepath fill\n");

}

sub render_Text {
    my ($this, $glyph) = @_;
    my $font = $glyph->font();

    #my $colour = $this->colour($glyph->colour());

    $glyph->transform($this->{'transform'});

    $self->add_string($glyph->pixelx()." ".$glyph->pixely." moveto (".$glyph->text.") show\n");

}

sub render_Circle {
    die "Not implemented in postscript yet!";
}

sub render_Ellipse {
    die "Not implemented in postscript yet!";
}

sub render_Intron {
    my ($self, $glyph) = @_;

    #my $colour = $self->colour($glyph->colour());

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

    $self->add_string("$xstart  $ystart  moveto $xmiddle $ymiddle stroke\n");
    $self->add_string("$xmiddle $ymiddle moveto $xend $yend stroke\n");


}

sub render_Poly {
    my ($this, $glyph) = @_;


    die "Postscript has not implemented render_Poly yet";

    my $bordercolour = $this->colour($glyph->bordercolour());
    my $colour       = $this->colour($glyph->colour());

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

sub render_Composite {
    my ($this, $glyph) = @_;
    #########
    # apply transformation
    #
    $glyph->transform($this->{'transform'});

    #########
    # draw & colour the bounding area if specified
    # 
    $this->render_Rect($glyph) if(defined $glyph->colour() || defined $glyph->bordercolour());

    #########
    # now loop through $glyph's children
    #
    $this->SUPER::render_Composite($glyph);
}

1;
