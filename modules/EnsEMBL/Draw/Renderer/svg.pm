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

package EnsEMBL::Draw::Renderer::svg;
use strict;

use vars qw(%classes);

use base qw(EnsEMBL::Draw::Renderer);

use List::Util qw(max);

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $im_height = int($im_height * $self->{sf});
  $im_width  = int($im_width  * $self->{sf});

  my @colours = keys %{$self->{'colourmap'}};
  $self->{'image_width'}  = $im_width;
  $self->{'image_height'} = $im_height;
  $self->{'style_cache'}  = {};
  $self->{'next_style'}   = 'aa';
  $self->canvas('');
}

sub svg_rgb_by_name {
    my ($self, $name) = @_;
    return 'none' if($name eq 'transparent');
    my @rgb = $self->{'colourmap'}->rgb_by_name($name);
    if ($self->{'contrast'} && $self->{'contrast'} != 1) {
      @rgb = $self->{'colourmap'}->hivis($self->{'contrast'},@rgb);
    }
    return 'rgb('. (join ',',@rgb).')';
}
sub svg_rgb_by_id {
    my ($self, $id) = @_;
    return 'none' if($id eq 'transparent');
    my @rgb = $self->{'colourmap'}->rgb_by_name($id);
    if ($self->{'contrast'} && $self->{'contrast'} != 1) {
      @rgb = $self->{'colourmap'}->hivis($self->{'contrast'},@rgb);
    }
    return 'rgb('. (join ',',@rgb).')';
}

sub canvas {
    my ($self, $canvas) = @_;

    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
        my $styleHTML = join "\n", map { '.'.($self->{'style_cache'}->{$_})." { $_ }" } keys %{$self->{'style_cache'}};
	return qq(<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20001102//EN" "http://www.w3.org/TR/2000/CR-SVG-20001102/DTD/svg-20001102.dtd">
<svg width="$self->{'image_width'}" height="$self->{'image_height'}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<defs><style type="text/css">
poly { stroke-linecap: round }
line, rect, poly { stroke-width: 0.5; }
text { font-family:Helvetica, Arial, sans-serif;font-size:6pt;font-weight:normal;text-align:left;fill:black; }
${styleHTML}
</style></defs>
$self->{'canvas'}
</svg>
    	);
    }
}

sub add_string {
    my ($self,$string) = @_;

    $self->{'canvas'} .= $string;
}

sub class {
    my ($self, $style) = @_;
    my $class = $self->{'style_cache'}->{$style};
    unless($class) {
      $class = $self->{'style_cache'}->{$style} = $self->{'next_style'}++;
    }
    return qq(class="$class");
}

sub style {
    my ($self, $glyph,$colour) = @_;
    my $gcolour       = $colour || $glyph->colour();
    my $gbordercolour = $glyph->bordercolour();
    my $opacity       = sprintf '%.1f', 1 - ($glyph->{'alpha'} || 0);
       $opacity       = int $opacity if int $opacity == $opacity;

    my $style = defined $gcolour ? 'fill:'.$self->svg_rgb_by_id($gcolour).qq(;opacity:$opacity;)
                                 : 'fill:none;';
    
    if (defined $gbordercolour) {
      $style .= 'stroke:'.$self->svg_rgb_by_id($gbordercolour).';'; 
    }
    else {
      $style .= 'stroke:none;';
    }
    
    return $self->class($style);
}

sub textstyle {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour() ? $self->svg_rgb_by_id($glyph->colour()) : $self->svg_rgb_by_name('black');

    my $style = "stroke:none;opacity:1;fill:$gcolour;";
    return $self->class($style);
}

sub linestyle {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour();
    my $dotted        = $glyph->dotted();

    my $style =
        defined $gcolour ? 	qq(fill:none;stroke:).$self->svg_rgb_by_id($gcolour).qq(;opacity:1;) :
				qq(fill:none;stroke:none;);
    $style .= qq(stroke-dasharray:1,2,1;) if defined $dotted; 

    return $self->class($style);
}

sub render_Rect {
    my ($self, $glyph) = @_;

    my $style = $self->style( $glyph );
    my $x = $glyph->pixelx();
    my $w = $glyph->pixelwidth();
    my $y = $glyph->pixely();
    my $h = $glyph->pixelheight();

    $x = sprintf("%0.3f",$x*$self->{sf});
    $w = sprintf("%0.3f",($w+1)*$self->{sf});
    $y = sprintf("%0.3f",$y*$self->{sf});
    $h = sprintf("%0.3f",($h+1)*$self->{sf});
    $self->add_string(qq(<rect x="$x" y="$y" width="$w" height="$h" $style />\n)); 
}

sub render_Histogram {
  my ($self, $glyph) = @_;

  my $points = $glyph->{'pixelpoints'};
  return unless defined $points;

  my $x1 = $self->{'sf'} *   $glyph->{'pixelx'};
  my $x2 = $self->{'sf'} * ( $glyph->{'pixelx'} + $glyph->{'pixelunit'} );
  my $y1 = $self->{'sf'} *   $glyph->{'pixely'};
  my $y2 = $self->{'sf'} * ( $glyph->{'pixely'} + $glyph->{'pixelheight'} );
  my $fmt     = '<rect x="%0.3f" y="%0.3f" width="%0.3f" height="%0.3f" %s />';
  my $max     = $glyph->{'max'} || 1000;
  my $step    = $glyph->{'pixelunit'} * $self->{'sf'};

  my $mul     = ($y2-$y1) / $max;
  my $style   = $self->style($glyph);
  my $t_style = $self->style($glyph,$glyph->{'truncate_colour'});
  foreach my $p (@$points) {
    my $truncated = 0;
    if ($p > $max) {
      ## Truncate values that lie outside the range we want to draw
      $p = $max;
      $truncated = 1 if $glyph->{'truncate_colour'};
    }
    my $yb = $y2 - max($p,0) * $mul;
    $self->add_string(sprintf($fmt,$x1,$y2,$x2-$x1+1,$yb-$y2+1,$style));
    ## Mark truncation with a contrasting line at the top of the bar
    if ($truncated) {
    #  $self->add_string(sprintf($fmt,$x1,$y1,$x2-$x1+1,$yb-$y2+1,$t_style));
    }
    $x1 += $step;
    $x2 += $step;
  }
}

sub render_Barcode {
  my ($self, $glyph) = @_;

  my $points = $glyph->{'pixelpoints'};
  return unless defined $points;

  my $x1 = $self->{'sf'} *   $glyph->{'pixelx'};
  my $x2 = $self->{'sf'} * ( $glyph->{'pixelx'} + $glyph->{'pixelunit'} );
  my $y1 = $self->{'sf'} *   $glyph->{'pixely'};
  my $y2 = $self->{'sf'} * ( $glyph->{'pixely'} + $glyph->{'pixelheight'} );
  my @colours = @{$glyph->{'colours'}};
  my $max = $glyph->{'max'} || 1000;
  my $fmt = '<rect x="%0.3f" y="%0.3f" width="%0.3f" height="%0.3f" %s />';
  my $step = $glyph->{'pixelunit'} * $self->{'sf'};
  if($glyph->{'wiggle'} eq 'bar') {
    my $mul = ($y2-$y1) / $max;
    my $style = $self->style($glyph);
    foreach my $p (@$points) {
      my $yb = $y2 - max($p,0) * $mul;
      $self->add_string(sprintf($fmt,$x1,$y2,$x2-$x1+1,$yb-$y2+1,$style));
      $x1 += $step;
      $x2 += $step;
    }
  } else {
    foreach my $p (@$points) {
      my $colour = $colours[int(max($p,0) * scalar @colours / $max)] || 'black';
      my $style = $self->style($glyph,$colour);
      $self->add_string(sprintf($fmt,$x1,$y1,$x2-$x1+1,$y2-$y1+1,$style));
      $x1 += $step;
      $x2 += $step;
    }
  }
}

sub render_Text {
    my ($self, $glyph) = @_;
    my $font = $glyph->font();

    my $style   = $self->textstyle( $glyph );
    my $x       = $glyph->pixelx()*$self->{sf};
    my $y       = $glyph->pixely()*$self->{sf}+6*$self->{sf};
    my $text    = $glyph->text();

    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&amp;/g;
    my $sz = ($self->{sf}*100).'%';
    $self->add_string( qq(<text x="$x" y="$y" text-size="$sz" $style>$text</text>\n) );
}

sub render_Arc {
  my ($self, $glyph) = @_;

  my $style = $self->linestyle( $glyph );

  my $x = $glyph->pixelx() * $self->{sf};
  my $y = $glyph->pixely() * $self->{sf};
  my $a = $glyph->pixelwidth * $self->{sf};
  my $b = $glyph->pixelheight * 2 * $self->{sf};
  my $x1 = $x - $a;
  $y    -= $b / 4;

  my $arc = "M $x1 $y A $a $b 0 0 0 $x $y";

  $self->add_string(qq(<path d="$arc" $style />\n));
}

sub render_Circle {
#    die "Not implemented in svg yet!";
}

sub render_Ellipse {
#    die "Not implemented in svg yet!";
}

sub render_Intron {
    my ($self, $glyph) = @_;
    my $style   = $self->linestyle( $glyph );

    my $x1 = $glyph->pixelx() *$self->{sf};
    my $w1 = $glyph->pixelwidth() / 2 * $self->{sf};
    my $h1 = $glyph->pixelheight() / 2 * $self->{sf};
    my $y1 = $glyph->pixely() * $self->{sf} + $h1;

    $h1 = -$h1 if($glyph->strand() == -1);

    my $h2 = -$h1;

    $self->add_string(qq(<path d="M$x1,$y1 l$w1,$h2 l$w1,$h1" $style />\n));
}

sub render_Line {
    my ($self, $glyph) = @_;

    my $style = $self->linestyle( $glyph );

    $glyph->transform($self->{'transform'});

    my $x = $glyph->pixelx() * $self->{sf};
    my $w = $glyph->pixelwidth() * $self->{sf};
    my $y = $glyph->pixely() * $self->{sf};
    my $h = $glyph->pixelheight() * $self->{sf};

    $self->add_string(qq(<path d="M$x,$y l$w,$h" $style />\n));
}

sub render_Poly {
    my ($self, $glyph) = @_;

    my $style = $self->style( $glyph );
    my @points = @{$glyph->pixelpoints()};
    my $x = shift @points;
    my $y = shift @points;
		$x*=$self->{sf};$y*=$self->{sf};
    my $poly = qq(<path d="M$x,$y);
    while(@points) {
	$x = shift @points;
	$y = shift @points;
		$x*=$self->{sf};$y*=$self->{sf};
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
