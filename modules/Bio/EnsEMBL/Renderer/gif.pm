package Bio::EnsEMBL::Renderer::gif;
use strict;
use Bio::EnsEMBL::Renderer;
use GD;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Renderer);

sub init_canvas {
    my ($self, $config, $im_width, $im_height) = @_;
    my $canvas = new GD::Image($im_width, $im_height);
    $canvas->colorAllocate($config->colourmap()->rgb_by_id($config->bgcolor()));
    $self->canvas($canvas);
}

sub add_canvas_frame {
    my ($self, $config, $im_width, $im_height) = @_;
	
	return if (defined $config->{'no_image_frame'});
	
	# default image frame colour
	my $imageframecol = $config->colourmap()->id_by_name('black');
	
	# custom image frame colour
	if (defined $config->{'image_frame_colour'}){
		$imageframecol = $config->colourmap()->id_by_name($config->{'image_frame_colour'});
	}
    my $framecolour = $self->colour($imageframecol);

	# for contigview bottom box we need an extra thick border...
	if ($config->script() eq "contigviewbottom"){		
    	$self->{'canvas'}->rectangle(1, 1, $im_width-2, $im_height-2, $framecolour);		
	}
	
    $self->{'canvas'}->rectangle(0, 0, $im_width-1, $im_height-1, $framecolour);
	
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
    my ($self, $id) = @_;
    $id ||= $self->{'colourmap'}->id_by_name("black");
    my $colour = $self->{'_GDColourCache'}->{$id} || $self->{'canvas'}->colorAllocate($self->{'colourmap'}->rgb_by_id($id));
    $self->{'_GDColourCache'}->{$id} = $colour;
    return $colour;
}


sub render_Rect {
    my ($self, $glyph) = @_;

    my $canvas = $self->{'canvas'};

    my $gcolour       = $glyph->colour();
    my $gbordercolour = $glyph->bordercolour();
	# (avc)
	# this is a no-op to let us define transparent glyphs
	# and which can still have an imagemap area BUT make
	# sure it is smaller than the carrent largest glyph in
	# this glyphset because its height is not recorded!
	if ($gcolour eq 'transparent'){
		return;
	}

    my $bordercolour  = $self->colour($gbordercolour);
    my $colour        = $self->colour($gcolour);

    my $x1 = $glyph->pixelx();
    my $x2 = $glyph->pixelx() + $glyph->pixelwidth();
    my $y1 = $glyph->pixely();
    my $y2 = $glyph->pixely() + $glyph->pixelheight();

    $canvas->filledRectangle($x1, $y1, $x2, $y2, $colour) if(defined $gcolour);
    $canvas->rectangle($x1, $y1, $x2, $y2, $bordercolour) if(defined $gbordercolour);
	
	#print STDERR qq(gif $glyph: $x1, $y1, $x2, $y2\n) if(ref($glyph) eq "Bio::EnsEMBL::Glyph::Composite");

}

sub render_Text {
    my ($self, $glyph) = @_;

    my $colour = $self->colour($glyph->colour());

    #########
    # BAH! HORRIBLE STINKY STUFF!
    # I'd take GD voodoo calls any day
    #
    if($glyph->font() eq "Tiny") {
        $self->{'canvas'}->string(gdTinyFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);

    } elsif($glyph->font() eq "Small") {
        $self->{'canvas'}->string(gdSmallFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);

    } elsif($glyph->font() eq "MediumBold") {
        $self->{'canvas'}->string(gdMediumBoldFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);

    } elsif($glyph->font() eq "Large") {
        $self->{'canvas'}->string(gdLargeFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);

    } elsif($glyph->font() eq "Giant") {
        $self->{'canvas'}->string(gdGiantFont, $glyph->pixelx(), $glyph->pixely(), $glyph->text(), $colour);
    }

}

sub render_Circle {
}

sub render_Ellipse {
}

sub render_Intron {
    my ($self, $glyph) = @_;

    my $colour = $self->colour($glyph->colour());

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
    my ($self, $glyph) = @_;

    my $colour = $self->colour($glyph->colour());
    my $x1     = $glyph->pixelx() + 0;
    my $y1     = $glyph->pixely() + 0;
    my $x2     = $x1 + $glyph->pixelwidth();
    my $y2     = $y1 + $glyph->pixelheight();

    if(defined $glyph->dotted()) {
	$self->{'canvas'}->dashedLine($x1, $y1, $x2, $y2, $colour);
    } else {
	$self->{'canvas'}->line($x1, $y1, $x2, $y2, $colour);
    }
}

sub render_Poly {
    my ($self, $glyph) = @_;

    my $bordercolour = $self->colour($glyph->bordercolour());
    my $colour       = $self->colour($glyph->colour());

    my $poly = new GD::Polygon;

    return unless(defined $glyph->pixelpoints());

    my @points = @{$glyph->pixelpoints()};
    my $pairs_of_points = (scalar @points)/ 2;

    for(my $i=0;$i<$pairs_of_points;$i++) {
	my $x = shift @points;
	my $y = shift @points;

	$poly->addPt($x,$y);
    }

    if(defined $colour) {
	$self->{'canvas'}->filledPolygon($poly, $colour);
    } else {
	$self->{'canvas'}->polygon($poly, $bordercolour);
    }
}

sub render_Composite {
    my ($self, $glyph) = @_;

    #########
    # draw & colour the fill area if specified
    #
    $self->render_Rect($glyph) if(defined $glyph->colour());

    #########
    # now loop through $glyph's children
    #
    $self->SUPER::render_Composite($glyph);

    #########
    # draw & colour the bounding area if specified
    #
    $glyph->{'colour'} = undef;
    $self->render_Rect($glyph) if(defined $glyph->bordercolour());
}

1;
