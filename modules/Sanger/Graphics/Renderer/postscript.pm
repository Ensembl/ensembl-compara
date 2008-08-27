#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::Renderer::postscript;
use strict;


use base qw(Sanger::Graphics::Renderer);

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;

  $self->{'colours'} = {};
  # we separate out postscript commands from header so that we can
  # do EPS at some future time.

  $im_height = int($im_height);
  $im_width  = int($im_width);

  my $canvas = qq(%!PS-Adobe-3.0 EPSF-3.0
%%BoundingBox: 0 0 $im_width $im_height
% Created by Sanger::Graphics::Renderer::postscript
%  ensembl-draw cvs module
%  Contact http://www.ensembl.org/
%  Author: rmp\@sanger.ac.uk
%%%%%%%%%
% set default font
%
/pt {6} def
/Helvetica findfont pt scalefont setfont

%%%%%%%%%
% glyph subroutines
%
/np {newpath} def
/mt {moveto} def
/lt {lineto} def
/lr {rlineto} def
/mr {rmoveto} def
/st {stroke} def
/cp {closepath} def
/fi {fill} def
/r  {rect} def

%%%%%%%%%
% draw rectangle "x y w h rect"
%
/rect {np 4 -2 roll moveto dup 0 exch lr exch dup 0 lr exch neg 0 exch lr neg 0 lr cp} def

%%%%%%%%%
% draw text "x y text"
%
/text { pt 0 exch moveto 3 1 roll mr 1 -1 scale show 1 -1 scale} def

%%%%%%%%%
% draw line "x y w h line"
%
/line { 4 -2 roll moveto lr st } def

1 -1 scale
0 -$im_height translate
%%%%%%%%%
% define colours
%
);

  #########
  # define colours which match our internal ids (I rule!)
  #
  for my $id (keys %{$self->{'colourmap'}} ) {
    my ($psr, $psg, $psb) = $self->ps_rgb_by_id($id);
    $canvas .= qq(/_$id { $psr $psg $psb setrgbcolor } def\n);
    $self->{'colours'}{$id}=1;
  }

  my $bgcolour = $config->bgcolor();
  $canvas .= qq(_$bgcolour 0 0 $im_width $im_height r fi\n);
  $self->{'colours'}{$bgcolour}=1;

  $self->canvas($canvas);
}

sub _colour {
  my( $self, $X) = @_;
  return if exists $self->{'colours'}{$X};
  if( $X =~ /^([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$/ ) {
    $self->add_string(sprintf " /_$X { %0.2f %0.2f %0.2f setrgbcolor } def\n", hex($1)/255, hex($2)/255, hex($3)/255 );
    $self->{'colours'}{$X} = 1;
  } else {
    $self->add_string(" /_$X { 1 0 0 setrgbcolor } def\n" );
    $self->{'colours'}{$X} = 1;
  }
}
sub add_canvas_frame {
}

sub ps_rgb_by_id {
  my ($self, $id) = @_;
  my ($psr, $psg, $psb) = $self->{'colourmap'}->rgb_by_name($id);
  $psr /= 255;
  $psg /= 255;
  $psb /= 255;
  return (sprintf("%.2f", $psr), sprintf("%.2f", $psg), sprintf("%.2f", $psb));
}

sub canvas {
  my ($self, $canvas) = @_;

  if(defined $canvas) {
    $self->{'canvas'} = $canvas;
  } else {
    return $self->{'canvas'} . qq(showpage\n);
  }
}

sub add_string {
  my ($self,$string) = @_;

  $self->{'canvas'} .= $string;
}


sub render_Rect {
  my ($self, $glyph) = @_;

  my $gcolour     = $glyph->colour();
  my $gbordercolour = $glyph->bordercolour();

  my $x = $glyph->pixelx();
  my $w = $glyph->pixelwidth();
  my $y = $glyph->pixely();
  my $h = $glyph->pixelheight();

  if(defined $gcolour) {
  
    #########
    # draw filled rect
    #
    $self->_colour($gcolour);
    $self->add_string("_$gcolour $x $y $w $h r fi\n") unless ($gcolour eq "transparent");

  }
  if(defined $gbordercolour) {

    #########
    # draw unfilled rect
    #
    $self->_colour($gbordercolour);
    $self->add_string("_$gbordercolour $x $y $w $h r st\n") unless ($gcolour eq "transparent");
  }
}

sub render_Text {
  my ($self, $glyph) = @_;
  my $font = $glyph->font();

  my $gcolour = $glyph->colour() || "black";
  my $x     = $glyph->pixelx();
  my $y     = $glyph->pixely();
  my $text  = $glyph->text();

  $self->_colour($gcolour);
  $self->add_string(qq(_$gcolour $x $y ($text) text\n)) unless ($gcolour eq "transparent");
}

sub render_Circle {
#  die "Not implemented in postscript yet!";
}

sub render_Ellipse {
#  die "Not implemented in postscript yet!";
}

sub render_Intron {
  my ($self, $glyph) = @_;
  my $gcolour = $glyph->colour();

  my $x1 = $glyph->pixelx();
  my $w1 = int($glyph->pixelwidth() / 2);
  my $y1 = $glyph->pixely() + int($glyph->pixelheight() / 2);
  my $h1 = -int($glyph->pixelheight() / 2);

  $h1 = -$h1 if($glyph->strand() == -1);

  my $x2 = $x1 + $w1;
  my $y2 = $y1 + $h1;
  my $w2 = $w1;
  my $h2 = -$h1;

  $self->_colour($gcolour);
  $self->add_string("_$gcolour $x1 $y1 $w1 $h1 line\n");
  $self->add_string("_$gcolour $x2 $y2 $w2 $h2 line\n");
}

sub render_Line {
  my ($self, $glyph) = @_;

  my $gcolour = $glyph->colour();

  $glyph->transform($self->{'transform'});

  my $x = $glyph->pixelx();
  my $w = $glyph->pixelwidth();
  my $y = $glyph->pixely();
  my $h = $glyph->pixelheight();

  my $beginstyle = "";
  my $endstyle = "";
  if(defined $glyph->dotted()) {
    $beginstyle = qq(gsave [3] 0 setdash);
    $endstyle   = qq(grestore);
  }
  $self->_colour($gcolour);
  $self->add_string("_$gcolour $beginstyle $x $y $w $h line $endstyle\n") unless ($gcolour eq "transparent");
}

sub render_Poly {
  my ($self, $glyph) = @_;
  my $gbordercolour = $glyph->bordercolour();
  my $gcolour     = $glyph->colour();

  my $poly = qq(np );

  my @points = @{$glyph->pixelpoints()};
  my $pairs_of_points = (scalar @points)/ 2;

  my ($lastx, $lasty) = ($points[-2], $points[-1]);

  $poly .= qq($lastx $lasty moveto );

  for(my $i=0;$i<$pairs_of_points;$i++) {
    my $x = shift @points;
    my $y = shift @points;

    $poly .= qq($x $y lt );
  }

  $poly .= qq(cp );

  if(defined $gcolour) {
    $self->_colour($gcolour);
    $poly = qq(_$gcolour $poly fi\n) unless ($gcolour eq "transparent");

  }
  if(defined $gbordercolour) {
    $self->_colour($gbordercolour);
    $poly = qq(_$gbordercolour $poly st\n) unless ($gbordercolour eq "transparent");
  }

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
