#########
# Author: js5@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::Renderer::svg;
use strict;


use vars qw(%classes);

use base qw(Sanger::Graphics::Renderer);

sub init_canvas {
    my ($self, $config, $im_width, $im_height) = @_;
    # we separate out postscript commands from header so that we can
    # do EPS at some future time.

    $im_height = int($im_height);
    $im_width  = int($im_width);

    my @colours = keys %{$self->{'colourmap'}};

    $self->{'image_width'} = $im_width;
    $self->{'image_height'} = $im_height;
    $self->{'style_cache'} = {};
    $self->{'next_style'} = 'aa';
    $self->canvas('');
}

sub add_canvas_frame {
}

sub svg_rgb_by_name {
    my ($self, $name) = @_;
    return 'none' if($name eq 'transparent');
    return 'rgb('. (join ',',$self->{'colourmap'}->rgb_by_name($name)).')';
}
sub svg_rgb_by_id {
    my ($self, $id) = @_;
    return 'none' if($id eq 'transparent');
    return 'rgb('. (join ',',$self->{'colourmap'}->rgb_by_name($id)).')';
}

sub canvas {
    my ($self, $canvas) = @_;

    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
        my $styleHTML = join "\n", map { '.'.($self->{'style_cache'}->{$_})." { $_ }" } keys %{$self->{'style_cache'}};
	return qq(<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20001102//EN" "http://www.w3.org/TR/2000/CR-SVG-20001102/DTD/svg-20001102.dtd">
<svg width="$self->{'image_width'}" height="$self->{'image_height'}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<defs><style type="text/css">
poly { stroke-linecap: round }
line, rect, poly { stroke-width: 0.5; }
text { font-family:Helvetica, Arial, sans-serif;font-size:6pt;font-weight:normal;text-align:left;fill:black; }
${styleHTML}
</style></defs>
$self->{'canvas'}
</svg>
    	);
    }
}

sub add_string {
    my ($self,$string) = @_;

    $self->{'canvas'} .= $string;
}

sub class {
    my ($self, $style) = @_;
    my $class = $self->{'style_cache'}->{$style};
    unless($class) {
      $class = $self->{'style_cache'}->{$style} = $self->{'next_style'}++;
    }
    return qq(class="$class");
}
sub style {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour();
    my $gbordercolour = $glyph->bordercolour();

    my $style = 
    	defined $gcolour ? 		qq(fill:).$self->svg_rgb_by_id($gcolour).qq(;opacity:1;stroke:none;) :
     	defined $gbordercolour ?	qq(fill:none;opacity:1;stroke:).$self->svg_rgb_by_id($gbordercolour).qq(;) : 
					qq(fill:none;stroke:none;);
    return $self->class($style);
}

sub textstyle {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour() ? $self->svg_rgb_by_id($glyph->colour()) : $self->svg_rgb_by_name('black');

    my $style = "stroke:none;opacity:1;fill:$gcolour;";
    return $self->class($style);
}

sub linestyle {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour();
    my $dotted        = $glyph->dotted();

    my $style =
        defined $gcolour ? 	qq(fill:none;stroke:).$self->svg_rgb_by_id($gcolour).qq(;opacity:1;) :
				qq(fill:none;stroke:none;);
    $style .= qq(stroke-dasharray:1,2,1;) if defined $dotted; 

    return $self->class($style);
}

sub render_Rect {
    my ($self, $glyph) = @_;

    my $style = $self->style( $glyph );
    my $x = $glyph->pixelx();
    my $w = $glyph->pixelwidth();
    my $y = $glyph->pixely();
    my $h = $glyph->pixelheight();

    $x = sprintf("%0.3f",$x);
    $w = sprintf("%0.3f",$w);
    $y = sprintf("%0.3f",$y);
    $h = sprintf("%0.3f",$h);
    $self->add_string(qq(<rect x="$x" y="$y" width="$w" height="$h" $style />\n)); 
}

sub render_Text {
    my ($self, $glyph) = @_;
    my $font = $glyph->font();

    my $style   = $self->textstyle( $glyph );
    my $x       = $glyph->pixelx();
    my $y       = $glyph->pixely()+6;
    my $text    = $glyph->text();

    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&amp;/g;

    $self->add_string( qq(<text x="$x" y="$y" $style>$text</text>\n) );
}

sub render_Circle {
#    die "Not implemented in postscript yet!";
}

sub render_Ellipse {
#    die "Not implemented in postscript yet!";
}

sub render_Intron {
    my ($self, $glyph) = @_;
    my $style   = $self->linestyle( $glyph );

    my $x1 = $glyph->pixelx();
    my $w1 = $glyph->pixelwidth() / 2;
    my $h1 = $glyph->pixelheight() / 2;
    my $y1 = $glyph->pixely() + $h1;

    $h1 = -$h1 if($glyph->strand() == -1);

    my $h2 = -$h1;

    $self->add_string(qq(<path d="M$x1,$y1 l$w1,$h2 l$w1,$h1" $style />\n));
}

sub render_Line {
    my ($self, $glyph) = @_;

    my $style = $self->linestyle( $glyph );

    $glyph->transform($self->{'transform'});

    my $x = $glyph->pixelx();
    my $w = $glyph->pixelwidth();
    my $y = $glyph->pixely();
    my $h = $glyph->pixelheight();

    $self->add_string(qq(<path d="M$x,$y l$w,$h" $style />\n));
}

sub render_Poly {
    my ($self, $glyph) = @_;

    my $style = $self->style( $glyph );
    my @points = @{$glyph->pixelpoints()};
    my $x = shift @points;
    my $y = shift @points;
    my $poly = qq(<path d="M$x,$y);
    while(@points) {
	$x = shift @points;
	$y = shift @points;
	$poly .= " L$x,$y";
    }

    $poly .= qq(z" $style />\n);
    $self->add_string($poly);

}

sub render_Composite {
    my ($self, $glyph) = @_;

    #########
    # draw & colour the bounding area if specified
    # 
    $self->render_Rect($glyph) if(defined $glyph->colour() || defined $glyph->bordercolour());

    #########
    # now loop through $glyph's children
    #
    $self->SUPER::render_Composite($glyph);
}

1;
