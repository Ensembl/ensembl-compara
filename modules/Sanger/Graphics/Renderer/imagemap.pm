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
 #   print STDERR "XX: $self->{'show_zmenus'}\n";
}

sub add_canvas_frame {
    my ($self, $config, $im_width, $im_height) = @_;
	return(); # no-op!	
}

sub render_Rect {
    my ($self, $glyph) = @_;
    my $href = $self->_getHref($glyph);
	return unless(defined $href);

    my $x1 = int( $glyph->pixelx() );
    my $x2 = int( $glyph->pixelx() + $glyph->pixelwidth() );
    my $y1 = int( $glyph->pixely() );
    my $y2 = int( $glyph->pixely() + $glyph->pixelheight() );

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
#    $self->SUPER::render_Composite($glyph);
}

sub render_Line {
}

sub _getHref {
  my ($self, $glyph) = @_;

  my %actions = {}; 
  my @X = qw( onmouseover onmouseout alt href );
  foreach(@X) {
    my $X = $glyph->$_;
    $actions{$_} = $X if defined $X;
  }
  if($self->{'show_zmenus'}==1) {
    my $zmenu = $glyph->zmenu();
    if(defined $zmenu && keys(%$zmenu)>0 ) {
      if($self->{'config'}->get('_settings','opt_zclick')==1 ) {
        $actions{'ondoubleclick'} = $actions{'href'}        if exists $actions{'href'};
        $actions{'onclick'}       = &Sanger::Graphics::JSTools::js_menu($zmenu).";return false;";
        delete $actions{'onmouseover'};
        delete $actions{'onmouseout'};
        $actions{'alt'} = "Click for Menu";
      } else {
        delete $actions{'alt'};
        $actions{'onmouseover'} = &Sanger::Graphics::JSTools::js_menu($zmenu);
      }
      $actions{'href'} ||= qq"javascript:void(0)";
    }
  }
  return join ' ', map { qq($_="$actions{$_}") } keys %actions;
}
1;
