
package Bio::EnsEMBL::Renderer::SVG;
use strict;

use Bio::EnsEMBL::Renderer;

use vars qw(@ISA);
use vars qw(%classes);

@ISA = qw(Bio::EnsEMBL::Renderer);

sub init_canvas {
    my ($self, $config, $im_width, $im_height) = @_;
    # we separate out postscript commands from header so that we can
    # do EPS at some future time.

    $im_height = int($im_height);
    $im_width  = int($im_width);

    my @colours = $self->{'colourmap'}->ids();
    my $canvas = qq(<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20001102//EN" "http://www.w3.org/TR/2000/CR-SVG-20001102/DTD/svg-20001102.dtd">
<svg width="$im_width" height="$im_height">
<g style="font-family:Helvetica, Arial, sans-serif;font-size:6pt;font-weight:normal;text-align:left;fill:black;">
).
'';
#<defs>
# <style type="text/css"><![CDATA[
# ).
# ( join "\n", map {
#	".f_$_ { fill-rule:evenodd;fill:".$self->svg_rgb_by_id($_).";opacity:1.00;}\n".
#	".t_$_ { fill:".$self->svg_rgb_by_id($_).";}\n".
#	".s_$_ { stroke:".$self->svg_rgb_by_id($_).";stroke-width:1;}\n".
#	".d_$_ { stroke:".$self->svg_rgb_by_id($_).";stroke-dasharray:1,2,1;stroke-width:1;}\n"
# } @colours ) 
#.qq(
#	.t_transparent, .f_transparent, .s_transparent, .d_transparent { fill:black; opacity: 0; }
# ]]>
# </style>
#</defs>
#);
    $self->canvas($canvas);
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
    return 'rgb('. (join ',',$self->{'colourmap'}->rgb_by_id($id)).')';
}

sub canvas {
    my ($self, $canvas) = @_;

    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'} . qq(</g></svg>\n);
    }
}

sub add_string {
    my ($self,$string) = @_;

    $self->{'canvas'} .= $string;
}

sub style {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour();
    my $gbordercolour = $glyph->bordercolour();

    my $style = 
    	defined $gcolour ? 		qq(fill:).$self->svg_rgb_by_id($gcolour).qq(;opacity:1;stroke:none;) :
     	defined $gbordercolour ?	qq(fill:none;opacity:1;stroke:).$self->svg_rgb_by_id($gbordercolour).qq(;) : 
					qq(fill:none;stroke:none;);
    return qq(style="$style");
}

sub textstyle {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour() ? $self->svg_rgb_by_id($glyph->colour()) : $self->svg_rgb_by_name('black');

    my $style = "stroke:none;opacity:1;fill:$gcolour;";
    return qq(style="$style");
}

sub linestyle {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour();
    my $dotted        = $glyph->dotted();

    my $style =
        defined $gcolour ? 	qq(fill:none;stroke:).$self->svg_rgb_by_id($gcolour).qq(;opacity:1;) :
				qq(fill:none;stroke:none;);
    $style .= qq(stroke-dasharray:1,2,1;) if defined $dotted; 

    return qq(style="$style");
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
