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

package EnsEMBL::Draw::Renderer::imagemap;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Draw::Renderer);

#########
sub init_canvas {
  my $self = shift;
  $self->canvas([]);
}

sub render_Ellipse {}
sub render_Intron  {}
sub render_Arc  {}

sub render_Composite { shift->render_Rect(@_); }
sub render_Space     { shift->render_Rect(@_); }
sub render_Text      { shift->render_Rect(@_); }

sub render_Rect {
  my ($self, $glyph) = @_;
  
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;  
  
  my $x1 = $glyph->{'pixelx'};
  my $x2 = $glyph->{'pixelx'} + $glyph->{'pixelwidth'};
  my $y1 = $glyph->{'pixely'};
  my $y2 = $glyph->{'pixely'} + $glyph->{'pixelheight'};

  $attrs->{'overlap'} = 1 if $glyph->{'alpha'};

  $x1 = 0 if $x1 < 0;
  $x2 = 0 if $x2 < 0;
  $y1 = 0 if $y1 < 0;
  $y2 = 0 if $y2 < 0;

  $y2++;
  $x2++;

  $self->render_area('rect', [ $x1, $y1, $x2, $y2 ], $attrs);
}

sub render_Circle {
  my ($self, $glyph) = @_;
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;

  my ($x, $y) = $glyph->pixelcentre;
  my $r = $glyph->{'pixelwidth'}/2;
  
  $self->render_area('circle', [ $x, $y, $r ], $attrs);
}

sub render_Barcode {
  my ($self, $glyph) = @_;
  $self->render_Histogram($glyph);
}

sub render_Histogram {
  my ($self, $glyph) = @_;

  my $attrs = $self->get_attributes($glyph);
  return unless $attrs;

  my $x1 = $glyph->{'pixelx'};
  my $x2 = $glyph->{'pixelx'} + $glyph->{'pixelwidth'};
  my $y1 = $glyph->{'pixely'};
  my $y2 = $glyph->{'pixely'} + $glyph->{'pixelheight'};

  $x1 = 0 if $x1 < 0;
  $x2 = 0 if $x2 < 0;
  $y1 = 0 if $y1 < 0;
  $y2 = 0 if $y2 < 0;

  $y2++;
  $x2++;

  $self->render_area('rect', [ $x1, $y1, $x2, $y2 ], $attrs);
}

sub render_Poly {
  my ($self, $glyph) = @_;
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;
  
  $self->render_area('poly', $glyph->pixelpoints, $attrs);
}

sub render_Line {
  my ($self, $glyph) = @_;
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;

  my $x1 = $glyph->{'pixelx'} + 0;
  my $y1 = $glyph->{'pixely'} + 0;
  my $x2 = $x1 + $glyph->{'pixelwidth'};
  my $y2 = $y1 + $glyph->{'pixelheight'};
  my $click_width = exists $glyph->{'clickwidth'} ? $glyph->{'clickwidth'} : 1;
  my $len = sqrt(($y2-$y1)*($y2-$y1) + ($x2-$x1)*($x2-$x1));
  my ($u_x, $u_y) = $len > 0 ? (($x2-$x1) * $click_width / $len, ($y2-$y1) * $click_width /$len) : ($click_width, 0);
  
  my $pointslist = [
    $x2+$u_x, $y2+$u_y,
    $x2+$u_y, $y2-$u_x,
    $x1+$u_y, $y1-$u_x,
    $x1-$u_x, $y1-$u_y,
    $x1-$u_y, $y1+$u_x,
    $x2-$u_y, $y2+$u_x,
    $x2+$u_x, $y2+$u_y
  ];

  $self->render_area('poly', $pointslist, $attrs);
}

sub render_area {
  my ($self, $shape, $points, $attrs) = @_;
  
  my $coords = join ',', map int, @$points;

  push @{$self->canvas},[$shape,[map int, @$points],$attrs];
}

sub get_attributes {
  my ($self, $glyph) = @_;

  my %actions = ();
  
  foreach (qw(title alt href target class)) {
    my $attr = $glyph->$_;
    
    if ($attr) {
      if ($_ eq 'class') {
        $actions{'klass'} = [ split(/ /,$attr) ];
      } else {
        $actions{$_} = $attr;
      }
    }
  }
  
  return unless $actions{'title'} || $actions{'href'} || grep { $_ eq 'label'  } @{$actions{'klass'}||[]};
  
  return \%actions;
}

sub add_location_marking_layer {}

1;
