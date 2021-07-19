=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::Renderer::gif;

use strict;
use warnings;
no warnings "uninitialized";

use GD;

use base qw(EnsEMBL::Draw::Renderer);

use List::Util qw(max);

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $self->{'im_width'}     = $im_width;
  $self->{'im_height'}    = $im_height;

  if( $self->{'config'}->can('species_defs') ) {
    $self->{'ttf_path'} ||= $self->{'config'}->species_defs->get_font_path;
  }
  $self->{'ttf_path'}   ||= '/usr/local/share/fonts/ttfonts/';

  my $canvas           = GD::Image->new(
	  $im_width  * $self->{'sf'},
		$im_height * $self->{'sf'}
  );

  $canvas->colorAllocate($config->colourmap->rgb_by_name($config->get_parameter('bgcolor')));
  $self->canvas($canvas);
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
# This is also a good place to apply contrast
sub colour {
  my ($self, $id, $alpha) = @_;
  $id           ||= 'black';

  my @rgb = $self->{'colourmap'}->rgb_by_name($id);
  push @rgb,int(127*$alpha) if $alpha;
  @rgb = $self->{'colourmap'}->hivis($self->{'contrast'},@rgb);
  if ($alpha) {
    $self->{'_GDColourCacheAlpha'}->{$id}{$alpha} ||= $self->{'canvas'}->colorAllocateAlpha(@rgb);
    return $self->{'_GDColourCacheAlpha'}->{$id}{$alpha};
  } else {
    $self->{'_GDColourCache'}->{$id} ||= $self->{'canvas'}->colorAllocate(@rgb);
    return $self->{'_GDColourCache'}->{$id};
  }
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
    my $pattern_def = $EnsEMBL::Draw::Renderer::patterns->{$pattern};
    if( $pattern_def ) {
      $tile = GD::Image->new(@{ $pattern_def->{'size'}} );
      my $bg   = $tile->colorAllocate($self->{'colourmap'}->rgb_by_name($bg_color));
      my $fg   = $tile->colorAllocate($self->{'colourmap'}->rgb_by_name($id));
      $tile->transparent($bg);
      $tile->line(@$_, $fg ) foreach( @{$pattern_def->{'lines'}||[]});
      foreach my $poly_def ( @{$pattern_def->{'polys'}||[]} ) {
        my $poly = GD::Polygon->new;
        foreach( @$poly_def ) {
          $poly->addPt( map { $_ } @$_ );
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
  my $alpha          = $glyph->{'alpha'};

  # (avc)
  # this is a no-op to let us define transparent glyphs
  # and which can still have an imagemap area BUT make
  # sure it is smaller than the carrent largest glyph in
  # this glyphset because its height is not recorded!
  if (defined $gcolour && $gcolour eq 'transparent') {
    return;
  }

  my $bordercolour  = $self->colour($gbordercolour, $alpha);
  my $colour        = $self->colour($gcolour, $alpha);

  my $x1 = $self->{sf} *   $glyph->{'pixelx'};
  my $x2 = $self->{sf} * ( $glyph->{'pixelx'} + $glyph->{'pixelwidth'} );
  my $y1 = $self->{sf} *   $glyph->{'pixely'};
  my $y2 = $self->{sf} * ( $glyph->{'pixely'} + $glyph->{'pixelheight'} );

  $canvas->alphaBlending(1) if $alpha;

  $canvas->filledRectangle($x1, $y1, $x2, $y2, $colour) if(defined $gcolour);
  if($glyph->{'pattern'}) {
    $canvas->setTile($self->tile($glyph->{'patterncolour'}, $glyph->{'pattern'}));
    $canvas->filledRectangle($x1, $y1, $x2, $y2, gdTiled);
  }

  $canvas->rectangle($x1, $y1, $x2, $y2, $bordercolour) if(defined $gbordercolour);
}

sub render_Text {
  my ($self, $glyph) = @_;

  return unless length $glyph->{'text'};
  my $font   = $glyph->font();
  my $colour = $self->colour($glyph->{'colour'}, $glyph->{'alpha'});

  ########## Stock GD fonts
  my $left       = $self->{sf} * $glyph->{'pixelx'}    || 0;
  my $textwidth  = $self->{sf} * $glyph->{'textwidth'} || 0;
  my $top        = $self->{sf} * $glyph->{'pixely'}    || 0;
  my $textheight = $self->{sf} * $glyph->{'pixelheight'} || 0;
  my $halign     = $glyph->{'halign'}    || '';

  if($halign eq 'right' ) {
    $left += $glyph->{'pixelwidth'} * $self->{sf} - $textwidth;

  } elsif($halign ne 'left' ) {
    $left += ($glyph->{'pixelwidth'} * $self->{sf} - $textwidth)/2;
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
    $self->{'canvas'}->stringTTF( $colour, $self->{'ttf_path'}.$font.'.ttf', $self->{sf} * $glyph->ptsize, 0, $left, $top+$textheight, $glyph->{'text'} );

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
  my $colour         = $self->colour($gcolour, $glyph->{'alpha'});
  my $filled         = $glyph->filled();
  my ($cx, $cy)      = $glyph->pixelcentre();

  my $method = $filled ? 'filledEllipse' : 'ellipse';
  $canvas->$method( 
    $self->{sf} * ($cx-$glyph->{'pixelwidth'}/2),
    $self->{sf} * ($cy-$glyph->{'pixelheight'}/2),
    $self->{sf} *  $glyph->{'pixelwidth'},
    $self->{sf} *  $glyph->{'pixelheight'},
    $colour
   );
#  $canvas->fillToBorder($cx, $cy, $colour, $colour) if ($filled && $cx <= $self->{'im_width'});
}

sub render_Ellipse {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $gcolour        = $glyph->{'colour'};
  my $colour         = $self->colour($gcolour, $glyph->{'alpha'});
  my $filled         = $glyph->filled();
  my ($cx, $cy)      = $glyph->pixelcentre();

  my $method = $filled ? 'filledEllipse' : 'ellipse';
  $canvas->$method( 
    $self->{sf} * ($cx-$glyph->{'pixelwidth'}/2),
    $self->{sf} * ($cy-$glyph->{'pixelheight'}/2),
    $self->{sf} *  $glyph->{'pixelwidth'},
    $self->{sf} *  $glyph->{'pixelheight'},
    $colour
   );
}

sub render_Arc {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $gcolour        = $glyph->{'colour'};
  my $colour         = $self->colour($gcolour, $glyph->{'alpha'});
  my $filled         = $glyph->filled();
  my ($cx, $cy)      = $glyph->pixelcentre();

  $canvas->setThickness($self->{sf} * $glyph->{'thickness'});

  my $method = $filled ? 'filledArc' : 'arc';
  $canvas->$method(
    $self->{sf} * ($cx-$glyph->{'pixelwidth'}/2),
    $self->{sf} * ($cy-$glyph->{'pixelheight'}/2),
    $self->{sf} *  $glyph->{'pixelwidth'},
    $self->{sf} *  $glyph->{'pixelheight'},
    $self->{sf} *  $glyph->{'start_point'},
    $self->{sf} *  $glyph->{'end_point'},
    $colour
   );

  ## Reset brush thickness
  $canvas->setThickness(1);
}



sub render_Intron {
  my ($self, $glyph) = @_;

  my ($colour, $xstart, $xmiddle, $xend, $ystart, $ymiddle, $yend, $strand, $gy);
  $colour  = $self->colour($glyph->{'colour'}, $glyph->{'alpha'});
  $gy      = $self->{sf} * $glyph->{'pixely'};
  $strand  = $glyph->{'strand'};
  $xstart  = $self->{sf} * $glyph->{'pixelx'};
  $xend    = $xstart + $self->{sf} * $glyph->{'pixelwidth'};
  $xmiddle = $xstart + $self->{sf} * $glyph->{'pixelwidth'} / 2;
  $ystart  = $gy + $self->{sf} * $glyph->{'pixelheight'}/2;
  $yend    = $ystart;
  $ymiddle = $ystart + $self->{sf} * ( $strand == 1 ? -1 : 1 ) * $glyph->{'pixelheight'} * 3/8;

  $self->{'canvas'}->setAntiAliased($colour);
  $self->{'canvas'}->line($xstart, $ystart, $xmiddle, $ymiddle, gdAntiAliased);
  $self->{'canvas'}->line($xmiddle, $ymiddle, $xend, $yend, gdAntiAliased);
}

sub render_Line {
  my ($self, $glyph) = @_;

  my $colour = $self->colour($glyph->{'colour'}, $glyph->{'alpha'});
  my $x1     = $self->{sf} * $glyph->{'pixelx'} + 0;
  my $y1     = $self->{sf} * $glyph->{'pixely'} + 0;
  my $x2     = $x1 + $self->{sf} * $glyph->{'pixelwidth'};
  my $y2     = $y1 + $self->{sf} * $glyph->{'pixelheight'};

  if (defined $glyph->dotted && $glyph->dotted) {
    $self->{'canvas'}->setStyle($glyph->dotted eq 'small' ? (gdTransparent, $colour, $colour) : (gdTransparent, gdTransparent, gdTransparent, $colour, $colour, $colour));
    $self->{'canvas'}->line($x1, $y1, $x2, $y2, gdStyled);
  } else {
    $self->{'canvas'}->setAntiAliased($colour);
    $self->{'canvas'}->line($x1, $y1, $x2, $y2, gdAntiAliased);
  }

  if($glyph->chevron()) {
    my $flip = ($glyph->{'strand'}<0);
    my $len  = $glyph->chevron(); $len=4 if $len<4;
    my $n    = int($self->{sf} * ($glyph->{'pixelwidth'} + $glyph->{'pixelheight'})/$len);
    my $dx   = $self->{sf} * $glyph->{'pixelwidth'}  / $n; $dx*=-1 if $flip;
    my $dy   = $self->{sf} * $glyph->{'pixelheight'} / $n; $dy*=-1 if $flip;
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

sub render_Histogram {
### Render a track as a series of rectangles of the same width but
### varying heights
### N.B. this is much faster than drawing individual rectangles
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $colour         = $self->colour($glyph->{'colour'}, $glyph->{'alpha'});

  my $points = $glyph->{'pixelpoints'};
  return unless defined $points;

  my $max = defined($glyph->{'max'}) ? $glyph->{'max'} : 1000;
  my $min = defined($glyph->{'min'}) ? $glyph->{'min'} : 0;

  my $x1 = $self->{'sf'} *   $glyph->{'pixelx'};
  my $x2 = $self->{'sf'} * ( $glyph->{'pixelx'} + $glyph->{'pixelunit'} );
  my $y1 = $self->{'sf'} * ( $glyph->{'pixely'} + $min );
  my $y2 = $self->{'sf'} * ( $glyph->{'pixely'} + $glyph->{'pixelheight'} + $min);

  my $step = $glyph->{'pixelunit'} * $self->{'sf'};
  my $mul = ($y2-$y1) / ($max - $min);

  foreach my $p (@$points) {
    my $truncated = 0;
    if ($p > $max) {
      ## Truncate values that lie outside the range we want to draw
      $p = $max;
      $truncated = 1 if $glyph->{'truncate_colour'};
    }
    my $yb = $y2 - max($p,$min) * $mul;
    $canvas->filledRectangle($x1,$yb,$x2,$y2,$colour);
    ## Mark truncation with a contrasting line at the top of the bar
    if ($truncated) {
      my $yc = $yb + 1;
      $canvas->filledRectangle($x1,$yb,$x2,$yc,$self->colour($glyph->{'truncate_colour'}, $glyph->{'alpha'}));
    }
    $x1 += $step;
    $x2 += $step;
  }
}

sub render_Barcode {
### Render a track as a series of equal-sized rectangles
### with value indicated by a colour gradient
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $colours        = $self->{'colours'};

  my $points = $glyph->{'pixelpoints'};
  return unless defined $points;

  my $x1 = $self->{'sf'} *   $glyph->{'pixelx'};
  my $x2 = $self->{'sf'} * ( $glyph->{'pixelx'} + $glyph->{'pixelunit'} );
  my $y1 = $self->{'sf'} *   $glyph->{'pixely'};
  my $y2 = $self->{'sf'} * ( $glyph->{'pixely'} + $glyph->{'pixelheight'} );
  my @colours = map { $self->colour($_) } @{$glyph->{'colours'}};

  my $max = $glyph->{'max'} || 1000;
  my $step = $glyph->{'pixelunit'} * $self->{'sf'};

  if($glyph->{'wiggle'} eq 'bar') {
    ## TODO Remove once no longer needed - has been superceded by render_Histogram
    my $mul = ($y2-$y1) / $max;
    foreach my $p (@$points) {
      my $yb = $y2 - max($p,0) * $mul;
      $canvas->filledRectangle($x1,$yb,$x2,$y2,$colours[0]);
      $x1 += $step;
      $x2 += $step;
    }
  } else {
    my $mul =  scalar(@colours) / $max;
    foreach my $p (@$points) {
      my $colour = $colours[int(max($p,0) * $mul)] || '000000';
      $canvas->filledRectangle($x1,$y1,$x2,$y2,$colour);
      $x1 += $step;
      $x2 += $step;
    }
  }
}

sub render_Poly {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $bordercolour   = $self->colour($glyph->{'bordercolour'});
  my $colour         = $self->colour($glyph->{'colour'}, $glyph->{'alpha'});
  my $poly           = GD::Polygon->new;

  return unless(defined $glyph->pixelpoints());

  my @points = @{$glyph->pixelpoints()};
  my $pairs_of_points = (scalar @points)/ 2;

  for(my $i=0;$i<$pairs_of_points;$i++) {
    my $x = shift @points;
    my $y = shift @points;
    $poly->addPt($self->{sf} * $x,$self->{sf} * $y);
  }

  if($glyph->{colour}) {
    $canvas->setAntiAliased($colour);
    $canvas->filledPolygon($poly, gdAntiAliased);
  }

  if($glyph->{'pattern'}) {
    $canvas->setTile($self->tile($glyph->{'patterncolour'}, $glyph->{'pattern'}));
    $canvas->filledPolygon($poly, gdTiled);
  }

  if($glyph->{bordercolour}) {
    $canvas->setAntiAliased($bordercolour);
    $canvas->polygon($poly, gdAntiAliased);
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
			     $self->{sf} * $glyph->{'pixelx'},
			     $self->{sf} * $glyph->{'pixely'},
			     0,
			     0,
			     $self->{sf} * $glyph->{'pixelwidth'}  || 1,
			     $self->{sf} * $glyph->{'pixelheight'} || 1,
			     $width,
			     $height);
}

1;
