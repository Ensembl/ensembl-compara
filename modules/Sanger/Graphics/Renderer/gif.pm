#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
# Last Modified: rmp 2004-12-14 initial stringFT support
#
package Sanger::Graphics::Renderer::gif;
use strict;
use Sanger::Graphics::Renderer;
use GD;
# use Math::Bezier;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::Renderer);

sub init_canvas {
    my ($self, $config, $im_width, $im_height) = @_;
    $self->{'im_width'} = $im_width;
    $self->{'im_height'} = $im_height;
    my $canvas = GD::Image->new($im_width, $im_height);
    $canvas->colorAllocate($config->colourmap->rgb_by_name($config->bgcolor()));
    $self->canvas($canvas);
}

sub add_canvas_frame {
    my ($self, $config, $im_width, $im_height) = @_;
	
    return if (defined $config->{'no_image_frame'});
	
    # custom || default image frame colour
    my $imageframecol = $config->{'image_frame_colour'} || 'black';
	
    my $framecolour = $self->colour($imageframecol);

    # for contigview bottom box we need an extra thick border...
    if ($config->script() eq "contigviewbottom"){		
    	$self->{'canvas'}->rectangle(1, 1, $im_width-2, $im_height-2, $framecolour);		
    }
	
    $self->{'canvas'}->rectangle(0, 0, $im_width-1, $im_height-1, $framecolour);
}

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
        $self->{'canvas'} = $canvas ;
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
  $id ||= "black";
  $self->{'_GDColourCache'}->{$id} ||= $self->{'canvas'}->colorAllocate($self->{'colourmap'}->rgb_by_name($id));
  return $self->{'_GDColourCache'}->{$id};
}

sub render_Rect {
    my ($self, $glyph) = @_;

    my $canvas = $self->{'canvas'};

    my $gcolour       = $glyph->{'colour'};
    my $gbordercolour = $glyph->{'bordercolour'};

    # (avc)
    # this is a no-op to let us define transparent glyphs
    # and which can still have an imagemap area BUT make
    # sure it is smaller than the carrent largest glyph in
    # this glyphset because its height is not recorded!
    if (defined $gcolour && $gcolour eq 'transparent'){
      return;
    }
    
    my $bordercolour  = $self->colour($gbordercolour);
    my $colour        = $self->colour($gcolour);

    my $x1 = $glyph->{'pixelx'};
    my $x2 = $glyph->{'pixelx'} + $glyph->{'pixelwidth'};
    my $y1 = $glyph->{'pixely'};
    my $y2 = $glyph->{'pixely'} + $glyph->{'pixelheight'};

    $canvas->filledRectangle($x1, $y1, $x2, $y2, $colour) if(defined $gcolour);
    $canvas->rectangle($x1, $y1, $x2, $y2, $bordercolour) if(defined $gbordercolour);
	
}

sub render_Text {
    my ($self, $glyph) = @_;

    my $colour = $self->colour($glyph->{'colour'});
    
    #########
    # Stock GD fonts
    #
    my $font = $glyph->font();
    if($font eq "Tiny") {
        $self->{'canvas'}->string(gdTinyFont, $glyph->{'pixelx'}, $glyph->{'pixely'}, $glyph->text(), $colour);

    } elsif($font eq "Small") {
        $self->{'canvas'}->string(gdSmallFont, $glyph->{'pixelx'}, $glyph->{'pixely'}, $glyph->text(), $colour);

    } elsif($font eq "MediumBold") {
        $self->{'canvas'}->string(gdMediumBoldFont, $glyph->{'pixelx'}, $glyph->{'pixely'}, $glyph->text(), $colour);

    } elsif($font eq "Large") {
        $self->{'canvas'}->string(gdLargeFont, $glyph->{'pixelx'}, $glyph->{'pixely'}, $glyph->text(), $colour);

    } elsif($font eq "Giant") {
        $self->{'canvas'}->string(gdGiantFont, $glyph->{'pixelx'}, $glyph->{'pixely'}, $glyph->text(), $colour);

    } elsif($font) {
	#########
	# If we didn't recognise it already, assume it's a TrueType font
	#
	$self->{'canvas'}->stringFT($colour,
				    $font,
				    $glyph->ptsize(),
				    $glyph->angle()||0,
				    $glyph->{'pixelx'},
				    $glyph->{'pixely'},
				    $glyph->text());
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
    $ystart  = $gy + $glyph->{'pixelheight'} / 2;
    $yend    = $ystart;
    $ymiddle = ($strand == 1)?$gy:($gy+$glyph->{'pixelheight'});

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
        $self->{'canvas'}->setStyle($colour,$colour,$colour,gdTransparent,gdTransparent,gdTransparent);
        $self->{'canvas'}->line($x1, $y1, $x2, $y2, gdStyled);
    } else {
        $self->{'canvas'}->line($x1, $y1, $x2, $y2, $colour);
    }
}

sub render_Poly {
    my ($self, $glyph) = @_;

    my $bordercolour = $self->colour($glyph->{'bordercolour'});
    my $colour       = $self->colour($glyph->{'colour'});
    my $poly         = new GD::Polygon;

    return unless(defined $glyph->pixelpoints());

    my @points = @{$glyph->pixelpoints()};
    my $pairs_of_points = (scalar @points)/ 2;

    for(my $i=0;$i<$pairs_of_points;$i++) {
    	my $x = shift @points;
    	my $y = shift @points;
        $poly->addPt($x,$y);
    }

    if($glyph->{colour})        { $self->{'canvas'}->filledPolygon($poly, $colour); }
    if($glyph->{bordercolour})  { $self->{'canvas'}->polygon($poly, $bordercolour); }
}

sub render_Composite {
    my ($self, $glyph) = @_;

    #########
    # draw & colour the fill area if specified
    #
    $self->render_Rect($glyph) if(defined $glyph->{'colour'});

    #########
    # now loop through $glyph's children
    #
    $self->SUPER::render_Composite($glyph);

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
  my $spritename     = $glyph->{'sprite'} || "unknown";
  my $config         = $self->config();

  unless(exists $config->{'_spritecache'}->{$spritename}) {
    my $libref = $config->get("_settings", "spritelib");
    my $lib    = $libref->{$glyph->{'spritelib'} || "default"};
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
