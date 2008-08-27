#########
# Author: avc@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::Renderer::wmf;
use strict;
use WMF;
use WMF::Polygon;
use base qw(Sanger::Graphics::Renderer::gif);

sub init_canvas {
    my ($this, $config, $im_width, $im_height) = @_;
    my $canvas = new WMF($im_width, $im_height);
    $canvas->colorAllocate($config->colourmap()->rgb_by_name($config->bgcolor()));
    $this->canvas($canvas);
}

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->wmf();
    }
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

sub render_Poly {
    my ($self, $glyph) = @_;

    my $bordercolour = $self->colour($glyph->bordercolour());
    my $colour       = $self->colour($glyph->colour());

    my $poly = new WMF::Polygon;

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



1;
