#########
# Author:        rmp@sanger.ac.uk
# Maintainer:    webmaster@sanger.ac.uk
# Created:       2001
# Last Modified: $Date$
# Id:            $Id$
# Source:        $Source$
# $HeadURL$
#
package Sanger::Graphics::Renderer::imagemap;
use strict;
use warnings;
no warnings 'uninitialized';
use base qw(Sanger::Graphics::Renderer);
use Sanger::Graphics::JSTools;
use CGI qw(escapeHTML);

our $VERSION = do { my @r = (q$Revision$ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

#########
# imagemaps are basically strings, so initialise the canvas with ""
# imagemaps also aren't too fussed about width & height boundaries
#
sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $self->canvas(q());

  $self->{'show_zmenus'}     = defined( $config->get_parameter('opt_zmenus') ) ? $config->get_parameter('opt_zmenus') : 1;
  $self->{'zmenu_zclick'}    = $config->get_parameter('opt_zclick');
  $self->{'zmenu_behaviour'} = $config->get_parameter('zmenu_behaviour') || 'onmouseover';
  return;
}

sub add_canvas_frame {
  return;
}

sub render_Rect {
  my ($self, $glyph) = @_;
  my $href = $self->_getHref($glyph);
  $href or return;

  my $x1 = int $glyph->{'pixelx'};
  my $x2 = int $glyph->{'pixelx'} + $glyph->{'pixelwidth'};
  my $y1 = int $glyph->{'pixely'};
  my $y2 = int $glyph->{'pixely'} + $glyph->{'pixelheight'};

  $x1 = 0 if($x1<0);
  $x2 = 0 if($x2<0);
  $y1 = 0 if($y1<0);
  $y2 = 0 if($y2<0);

  $y2 += 1;
  $x2 += 1;

  $self->{'canvas'} = qq(<area coords="$x1 $y1 $x2 $y2"$href />\n).$self->{'canvas'};
  return;
}

sub render_Text {
  my ($self, $glyph) = @_;
  return $self->render_Rect($glyph);
}

sub render_Circle {
  my ($self, $glyph) = @_;
  my $href = $self->_getHref($glyph);
  $href or return;

  my ($cx, $cy) = $glyph->pixelcentre();
  my $cw = $glyph->{'pixelwidth'}/2;

  my $x1 = int $cx - $cw;
  my $x2 = int $cx + $cw;
  my $y1 = int $cy - $cw;
  my $y2 = int $cy + $cw;

  $x1 = 0 if($x1<0);
  $x2 = 0 if($x2<0);
  $y1 = 0 if($y1<0);
  $y2 = 0 if($y2<0);

  $y2 += 1;
  $x2 += 1;

  $self->{'canvas'} = qq(<area coords="$x1 $y1 $x2 $y2"$href />\n).$self->{'canvas'};
  return;
}

sub render_Ellipse {
}

sub render_Intron {
}

sub render_Poly {
  my ($self, $glyph) = @_;
  my $href = $self->_getHref($glyph);
  $href or return;

  my $pointslist = join q( ), map { int } @{$glyph->pixelpoints()};
  $self->{'canvas'} = qq(<area shape="poly" coords="$pointslist"$href />\n).$self->{'canvas'} ;
  return;
}

sub render_Space {
  my ($self, $glyph) = @_;
  return $self->render_Rect($glyph);
}

sub render_Composite {
  my ($self, $glyph) = @_;
  return $self->render_Rect($glyph);
}

sub render_Line {
  my ($self, $glyph) = @_;
  my $href = $self->_getHref($glyph);
  $href or return;

  my $x1     = $glyph->{'pixelx'} + 0;
  my $y1     = $glyph->{'pixely'} + 0;
  my $x2     = $x1 + $glyph->{'pixelwidth'};
  my $y2     = $y1 + $glyph->{'pixelheight'};
  my $click_width = exists( $glyph->{'clickwidth'} ) ? $glyph->{'clickwidth'} : 1;
  my $len    = sqrt( ($y2-$y1)*($y2-$y1) + ($x2-$x1)*($x2-$x1) );
  my ($u_x, $u_y ) = $len > 0 ? ( ($x2-$x1) * $click_width / $len, ($y2-$y1) * $click_width /$len ) : ( $click_width , 0 ) ; 
  my $pointslist = join ' ', map {int($_)} (
    $x2+$u_x,$y2+$u_y,
    $x2+$u_y,$y2-$u_x,
    $x1+$u_y,$y1-$u_x,
    $x1-$u_x,$y1-$u_y,
    $x1-$u_y,$y1+$u_x,
    $x2-$u_y,$y2+$u_x,
    $x2+$u_x,$y2+$u_y );

  $self->{'canvas'} = qq(<area shape="poly" coords="$pointslist"$href />\n).$self->{'canvas'} ;
  return;

}

sub _getHref {
  my( $self, $glyph ) = @_;

  my %actions = ();

  foreach (qw(title onmouseover onmouseout onclick alt href target)) {
    my $X = $glyph->$_;
    if(defined $X) {
      $actions{$_} = $X;

      if($_ eq 'alt' || $_ eq 'title') {
	$actions{'title'} = CGI::escapeHTML($X);
	$actions{'alt'}   = CGI::escapeHTML($X);
      }
    }
  }

  if($self->{'show_zmenus'} == 1) {
    my $zmenu = undef; # $glyph->zmenu();
    if(defined $zmenu && ((ref $zmenu  eq q()) ||
			  (ref $zmenu eq 'HASH')
			  && scalar keys(%{$zmenu}) > 0)) {

      if($self->{'zmenu_zclick'} || ($self->{'zmenu_behaviour'} =~ /onClick/mix)) {
#        $actions{'alt'}     = 'Click for Menu';
        $actions{'onclick'} = Sanger::Graphics::JSTools::js_menu($zmenu).q(;return false;);
        delete $actions{'onmouseover'};
        delete $actions{'onmouseout'};

      } else {
        delete $actions{'alt'};
        $actions{'onmouseover'} = Sanger::Graphics::JSTools::js_menu($zmenu);
      }
      $actions{'href'} ||= 'javascript:void(0);';
    }
  }

  if(keys %actions && !$actions{'href'}) {
    $actions{'nohref'} = 'nohref';
    delete $actions{'href'};
  }

  return join q(), map { qq( $_="$actions{$_}") } keys %actions;
}

1;
