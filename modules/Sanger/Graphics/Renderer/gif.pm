#########
# Author:        rmp@sanger.ac.uk
# Maintainer:    webmaster@sanger.ac.uk
# Created:       2001
# Last Modified: dj3 2005-09-01 add chevron line style a la UCSC (ticket 25769)
#                dj3 2005-08-31 add tiling ability to Polys (was just Rects)
#                rmp 2005-08-09 hatched fill-pattern support (subs tile and render_Rect): set $glyph->{'hatched'} = true|false and $glyph->{'hatchcolour'} = 'darkgrey';
#                rmp 2004-12-14 initial stringFT support
#
package Sanger::Graphics::Renderer::gif;
use strict;
#use warnings;
use base qw(Sanger::Graphics::Renderer);
use GD;
## use GD::Text::Align;
# use Math::Bezier;

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $self->{'im_width'}  = $im_width;
  $self->{'im_height'} = $im_height;

  if( $self->{'config'}->can('species_defs') ) {
    my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE || {};
    $self->{'ttf_path'} ||= $ST->{'GRAPHIC_TTF_PATH'};
  }
  $self->{'ttf_path'}   ||= '/usr/local/share/fonts/ttfonts/';

  my $canvas           = GD::Image->new($im_width, $im_height);

  $canvas->colorAllocate($config->colourmap->rgb_by_name($config->bgcolor()));
  $self->canvas($canvas);
}

sub add_canvas_frame {
  my ($self, $config, $im_width, $im_height) = @_;
	
  return;
  return if (defined $config->{'no_image_frame'});
	
  # custom || default image frame colour
  my $imageframecol = $config->{'image_frame_colour'} || 'black';
  my $framecolour   = $self->colour($imageframecol);

  # for contigview bottom box we need an extra thick border...
  if ($config->script() eq 'contigviewbottom'){		
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
  $id           ||= 'black';
  $self->{'_GDColourCache'}->{$id} ||= $self->{'canvas'}->colorAllocate($self->{'colourmap'}->rgb_by_name($id));
  return $self->{'_GDColourCache'}->{$id};
}

#########
# build mini GD images which can be used as fill patterns
# should probably support different density hatching too
#
sub tile {
  my ($self, $id, $pattern) = @_;
  my $bg_color = 'white';
  $id      ||= 'darkgrey';
  $pattern ||= 'hatch_ne';

  my $key = join ':', $bg_color, $id, $pattern;
  unless($self->{'_GDTileCache'}->{$key}) {
    my $tile;
    my $pattern_def = $Sanger::Graphics::Renderer::patterns->{$pattern};
    if( $pattern_def ) {
      $tile = GD::Image->new(@{ $pattern_def->{'size'}} );
      my $bg   = $tile->colorAllocate($self->{'colourmap'}->rgb_by_name($bg_color));
      my $fg   = $tile->colorAllocate($self->{'colourmap'}->rgb_by_name($id));
      $tile->transparent($bg);
      $tile->line(@$_, $fg ) foreach( @{$pattern_def->{'lines'}||[]});
      foreach my $poly_def ( @{$pattern_def->{'polys'}||[]} ) {
        my $poly = new GD::Polygon;
        foreach( @$poly_def ) {
          $poly->addPt( @$_ );
        } 
        $tile->filledPolygon($poly,$fg);
      }
    }
    $self->{'_GDTileCache'}->{$key} = $tile;
  }
  return $self->{'_GDTileCache'}->{$key};
}

sub render_Rect {
  my ($self, $glyph) = @_;
  my $canvas         = $self->{'canvas'};
  my $gcolour        = $glyph->{'colour'};
  my $gbordercolour  = $glyph->{'bordercolour'};

  # (avc)
  # this is a no-op to let us define transparent glyphs
  # and which can still have an imagemap area BUT make
  # sure it is smaller than the carrent largest glyph in
  # this glyphset because its height is not recorded!
  if (defined $gcolour && $gcolour eq 'transparent') {
    return;
  }

  my $bordercolour  = $self->colour($gbordercolour);
  my $colour        = $self->colour($gcolour);

  my $x1 = $glyph->{'pixelx'};
  my $x2 = $glyph->{'pixelx'} + $glyph->{'pixelwidth'};
  my $y1 = $glyph->{'pixely'};
  my $y2 = $glyph->{'pixely'} + $glyph->{'pixelheight'};

  $canvas->filledRectangle($x1, $y1, $x2, $y2, $colour) if(defined $gcolour);
  if($glyph->{'pattern'}) {
    $canvas->setTile($self->tile($glyph->{'patterncolour'}, $glyph->{'pattern'}));
    $canvas->filledRectangle($x1, $y1, $x2, $y2, gdTiled);
  }

  $canvas->rectangle($x1, $y1, $x2, $y2, $bordercolour) if(defined $gbordercolour);
}

sub render_Text {
  my ($self, $glyph) = @_;

  return unless $glyph->{'text'};
  my $font   = $glyph->font();
  my $colour = $self->colour($glyph->{'colour'});

  ########## Stock GD fonts
  my $left      = $glyph->{'pixelx'}    || 0;
  my $textwidth = $glyph->{'textwidth'} || 0;
  my $top       = $glyph->{'pixely'}    || 0;
  my $textheight = $glyph->{'pixelheight'} || 0;
  my $halign    = $glyph->{'halign'}    || '';

  if($halign eq 'right' ) {
    $left += $glyph->{'pixelwidth'} - $textwidth;

  } elsif($halign ne 'left' ) {
    $left += ($glyph->{'pixelwidth'} - $textwidth)/2;
  }

  if($font eq 'Tiny') {
    $self->{'canvas'}->string(gdTinyFont,  $left, $top, $glyph->text(), $colour);

  } elsif($font eq 'Small') {
    $self->{'canvas'}->string(gdSmallFont, $left, $top, $glyph->text(), $colour);

  } elsif($font eq 'MediumBold') {
    $self->{'canvas'}->string(gdMediumBoldFont, $left, $top, $glyph->text(), $colour);

  } elsif($font eq 'Large') {
    $self->{'canvas'}->string(gdLargeFont, $left, $top, $glyph->text(), $colour);

  } elsif($font eq 'Giant') {
    $self->{'canvas'}->string(gdGiantFont, $left, $top, $glyph->text(), $colour);

  } elsif($font) {
    #########
    # If we didn't recognise it already, assume it's a TrueType font
    $self->{'canvas'}->stringTTF( $colour, $self->{'ttf_path'}.$font.'.ttf', $glyph->ptsize, 0, $left, $top+$textheight, $glyph->{'text'} );

###  my ($cx, $cy)      = $glyph->pixelcentre();
###  my $xpt = $glyph->{'pixelx'} + 
###            ( $glyph->{'halign'} eq 'left' ? 0 : $glyph->{'halign'} eq 'right' ? 1 : 0.5 ) * $glyph->{'pixelwidth'};
###    my $X = GD::Text::Align->new( $self->{'canvas'},
###      'valign' => $glyph->{'valign'} || 'center', 'halign' => $glyph->{'halign'} || 'center',
###      'colour' => $colour,                        'font'   => "$self->{'ttf_path'}$font.ttf",
###      'ptsize' => $glyph->ptsize(),               'text'   => $glyph->text()
###    );
###    $X->draw( $xpt, $cy, $glyph->angle()||0 );
  }
}

sub render_Circle {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $gcolour        = $glyph->{'colour'};
  my $colour         = $self->colour($gcolour);
  my $filled         = $glyph->filled();
  my ($cx, $cy)      = $glyph->pixelcentre();

  $canvas->arc(
	       $cx,
	       $cy,
	       $glyph->{'pixelwidth'},
	       $glyph->{'pixelheight'},
	       0,
	       360,
	       $colour
	      );
  $canvas->fillToBorder($cx, $cy, $colour, $colour) if ($filled && $cx <= $self->{'im_width'});
}

sub render_Ellipse {
}

sub render_Intron {
  my ($self, $glyph) = @_;

  my ($colour, $xstart, $xmiddle, $xend, $ystart, $ymiddle, $yend, $strand, $gy);
  $colour  = $self->colour($glyph->{'colour'});
  $gy      = $glyph->{'pixely'};
  $strand  = $glyph->{'strand'};
  $xstart  = $glyph->{'pixelx'};
  $xend    = $xstart + $glyph->{'pixelwidth'};
  $xmiddle = $xstart + $glyph->{'pixelwidth'} / 2;
  $ystart  = $gy + $glyph->{'pixelheight'}/2;
  $yend    = $ystart;
  $ymiddle = $ystart + ( $strand == 1 ? -1 : 1 ) * $glyph->{'pixelheight'} * 3/8;

  $self->{'canvas'}->line($xstart, $ystart, $xmiddle, $ymiddle, $colour);
  $self->{'canvas'}->line($xmiddle, $ymiddle, $xend, $yend, $colour);
}

sub render_Line {
  my ($self, $glyph) = @_;

  my $colour = $self->colour($glyph->{'colour'});
  my $x1     = $glyph->{'pixelx'} + 0;
  my $y1     = $glyph->{'pixely'} + 0;
  my $x2     = $x1 + $glyph->{'pixelwidth'};
  my $y2     = $y1 + $glyph->{'pixelheight'};

  if(defined $glyph->dotted()) {
    $self->{'canvas'}->setStyle(gdTransparent,gdTransparent,gdTransparent,$colour,$colour,$colour);
    $self->{'canvas'}->line($x1, $y1, $x2, $y2, gdStyled);
  } else {
    $self->{'canvas'}->line($x1, $y1, $x2, $y2, $colour);
  }

  if($glyph->chevron()) {
    my $flip = ($glyph->{'strand'}<0);
    my $len  = $glyph->chevron(); $len=4 if $len<4;
    my $n    = int(($glyph->{'pixelwidth'} + $glyph->{'pixelheight'})/$len);
    my $dx   = $glyph->{'pixelwidth'}  / $n; $dx*=-1 if $flip;
    my $dy   = $glyph->{'pixelheight'} / $n; $dy*=-1 if $flip;
    my $ix   = int($dx);
    my $iy   = int($dy);
    my $i1x  = int(-0.5*($ix-$iy));
    my $i1y  = int(-0.5*($iy+$ix));
    my $i2x  = int(-0.5*($ix+$iy));
    my $i2y  = int(-0.5*($iy-$ix));

    for (;$n;$n--) {
      my $tx = int($n*$dx)+($flip ? $x2 : $x1);
      my $ty = int($n*$dy)+($flip ? $y2 : $y1);
      $self->{'canvas'}->line($tx, $ty, $tx+$i1x, $ty+$i1y, $colour);
      $self->{'canvas'}->line($tx, $ty, $tx+$i2x, $ty+$i2y, $colour);
    }
  }
}

sub render_Poly {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $bordercolour   = $self->colour($glyph->{'bordercolour'});
  my $colour         = $self->colour($glyph->{'colour'});
  my $poly           = new GD::Polygon;

  return unless(defined $glyph->pixelpoints());

  my @points = @{$glyph->pixelpoints()};
  my $pairs_of_points = (scalar @points)/ 2;

  for(my $i=0;$i<$pairs_of_points;$i++) {
    my $x = shift @points;
    my $y = shift @points;
    $poly->addPt($x,$y);
  }

  if($glyph->{colour}) {
    $canvas->filledPolygon($poly, $colour);
  }

  if($glyph->{'pattern'}) {
    $canvas->setTile($self->tile($glyph->{'patterncolour'}, $glyph->{'pattern'}));
    $canvas->filledPolygon($poly, gdTiled);
  }

  if($glyph->{bordercolour}) {
    $canvas->polygon($poly, $bordercolour);
  }
}

sub render_Composite {
  my ($self, $glyph, $Ta) = @_;

  #########
  # draw & colour the fill area if specified
  #
  $self->render_Rect($glyph) if(defined $glyph->{'colour'});

  #########
  # now loop through $glyph's children
  #
  $self->SUPER::render_Composite($glyph,$Ta);

  #########
  # draw & colour the bounding area if specified
  #
  $glyph->{'colour'} = undef;
  $self->render_Rect($glyph) if(defined $glyph->{'bordercolour'});
}

#sub render_Bezier {
#  my ($self, $glyph) = @_;
#
#  my $colour = $self->colour($glyph->{'colour'});
#
#  return unless(defined $glyph->pixelpoints());
#
#  my @coords = @{$glyph->pixelpoints()};
#  my $bezier = Math::Bezier->new(\@coords);
#  my $points = $bezier->curve($glyph->{'samplesize'}||20);
#
#  my ($lx,$ly);
#  while (@$points) {
#    my ($x, $y) = splice(@$points, 0, 2);
#
#    $self->{'canvas'}->line($lx, $ly, $x, $y, $colour) if(defined($lx) && defined($ly));
#    ($lx, $ly) = ($x, $y);
#  }
#}

sub render_Sprite {
  my ($self, $glyph) = @_;
  my $spritename     = $glyph->{'sprite'} || 'unknown';
  my $config         = $self->config();

  unless(exists $config->{'_spritecache'}->{$spritename}) {
    my $libref = $config->get_parameter(  'spritelib');
    my $lib    = $libref->{$glyph->{'spritelib'} || 'default'};
    my $fn     = "$lib/$spritename.gif";

    unless( -r $fn ){
      warn( "$fn is unreadable by uid/gid" );
      return;
    }

    $config->{'_spritecache'}->{$spritename} = GD::Image->newFromGif($fn);

    if( !$config->{'_spritecache'}->{$spritename} ) {
      $config->{'_spritecache'}->{$spritename} = GD::Image->newFromGif("$lib/missing.gif");
    }
  }

  my $sprite = $config->{'_spritecache'}->{$spritename};

  return unless $sprite;
  my ($width, $height) = $sprite->getBounds();

  my $METHOD = $self->{'canvas'}->can('copyRescaled') ? 'copyRescaled' : 'copyResized' ;
  $self->{'canvas'}->$METHOD($sprite,
			     $glyph->{'pixelx'},
			     $glyph->{'pixely'},
			     0,
			     0,
			     $glyph->{'pixelwidth'}  || 1,
			     $glyph->{'pixelheight'} || 1,
			     $width,
			     $height);
}

1;
