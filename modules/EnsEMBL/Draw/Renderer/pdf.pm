=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Renderer::pdf;
use strict;


use PDF::API2;

use base qw(EnsEMBL::Draw::Renderer);

use List::Util qw(max);

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;

  $im_height = int($im_height* $self->{sf})+0;
  $im_width  = int($im_width* $self->{sf})+0;

  my $pdf = PDF::API2->new;
  my $page = $pdf->page();
     $page->mediabox( $im_width , $im_height );

  $self->canvas(
    { 'im_height' => $im_height, 'page' => $page, 'pdf' => $pdf, 'g' => $page->gfx, 't'=>$page->text, 'font' => $pdf->corefont('Helvetica-Bold',1) }
  );
  $self->{'canvas'}{'g'}->linewidth(0.5);
}

sub canvas {
  my ($self, $canvas) = @_;

  if(defined $canvas) {
  $self->{'canvas'} = $canvas;
  } else {
  my $result = $self->{'canvas'}{'pdf'}->stringify;
    $self->{'canvas'}{'pdf'}->end;
    return $result;
  }
}

sub Y { my( $self, $glyph ) = @_; return $self->{'canvas'}{'im_height'} - ($glyph->pixely() - $glyph->pixelheight())* $self->{sf}; }
sub X { my( $self, $glyph ) = @_; return $glyph->pixelx()* $self->{sf} ; }
sub XY { my( $self, $x, $y ) = @_; return ( $x* $self->{sf}, $self->{'canvas'}{'im_height'} - $y* $self->{sf} ); }
sub H { my( $self, $glyph ) = @_; return 1 + $glyph->pixelheight()* $self->{sf}; }
sub W { my( $self, $glyph ) = @_; return 1 + $glyph->pixelwidth()* $self->{sf}; }

sub strokecolor { 
  my $self = shift; 
  $self->{'canvas'}{'g'}->strokecolor($self->colour(shift)); 
}

sub fillcolor   { 
  my $self = shift; 
  $self->{'canvas'}{'g'}->fillcolor($self->colour(shift));
}

sub colour {
  my ($self, $colour) = @_;
  my @rgb = $self->{'colourmap'}->rgb_by_name($colour);
  if ($self->{'contrast'} && $self->{'contrast'} != 1) {
    @rgb = $self->{'colourmap'}->hivis($self->{'contrast'},@rgb);
  }
  ## hex_by_rgb doesn't include hash character. Because Reasons.
  return '#'.$self->{'colourmap'}->hex_by_rgb(\@rgb);
}

sub stroke      { my $self = shift; $self->_fillstroke_alpha('stroke', @_); }
sub fill        { my $self = shift; $self->_fillstroke_alpha('fill', @_); }
sub rect        { my $self = shift; $self->{'canvas'}{'g'}->rect(@_); }
sub move        { my $self = shift; $self->{'canvas'}{'g'}->move(@_); }
sub line        { my $self = shift; $self->{'canvas'}{'g'}->line(@_); }
sub poly        { my $self = shift; $self->{'canvas'}{'g'}->poly(@_); }
sub hybrid      { my $self = shift; $self->{'canvas'}{'page'}->hybrid; }

sub _fillstroke_alpha {
  my ($self, $action, $alpha) = @_;

  my $pdf = $self->{'canvas'}{'pdf'};
  my $gfx = $self->{'canvas'}{'g'};

  $gfx->egstate($self->{'_egstate'}{$alpha} ||= $pdf->egstate()->transparency($alpha)) if $alpha; # apply transparency
  $gfx->$action;
  $gfx->egstate($self->{'_egstate'}{0} ||= $pdf->egstate()->transparency(0)) if $alpha; # reset transparency
}

sub render_Rect {
  my ($self, $glyph) = @_;
  my $gcolour     = $glyph->colour();
  my $gbordercolour = $glyph->bordercolour();

	my($x,$y) = $self->XY($glyph->pixelx,$glyph->pixely);
	my($a,$b) = $self->XY($glyph->pixelx+$glyph->pixelwidth,$glyph->pixely+$glyph->pixelheight);

  ## Fix invisible glyphs!
  if ($a - $x < 1) { $a += 1; }
  if ($b - $y < 1) { $b += 1; }

  if (defined $gcolour && $gcolour ne 'transparent' ) {
    $self->fillcolor( $gcolour );
    $self->rect($x,$y,$a-$x,$b-$y);
    $self->fill($glyph->{'alpha'});
  } 
  if (defined $gbordercolour && $gbordercolour ne 'transparent' ) {
    $self->strokecolor( $gbordercolour );
    $self->rect($x,$y,$a-$x,$b-$y);
    $self->stroke($glyph->{'alpha'});
  }

  if($glyph->{'pattern'}) {
    my $pattern_def = $EnsEMBL::Draw::Renderer::patterns->{$glyph->{pattern}};

    if( $pattern_def ) {
      my $size = $pattern_def->{size};
      my $lines = $pattern_def->{lines} || [];
      my $polys = $pattern_def->{polys} || [];
      $self->strokecolor( $glyph->{patterncolour} );
      # $self->strokecolor(  );
      $self->fillcolor( $glyph->{patterncolour} );
      # $self->fillcolor( 'yellow' );
      my $x1 = $x;
      my $y1 = $y;
      my $total_size = 0;

      while ($x1 < $a) {
        #  For lines
        if ($#$lines >= 0) {
          foreach my $line (@$lines) {
            # Draw line on each tile using the pattern from Renderer.pm
            $self->move($x1+$line->[2]+3, $y1-$line->[3]);
            # e.g. [0,7,7,0]
            $self->line($x1+($line->[2]+3), $y1-$line->[3], $x1+$line->[0] ,$y1-($line->[1]+3));
          }
        }
        # For polys
        if($#$polys >=0) {
          foreach my $coords_arr (@$polys) {
            my $coords = [];
            foreach my $arr (@$coords_arr) {
              my ($x, $y);
              if ($a < $total_size) {
                $x = $a;
                $y = $b - ($y1 - $arr->[1]) / 2;
              }
              else {
                $x = $x1 + $arr->[0];
                $y = $y1 - $arr->[1] + 1;
              }

              push @$coords, $x, $y;
            }
            $self->poly(@$coords);
          }
        }
        $total_size += $size->[0];
        $x1 += $size->[0];
      }

      $self->fill($glyph->{'alpha'}) if ($#$polys >= 0);
      $self->stroke($glyph->{'alpha'}) if ($#$lines >= 0);
    }
  }
}

sub render_Histogram {
  my ($self, $glyph) = @_;

  my $points = $glyph->{'pixelpoints'};
  return unless defined $points;

  my $x1 = $self->{'sf'} *   $glyph->{'pixelx'};
  my $x2 = $self->{'sf'} * ( $glyph->{'pixelx'} + $glyph->{'pixelunit'} );
  my $y1 = $self->{'sf'} *   $glyph->{'pixely'};
  my $y2 = $self->{'sf'} * ( $glyph->{'pixely'} + $glyph->{'pixelheight'} );
  my $colour  = $self->colour($glyph->{'colour'});

  my $max = $glyph->{'max'} || 1000;
  my $top = $self->{'canvas'}{'im_height'};
  my $step = $glyph->{'pixelunit'} * $self->{'sf'};

  my $mul = ($y2-$y1) / $max;
  foreach my $p (@$points) {
    my $truncated = 0;
    if ($p > $max) {
      ## Truncate values that lie outside the range we want to draw
      $p = $max;
      $truncated = 1 if $glyph->{'truncate_colour'};
    }
    my $yb = $y1 + max($p,0) * $mul;
    $self->strokecolor($colour);
    $self->fillcolor($colour);
    $self->rect($x1,$top-$y2,$x2-$x1,$yb-$y1,$colour);
    $self->fill();
    ## Mark truncation with a contrasting line at the top of the bar
    if ($truncated) {
      $self->strokecolor($glyph->{'truncate_colour'});
      $self->fillcolor($glyph->{'truncate_colour'});
      $self->rect($x1,$top-$y1,$x2-$x1,1,$glyph->{'truncate_colour'});
      $self->fill();
    }
    $x1 += $step;
    $x2 += $step;
  }
}

sub render_Barcode {
  my ($self, $glyph) = @_;

  my $colours        = $self->{'colours'};

  my $points = $glyph->{'pixelpoints'};
  return unless defined $points;

  my $x1 = $self->{'sf'} *   $glyph->{'pixelx'};
  my $x2 = $self->{'sf'} * ( $glyph->{'pixelx'} + $glyph->{'pixelunit'} );
  my $y1 = $self->{'sf'} *   $glyph->{'pixely'};
  my $y2 = $self->{'sf'} * ( $glyph->{'pixely'} + $glyph->{'pixelheight'} );
  my @colours = @{$glyph->{'colours'}};

  my $max = $glyph->{'max'} || 1000;
  my $top = $self->{'canvas'}{'im_height'};
  my $step = $glyph->{'pixelunit'} * $self->{'sf'};

  if($glyph->{'wiggle'} eq 'bar') {
  ## TODO Remove once no longer needed - has been superceded by render_Histogram
    my $mul = ($y2-$y1) / $max;
    foreach my $p (@$points) {
      my $yb = $y1 + max($p,0) * $mul;
      $self->strokecolor($colours[0]);
      $self->fillcolor($colours[0]);
      $self->rect($x1,$top-$y2,$x2-$x1,$yb-$y1,$colours[0]);
      $self->fill();
      $x1 += $step;
      $x2 += $step;
    }
  } else {
    foreach my $p (@$points) {
      my $colour = $colours[int(max($p,0) * scalar @colours / $max)] || 'black';
      $self->fillcolor($colour);
      $self->strokecolor($colour);
      $self->rect($x1,$top-$y1,$x2-$x1,$y2-$y1);
      $self->fill();
      $x1 += $step;
      $x2 += $step;
    }
  }
}

sub render_Text {
  my ($self, $glyph) = @_;
  my $font = $glyph->font();
#  return;

  my $gcolour = $glyph->colour() || "black";
  $gcolour = $self->colour($gcolour); 
  my $text  = $glyph->text();

	my($x,$y) = $self->XY($glyph->pixelx,$glyph->pixely);
	my($a,$b) = $self->XY($glyph->pixelx+$glyph->pixelwidth,$glyph->pixely+$glyph->pixelheight);

	my $h = $y - $b;

  my $S = ($glyph->{'ptsize'}||8)* $self->{sf};
  my $T = $self->{'canvas'}{'t'};
     $T->font( $self->{'canvas'}{'font'}, $S );
     $T->fillcolor( $gcolour ); 
  if( $glyph->{'valign'} eq 'top' ) {
    $y -= $S;
  } elsif( $glyph->{'valign'} ne 'bottom' ) {
	  $y = ( $y + $b - $S ) /2;
  } else {
    $y = $b;
	}
  
  if( $glyph->{'halign'} eq 'right' ) {
    $T->translate( $a, $y );
    $T->text_right( $text );
  } elsif( $glyph->{'halign'} eq 'center' ) {
    $T->translate( ($x+$a)/2, $y );
    $T->text_center( $text );
  } else {
    $T->translate( $x, $y );
    $T->text( $text );
  }
}

sub render_Arc {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $colour         = $glyph->{'colour'};
  my ($cx, $cy)      = $glyph->pixelcentre();

	my($x,$y) = $self->XY($cx, $cy);

  $canvas->{'g'}->arc(
    $self->{sf} * ($x - $glyph->{'pixelwidth'}/2),
    $self->{sf} * ($y + $glyph->{'pixelheight'}/2),
    $self->{sf} * $glyph->{'pixelwidth'}/2,
    $self->{sf} * $glyph->{'pixelheight'}/2,
    $self->{sf} * ($glyph->{'start_point'} + 180),
    $self->{sf} * ($glyph->{'end_point'} + 180),
    1,
  );
  $self->{'canvas'}{'g'}->linewidth(1.0);
  $self->strokecolor($colour);
  $self->stroke;
  $self->{'canvas'}{'g'}->linewidth(0.5);
}

sub render_Circle {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $colour         = $glyph->{'colour'};
  my ($cx, $cy)      = $glyph->pixelcentre();

	my($x,$y) = $self->XY($cx, $cy);

  $canvas->{'g'}->ellipse(
    $self->{sf} * ($x - $glyph->{'pixelwidth'}/2),
    $self->{sf} * ($y + $glyph->{'pixelheight'}/2),
    $self->{sf} * $glyph->{'pixelwidth'}/2,
    $self->{sf} * $glyph->{'pixelheight'}/2,
  );

  if ($glyph->{'filled'}) {
    $self->fillcolor($colour);
    $self->fill;
  }
  else {
    $self->{'canvas'}{'g'}->linewidth(1.0);
    $self->strokecolor($colour);
    $self->stroke;
    $self->{'canvas'}{'g'}->linewidth(0.5);
  }
}

sub render_Ellipse {
#  die "Not implemented in pdf yet!";
}

sub render_Intron {
  my ($self, $glyph) = @_;
  my $gcolour = $glyph->colour();

	my($x,$y) = $self->XY($glyph->pixelx,$glyph->pixely);
	my($a,$b) = $self->XY($glyph->pixelx+$glyph->pixelwidth,$glyph->pixely+$glyph->pixelheight);

  my $mid = $glyph->strand() == -1 ? 7*$b+$y : 7*$y+$b;

  $self->strokecolor( $gcolour );
  $self->move( $x ,       ($y+$b)/2 );
  $self->line( ($x+$a)/2,  $mid/8 );
  $self->line( $a ,       ($y+$b)/2 );
  $self->stroke();
}

sub render_Line {
  my ($self, $glyph) = @_;

  my $gcolour = $glyph->colour();
  return if $gcolour eq 'transparent';

  $glyph->transform($self->{'transform'});

	my($x,$y) = $self->XY($glyph->pixelx,$glyph->pixely);
	my($a,$b) = $self->XY($glyph->pixelx+$glyph->pixelwidth,$glyph->pixely+$glyph->pixelheight);

  $self->strokecolor( $gcolour );
  $self->{'canvas'}{'g'}->linedash(5,5) if defined $glyph->dotted();
  $self->move( $x, $y );
  $self->line( $a, $b );
  $self->stroke();
  $self->{'canvas'}{'g'}->linedash() if defined $glyph->dotted();
}

sub render_Poly {
  my ($self, $glyph) = @_;
  my $gbordercolour = $glyph->bordercolour();
  my $gcolour     = $glyph->colour();

  my @points = @{$glyph->pixelpoints()};
  my $pairs_of_points = (scalar @points)/ 2;
  my ($lastx,$lasty) = $self->XY($points[-2],$points[-1]);

  if(defined $gcolour) {
    return if $gcolour eq 'transparent';
    $self->strokecolor( $gcolour );
    $self->fillcolor( $gcolour );
  } elsif(defined $gbordercolour) {
    return if $gbordercolour eq 'transparent';
    $self->strokecolor( $gbordercolour );
  }

  $self->move( $lastx , $lasty );
  while( my ($x,$y) = splice(@points,0,2) ) {
     ($x,$y) = $self->XY($x,$y);
     $self->line( $x , $y );
  }
  if(defined $gcolour) {
     # $self->stroke();
     $self->fill();
  } elsif(defined $gbordercolour) {
     $self->stroke();
  }
}

sub render_Composite {
  my ($self, $glyph,$Ta) = @_;

  #########
  # draw & colour the bounding area if specified
  # 
  $self->render_Rect($glyph) if(defined $glyph->colour() || defined $glyph->bordercolour());

  #########
  # now loop through $glyph's children
  #
  $self->SUPER::render_Composite($glyph,$Ta);
}

sub render_Sprite {
  my ($self, $glyph) = @_;
  my $spritename   = $glyph->{'sprite'} || "unknown";
  my $config     = $self->config();

  unless(exists $config->{'_spritecache'}->{$spritename}) {
  my $libref = $config->get_parameter(  "spritelib");
  my $lib  = $libref->{$glyph->{'spritelib'} || "default"};
  my $fn   = "$lib/$spritename.png";
  unless( -r $fn ){
    warn( "$fn is unreadable by uid/gid" );
    return;
  }
  eval {
    $config->{'_spritecache'}->{$spritename} = $self->{'canvas'}{'page'}->image_png($fn);
  };
  if( $@ || !$config->{'_spritecache'}->{$spritename} ) {
    eval {
    $config->{'_spritecache'}->{$spritename} = $self->{'canvas'}{'page'}->image_png("$lib/missing.png");
    };
  }
  }

  return $self->SUPER::render_Sprite($glyph);
}

1;
