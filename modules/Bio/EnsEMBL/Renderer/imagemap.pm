package Bio::EnsEMBL::Renderer::imagemap;
use strict;
use lib "..";
use Bio::EnsEMBL::Renderer;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Renderer);

#########
# imagemaps are basically strings, so initialise the canvas with ""
# imagemaps also aren't too fussed about width & height boundaries
#
sub init_canvas {
    my ($this, $config, $im_width, $im_height) = @_;
    $this->canvas("");
}

sub render_Rect {
    my ($this, $glyph) = @_;

    $glyph->transform($this->{'config'}->{'transform'});

    my $onmouseover = $glyph->onmouseover();
    $onmouseover = (defined $onmouseover)?qq( onmouseover="$onmouseover"):"";

    my $onmouseout = $glyph->onmouseout();
    $onmouseout = (defined $onmouseout)?qq( onmouseout="$onmouseout"):"";

    my $href = $glyph->href();
    $href = qq( href="$href") if(defined $href);

    my $alt = $glyph->id();
    $alt = (defined $alt)?qq( alt="$alt"):"";

    #########
    # zmenus will override existing href, alt, onmouseover & onmouseout attributes
    # TEST FOR BROWSER SUPPORT
    # 
    my $zmenu = $glyph->zmenu();
    if(defined $zmenu) {
	$href        = qq( href="javascript:void(0);");
	$alt         = qq();
	$onmouseover = qq( onmouseover=") . &JSTools::js_menu($zmenu) . qq(");
    }

#    if($glyph->pixelwidth() == 0 || $glyph->pixelheight() == 0) {
#print STDERR qq(imagemap optimised out [width|height == 0]\n);
#	return;
#    }

    my $x1 = $glyph->pixelx();
    my $x2 = $glyph->pixelx() + $glyph->pixelwidth();
    my $y1 = $glyph->pixely();
    my $y2 = $glyph->pixely() + $glyph->pixelheight() + 1;
#print STDERR qq(imagemap got glyph $glyph pixelheight = ), $glyph->pixelheight(), qq(\n);

    $x1 = 0 if($x1<0);
    $x2 = 0 if($x2<0);
    $y1 = 0 if($y1<0);
    $y2 = 0 if($y2<0);

    #########
    # do range checking here for thresholding out very small regions
    #
#    if($x1 == $x2 || $y1 == $y2) {
#print STDERR qq(imagemap optimised out [start == end]\n);
#	return;
#    }

    $this->{'canvas'} .= qq(<area coords="$x1 $y1 $x2 $y2"$href$onmouseover$onmouseout$alt>\n) if(defined $href);
#print STDERR qq(imagemap $glyph: $x1, $y1, $x2, $y2\n) if(ref($glyph) eq "Bio::EnsEMBL::Glyph::Composite");
}

sub render_Text {
}

sub render_Circle {
}

sub render_Ellipse {
}

sub render_Intron {
}

sub render_Poly {
}

sub render_Composite {
    my ($this, $glyph) = @_;
    return $this->render_Rect($glyph);
}

sub render_Line {
}

1;
