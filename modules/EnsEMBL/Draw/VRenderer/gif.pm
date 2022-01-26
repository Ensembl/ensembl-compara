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

package EnsEMBL::Draw::VRenderer::gif;

### Renders vertical ideograms in GIF format using GD::Image
### Modeled on EnsEMBL::Draw::Renderer::gif

use strict;
use GD;
use base qw(EnsEMBL::Draw::VRenderer);

sub init_canvas {
  my ($self, $config, $im_height, $im_width) = @_;
  my $canvas = GD::Image->new($im_width, $im_height);
  $canvas->colorAllocate($config->colourmap()->rgb_by_name( $config->get_parameter('bgcolor') ));
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

sub colour {
## colour caching routine.
## GD can only store 256 colours, so need to cache the ones we colorAllocate. (Doh!)
  my ($self, $id) = @_;
  $id           ||= "black";
  my $colour      = $self->{'_GDColourCache'}->{$id} || $self->{'canvas'}->colorAllocate($self->{'colourmap'}->rgb_by_name($id));

  $self->{'_GDColourCache'}->{$id} = $colour;
  return $colour;
}


sub render_Rect {
  my ($self, $glyph) = @_;
  
  my $canvas = $self->{'canvas'};
  
  my $gcolour       = $glyph->colour();
  my $gbordercolour = $glyph->bordercolour();
  # (avc)
  # this is a no-op to let us define transparent glyphs
  # and which can still have an imagemap area BUT make
  # sure it is smaller than the carrent largest glyph in
  # this glyphset because its height is not recorded!
  if ($gcolour eq 'transparent') {
    return;
  }
  
  my $bordercolour  = $self->colour($gbordercolour);
  my $colour        = $self->colour($gcolour);
  
  my $x1 = $self->{sf} * $glyph->pixelx();
  my $x2 = $self->{sf} * ($glyph->pixelx() + $glyph->pixelwidth());
  my $y1 = $self->{sf} * $glyph->pixely();
  my $y2 = $self->{sf} * ($glyph->pixely() + $glyph->pixelheight());
  
  $canvas->filledRectangle($y1, $x1, $y2, $x2, $colour) if(defined $gcolour);
  $canvas->rectangle($y1, $x1, $y2, $x2, $bordercolour) if(defined $gbordercolour);
}

sub render_Text {
  my ($self, $glyph) = @_;
  my $colour         = $self->colour($glyph->colour());

  my $top        = $self->{sf} * $glyph->{'pixely'} || 0;
  my $left       = $self->{sf} * $glyph->{'pixelx'} || 0;

  #########
  # BAH! HORRIBLE STINKY STUFF!
  # I'd take GD voodoo calls any day
  #
  if(int($self->{sf}) != 1) {
    my $font = int($self->{sf}) > 2 ? gdGiantFont :  int($self->{sf}) ==  2 ? gdMediumBoldFont : gdSmallFont;
    $left += int($left/100) if int($self->{sf}) > 1; #adjustment of the text
    $self->{'canvas'}->string($font, $top, $left, $glyph->text(), $colour);
  } elsif($glyph->font() eq "Tiny") {
    $self->{'canvas'}->string(gdTinyFont, $top, $left, $glyph->text(), $colour);
    
  } elsif($glyph->font() eq "Small") {
    $self->{'canvas'}->string(gdSmallFont, $top, $left, $glyph->text(), $colour);
    
  } elsif($glyph->font() eq "MediumBold") {
    $self->{'canvas'}->string(gdMediumBoldFont, $top, $left, $glyph->text(), $colour);
    
  } elsif($glyph->font() eq "Large") {
    $self->{'canvas'}->string(gdLargeFont, $top, $left, $glyph->text(), $colour);
    
  } elsif($glyph->font() eq "Giant") {
    $self->{'canvas'}->string(gdGiantFont, $top, $left, $glyph->text(), $colour);
  }
}

sub render_Circle {
}

sub render_Ellipse {
}

sub render_Space {
}

sub render_Intron {
  my ($self, $glyph) = @_;
  
  my $colour = $self->colour($glyph->colour());
  
  my ($xstart, $xmiddle, $xend, $ystart, $ymiddle, $yend, $strand);
  
  #########
  # todo: check rotation conditions
  #
  $strand  = $glyph->strand();
  $xstart  = $self->{sf} * $glyph->pixelx();
  $xend    = $self->{sf} * ($glyph->pixelx() + $glyph->pixelwidth());
  $xmiddle = $self->{sf} * ($glyph->pixelx() + int($glyph->pixelwidth() / 2));
  $ystart  = $self->{sf} * ($glyph->pixely() + int($glyph->pixelheight() / 2));
  $yend    = $ystart;
  $ymiddle = ($strand == 1)? $self->{sf} * $glyph->pixely() : $self->{sf} * ($glyph->pixely()+$glyph->pixelheight());
  
  $self->{'canvas'}->line($xstart, $ystart, $xmiddle, $ymiddle, $colour);
  $self->{'canvas'}->line($xmiddle, $ymiddle, $xend, $yend, $colour);
}

sub render_Line {
  my ($self, $glyph) = @_;
  
  my $colour = $self->colour($glyph->colour());
  my $x1     = $self->{sf} * $glyph->pixelx() + 0;
  my $y1     = $self->{sf} * $glyph->pixely() + 0;
  my $x2     = $x1 + $self->{sf} * $glyph->pixelwidth();
  my $y2     = $y1 + $self->{sf} * $glyph->pixelheight();
  
  if(defined $glyph->dotted()) {
    $self->{'canvas'}->dashedLine($y1, $x1, $y2, $x2, $colour);
  } else {  
    $self->{'canvas'}->line($y1, $x1, $y2, $x2, $colour);
  }
}

sub render_Poly {
  my ($self, $glyph) = @_;
  
  my $bordercolour = $self->colour($glyph->bordercolour());
  my $colour       = $self->colour($glyph->colour());
  
  my $poly = GD::Polygon->new;
  
  return unless(defined $glyph->pixelpoints());
  
  my @points = @{$glyph->pixelpoints()};
  my $pairs_of_points = (scalar @points)/ 2;
  
  for(my $i=0;$i<$pairs_of_points;$i++) {
    my $x = shift @points;
    my $y = shift @points;
    
    $poly->addPt($self->{sf} * $y, $self->{sf} * $x);
  }
  
  if(defined $colour) {
    $self->{'canvas'}->filledPolygon($poly, $colour);
  } else {
    $self->{'canvas'}->polygon($poly, $bordercolour);
  }
}

sub render_Composite {
  my ($self, $glyph) = @_;
  
  #########
  # draw & colour the fill area if specified
  #
  $self->render_Rect($glyph) if(defined $glyph->colour());
  
  #########
  # now loop through $glyph's children
  #
  $self->SUPER::render_Composite($glyph);
  
  #########
  # draw & colour the bounding area if specified
  #
  $glyph->{'colour'} = undef;
  $self->render_Rect($glyph) if(defined $glyph->bordercolour());
}

1;
