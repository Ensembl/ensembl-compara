package Bio::EnsEMBL::Renderer::imagemap;
use strict;
use lib "..";
use Bio::EnsEMBL::Renderer;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Renderer);

sub render_Rect {
    my ($this, $glyph) = @_;

    $glyph->transform($this->{'transform'});

    my $onmouseover = $glyph->onmouseover();
    $onmouseover = (defined $onmouseover)?qq( onmouseover="$onmouseover"):"";

    my $onmouseout = $glyph->onmouseout();
    $onmouseout = (defined $onmouseout)?qq( onmouseout="$onmouseout"):"";

    my $href = $glyph->href();
    $href = qq( href="$href") if(defined $href);

    my $alt = $glyph->id();
    $alt = (defined $alt)?qq( alt="$alt"):qq( alt="");

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

    my $x1 = $glyph->pixelx();
    my $x2 = $glyph->pixelx() + $glyph->pixelwidth();
    my $y1 = $glyph->pixely();
    my $y2 = $glyph->pixely() + $glyph->pixelheight();

    $this->{'canvas'} .= qq(<area coords="$x1 $y1 $x2 $y2"$href$onmouseover$onmouseout$alt>\n) if(defined $href);
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

1;
