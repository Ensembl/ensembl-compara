package Bio::EnsEMBL::Renderer::gif;
use strict;
use lib "..";
use Bio::EnsEMBL::Renderer;
use GD;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Renderer);

sub init_canvas {
    my ($this, $config, $im_width, $im_height) = @_;
    my $canvas = new GD::Image($im_width, $im_height);
    $canvas->colorAllocate($config->colourmap()->rgb_by_id($config->bgcolor()));
    $this->canvas($canvas);
}

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->gif();
    }
}

#########
# colour caching routine.
# GD can only store 256 colours, so need to cache the ones we colorAllocate. (Doh!)
# 
sub colour {
    my ($this, $id) = @_;
    $id ||= $this->{'colourmap'}->id_by_name("black");
    my $colour = $this->{'_GDColourCache'}->{$id} || $this->{'canvas'}->colorAllocate($this->{'colourmap'}->rgb_by_id($id));
    $this->{'_GDColourCache'}->{$id} = $colour;
    return $colour;
}


sub render_Rect {
    my ($self, $glyph) = @_;

    my $canvas = $self->{'canvas'};

    my $gcolour       = $glyph->colour();
    my $gbordercolour = $glyph->bordercolour();

    my $bordercolour  = $self->colour($gbordercolour);
    my $colour        = $self->colour($gcolour);

    $glyph->transform($self->{'config'}->{'transform'});

    my $x1 = $glyph->pixelx();
    my $x2 = $glyph->pixelx() + $glyph->pixelwidth();
    my $y1 = $glyph->pixely();
    my $y2 = $glyph->pixely() + $glyph->pixelheight();

    $canvas->filledRectangle($x1, $y1, $x2, $y2, $colour) if(defined $gcolour);
    $canvas->rectangle($x1, $y1, $x2, $y2, $bordercolour) if(defined $gbordercolour);
#print STDERR qq(gif $glyph: $x1, $y1, $x2, $y2\n) if(ref($glyph) eq "Bio::EnsEMBL::Glyph::Composite");
}

sub render_Text {
    my ($this, $glyph) = @_;

    my $colour = $this->colour($glyph->colour());
    $glyph->transform($this->{'config'}->{'transform'});

    #########
    # BAH! HORRIBLE STINKY STUFF!
    # I'd take GD voodoo calls any day
    #
    if($glyph->font() eq "Tiny") {
        $this->{'canvas'}->string(gdTinyFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);

    } elsif($glyph->font() eq "Small") {
        $this->{'canvas'}->string(gdSmallFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);

    } elsif($glyph->font() eq "MediumBold") {
        $this->{'canvas'}->string(gdMediumBoldFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);

    } elsif($glyph->font() eq "Large") {
        $this->{'canvas'}->string(gdLargeFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);

    } elsif($glyph->font() eq "Giant") {
        $this->{'canvas'}->string(gdGiantFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);
    }

}

sub render_Circle {
}

sub render_Ellipse {
}

sub render_Intron {
    my ($self, $glyph) = @_;

    my $colour = $self->colour($glyph->colour());

    $glyph->transform($self->{'config'}->{'transform'});

    my ($xstart, $xmiddle, $xend, $ystart, $ymiddle, $yend, $strand);

    #########
    # todo: check rotation conditions
    #

    $strand  = $glyph->strand();

    $xstart  = $glyph->pixelx();
    $xend    = $glyph->pixelx() + $glyph->pixelwidth();
    $xmiddle = $glyph->pixelx() + int($glyph->pixelwidth() / 2);

    $ystart  = $glyph->pixely() + int($glyph->pixelheight() / 2);
    $yend    = $ystart;
    $ymiddle = ($strand == 1)?$glyph->pixely():($glyph->pixely()+$glyph->pixelheight());

    $self->{'canvas'}->line($xstart, $ystart, $xmiddle, $ymiddle, $colour);
    $self->{'canvas'}->line($xmiddle, $ymiddle, $xend, $yend, $colour);
}

sub render_Line {
    my ($this, $glyph) = @_;
    $glyph->transform($this->{'config'}->{'transform'});

    my $colour = $this->colour($glyph->colour());
    my $x1     = $glyph->pixelx() + 0;
    my $y1     = $glyph->pixely() + 0;
    my $x2     = $x1 + $glyph->pixelwidth();
    my $y2     = $y1 + $glyph->pixelheight();

    if(defined $glyph->dotted()) {
	$this->{'canvas'}->dashedLine($x1, $y1, $x2, $y2, $colour);
    } else {
	$this->{'canvas'}->line($x1, $y1, $x2, $y2, $colour);
    }
}

sub render_Poly {
    my ($this, $glyph) = @_;

    my $bordercolour = $this->colour($glyph->bordercolour());
    my $colour       = $this->colour($glyph->colour());

    my $poly = new GD::Polygon;

    $glyph->transform($this->{'config'}->{'transform'});

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
    # now loop through $glyph's children
    #
    $this->SUPER::render_Composite($glyph);

    #########
    # draw & colour the bounding area if specified
    #
    if(defined $glyph->colour() || defined $glyph->bordercolour()) {
	my $rect = $glyph;
	$rect->transform($this->{'config'}->{'transform'});
	$this->render_Rect($rect);
    }
}

1;
