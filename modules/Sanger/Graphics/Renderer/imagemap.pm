package Sanger::Graphics::Renderer::imagemap;
use strict;
use Sanger::Graphics::Renderer;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::Renderer);

#########
# imagemaps are basically strings, so initialise the canvas with ""
# imagemaps also aren't too fussed about width & height boundaries
#
sub init_canvas {
    my ($self, $config, $im_width, $im_height) = @_;
    $self->canvas("");
    $self->{'show_zmenus'} = defined( $config->get("_settings","opt_zmenus") ) ? $config->get("_settings","opt_zmenus") : 1;
    $self->{'zmenu_behaviour'} = $config->get("_settings", "zmenu_behaviour");
}

sub add_canvas_frame {
    return;
}

sub render_Rect {
    my ($self, $glyph) = @_;
    my $href = $self->_getHref($glyph);
    return unless(defined $href);

    my $x1 = int( $glyph->{'pixelx'} );
    my $x2 = int( $glyph->{'pixelx'} + $glyph->{'pixelwidth'} );
    my $y1 = int( $glyph->{'pixely'} );
    my $y2 = int( $glyph->{'pixely'} + $glyph->{'pixelheight'} );

    $x1 = 0 if($x1<0);
    $x2 = 0 if($x2<0);
    $y1 = 0 if($y1<0);
    $y2 = 0 if($y2<0);

    $y2 += 1;
    $x2 += 1;

    $self->{'canvas'} = qq(<area coords="$x1 $y1 $x2 $y2"$href>\n).$self->{'canvas'};
}

sub render_Text {
    my ($self, $glyph) = @_;
    $self->render_Rect($glyph);
}

sub render_Circle {
  my ($self, $glyph) = @_; 
  my $href = $self->_getHref($glyph); 
  return unless(defined $href); 

  my ($cx, $cy) = $glyph->pixelcentre();
  my $cw = $glyph->{'pixelwidth'}/2;
  
  my $x1 = int($cx - $cw);
  my $x2 = int($cx + $cw);
  my $y1 = int($cy - $cw);
  my $y2 = int($cy + $cw);
  
  $x1 = 0 if($x1<0);
  $x2 = 0 if($x2<0);
  $y1 = 0 if($y1<0);
  $y2 = 0 if($y2<0);
  
  $y2 += 1;
  $x2 += 1;
  
  $self->{'canvas'} = qq(<area coords="$x1 $y1 $x2 $y2"$href>\n).$self->{'canvas'}; 
}

sub render_Ellipse {
}

sub render_Intron {
}

sub render_Poly {
    my ($self, $glyph) = @_;
    my $href = $self->_getHref( $glyph );
    return unless(defined $href);

    my $pointslist = join ' ',map { int } @{$glyph->pixelpoints()};
    $self->{'canvas'} = qq(<area shape="poly" coords="$pointslist"$href>\n).$self->{'canvas'} ; 
}

sub render_Space {
    my ($self, $glyph) = @_;
    return $self->render_Rect($glyph);
}

sub render_Composite {
    my ($self, $glyph) = @_;
    $self->render_Rect($glyph);
}

sub render_Line {
}

sub _getHref {
    my ($self, $glyph) = @_;
    my $onmouseover = $glyph->{'onmouseover'};
    my $onmouseout  = $glyph->{'onmouseout'};
    my $href        = $glyph->{'href'};
    my $alt         = $glyph->{'id'};
    my $title       = "";
    $onmouseover    = (defined $onmouseover) ? qq( onmouseover="$onmouseover") : "";
    $onmouseout     = (defined $onmouseout)  ? qq( onmouseout="$onmouseout") : "";
    $href           = qq( href="$href") if(defined $href);
    $alt            = (defined $alt) ? qq( alt="$alt")  : "";

    #########
    # zmenus will override existing href, alt, onmouseover & onmouseout attributes
    #
    if($self->{'show_zmenus'} == 1) {
      my $zmenu = $glyph->{'zmenu'};

      my $ua    = $ENV{'HTTP_USER_AGENT'} || "";
      my $ns4   = undef;
      if($ua =~ /Mozilla\/4/ && $ua !~ /MSIE/) {
	$ns4 = 1;
      }

      if(defined $zmenu) {
	my $behaviour = $self->{'zmenu_behaviour'} || "onmouseover";
	my $jsmenu    = &Sanger::Graphics::JSTools::js_menu($zmenu);
	$alt          = "";
       	$href      = qq( href="javascript:void(0)") unless(defined $href);

	my $ret = "return false;";
	if($ns4) {
	  $behaviour = "onmouseover";
	  $ret       = "";
	}

	$onmouseover = qq( $behaviour="$jsmenu$ret");
      }
    }
    return "$href$onmouseover$onmouseout$alt$title" if(defined $href);
    return undef;
}

1;
