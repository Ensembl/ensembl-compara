package Sanger::Graphics::Renderer::test;
use strict;


use vars qw(%classes);

use base qw(Sanger::Graphics::Renderer);

sub init_canvas {
    my ($self, $config, $im_width, $im_height) = @_;
    # we separate out postscript commands from header so that we can
    # do EPS at some future time.

    $im_height = int($im_height);
    $im_width  = int($im_width);

    $self->{'image_width'}  = $im_width;
    $self->{'image_height'} = $im_height;
    $self->{'glyphs'}       = {};
    $self->{'tracks'}       = {};
    $self->canvas('');
}

sub add_canvas_frame {
}

sub canvas {
  my ($self, $canvas) = @_;

  if(defined $canvas) {
    $self->{'canvas'} = $canvas;
  } else {
    my $output = qq(
Summary of Drawing code:
);
    foreach my $T ( sort keys %{$self->{'tracks'}} ) {
      $output.=qq(\n[$T]\n);
      foreach ( sort keys %{$self->{'tracks'}{$T}} ) {
        $output.= sprintf(qq(%-20.20s %7d glyphs rendered caption: %s\n), $_, @{$self->{'tracks'}{$T}{$_}} );
      }
    }
    $output.=qq(
The following glyphs were rendered:
);
    foreach my $T ( sort keys %{$self->{'glyphs'}} ) {
      $output.= qq(\n[$T]\n);
      foreach my $C ( sort keys %{$self->{'glyphs'}{$T}} ) {
        $output.=sprintf("%-20.20s = %s\n", $C, $self->{'glyphs'}{$T}{$C});
      }
    }
    return $output;
  }
}

sub render_Rect {
    my ($self, $glyph) = @_;
    $self->{'glyphs'}{'Rect'}{"$glyph->{'colour'}:$glyph->{'bordercolour'}"} ++;
}
sub render_Text {
    my ($self, $glyph) = @_;
    $self->{'glyphs'}{'Text'}{"$glyph->{'colour'}:$glyph->{'bordercolour'}"} ++;
}
sub render_Circle {
    my ($self, $glyph) = @_;
    $self->{'glyphs'}{'Circle'}{"$glyph->{'colour'}:$glyph->{'bordercolour'}"} ++;
}
sub render_Ellipse {
    my ($self, $glyph) = @_;
    $self->{'glyphs'}{'Ellipse'}{"$glyph->{'colour'}:$glyph->{'bordercolour'}"} ++;
}
sub render_Intron {
    my ($self, $glyph) = @_;
    $self->{'glyphs'}{'Intron'}{"$glyph->{'colour'}:$glyph->{'bordercolour'}"} ++;
}
sub render_Line {
    my ($self, $glyph) = @_;
    $self->{'glyphs'}{'Line'}{"$glyph->{'colour'}:$glyph->{'bordercolour'}"} ++;
}
sub render_Composite {
    my ($self, $glyph) = @_;
    $self->{'glyphs'}{'Composite'}{"$glyph->{'colour'}:$glyph->{'bordercolour'}"} ++;
    $self->SUPER::render_Composite($glyph);
}
sub render_Poly {
    my ($self, $glyph) = @_;
    $self->{'glyphs'}{'Poly'}{"$glyph->{'colour'}:$glyph->{'bordercolour'}"} ++;
}
sub render_Space {
    my ($self, $glyph) = @_;
    $self->{'glyphs'}{'Space'}{"$glyph->{'colour'}:$glyph->{'bordercolour'}"} ++;
}
sub render_Diagnostic {
  my ($self, $glyph) = @_;
  my $strand = defined( $glyph->{'strand'} ) ?
     ( $glyph->{'strand'}<0 ? 'reverse strand' : 'forward strand' ) :
     'unstranded';
  $self->{'tracks'}{$glyph->{'track'}}{ $strand } = [ $glyph->{'glyphs'}, $glyph->{'rendered'} ];
}
1;
