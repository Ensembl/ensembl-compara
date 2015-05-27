=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

1;

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
  $self->{'canvas'}{'g'}->linewidth(0.25);
}

sub add_canvas_frame {
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

sub strokecolor { my $self = shift; $self->{'canvas'}{'g'}->strokecolor( $self->{'colourmap'}->hex_by_name( shift ) ); }
sub fillcolor   { my $self = shift; $self->{'canvas'}{'g'}->fillcolor(   $self->{'colourmap'}->hex_by_name( shift ) ); }
sub stroke    { my $self = shift; $self->{'canvas'}{'g'}->stroke; }
sub fill    { my $self = shift; $self->{'canvas'}{'g'}->fill; }
sub rect    { my $self = shift; $self->{'canvas'}{'g'}->rect(@_); }
sub move    { my $self = shift; $self->{'canvas'}{'g'}->move(@_); }
sub line    { my $self = shift; $self->{'canvas'}{'g'}->line(@_); }
sub hybrid    { my $self = shift; $self->{'canvas'}{'page'}->hybrid; }

sub render_Rect {
  my ($self, $glyph) = @_;
  my $gcolour     = $glyph->colour();
  my $gbordercolour = $glyph->bordercolour();

	my($x,$y) = $self->XY($glyph->pixelx,$glyph->pixely);
	my($a,$b) = $self->XY($glyph->pixelx+$glyph->pixelwidth,$glyph->pixely+$glyph->pixelheight);

  if(defined $gcolour) {
    unless( $gcolour eq 'transparent' ) {
    $self->fillcolor( $gcolour );
    $self->strokecolor( $gcolour );
    $self->rect($x,$y,$a-$x,$b-$y);
    # $self->stroke();
    $self->fill();
    }
  } elsif(defined $gbordercolour) {
    unless( $gbordercolour eq 'transparent' ) {
    $self->strokecolor( $gbordercolour );
    $self->rect($x,$y,$a-$x,$b-$y);
    $self->stroke();
    }
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
    my $mul = ($y2-$y1) / $max;
    foreach my $p (@$points) {
      my $yb = $y1 + $p * $mul;
      $self->strokecolor($colours[0]);
      $self->fillcolor($colours[0]);
      $self->rect($x1,$top-$y2,$x2-$x1,$yb-$y1,$colours[0]);
      $self->fill();
      $x1 += $step;
      $x2 += $step;
    }
  } else {
    foreach my $p (@$points) {
      my $colour = $colours[int($p * scalar @colours / $max)] || 'black';
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
  $gcolour = $self->{'colourmap'}->hex_by_name( $gcolour ); 
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

sub render_Circle {
#  die "Not implemented in pdf yet!";
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
