#########
# Author: js5@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2003
#
package Sanger::Graphics::Renderer::pdf;
use strict;


use PDF::API2;

use base qw(Sanger::Graphics::Renderer);

1;

sub init_canvas {
    my ($self, $config, $im_width, $im_height) = @_;

    $im_height = int($im_height)+0;
    $im_width  = int($im_width)+0;

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

sub Y { my( $self, $glyph ) = @_; return $self->{'canvas'}{'im_height'} - $glyph->pixely() - $glyph->pixelheight(); }
sub X { my( $self, $glyph ) = @_; return $glyph->pixelx() ; }
sub XY { my( $self, $x, $y ) = @_; return ( $x, $self->{'canvas'}{'im_height'} - $y ); }
sub H { my( $self, $glyph ) = @_; return 1 + $glyph->pixelheight(); }
sub W { my( $self, $glyph ) = @_; return 1 + $glyph->pixelwidth(); }

sub strokecolor { my $self = shift; $self->{'canvas'}{'g'}->strokecolor( "#".$self->{'colourmap'}->hex_by_name( shift ) ); }
sub fillcolor   { my $self = shift; $self->{'canvas'}{'g'}->fillcolor(   "#".$self->{'colourmap'}->hex_by_name( shift ) ); }
sub stroke      { my $self = shift; $self->{'canvas'}{'g'}->stroke; }
sub fill        { my $self = shift; $self->{'canvas'}{'g'}->fill; }
sub rect        { my $self = shift; $self->{'canvas'}{'g'}->rect(@_); }
sub move        { my $self = shift; $self->{'canvas'}{'g'}->move(@_); }
sub line        { my $self = shift; $self->{'canvas'}{'g'}->line(@_); }
sub hybrid      { my $self = shift; $self->{'canvas'}{'page'}->hybrid; }

sub render_Rect {
    my ($self, $glyph) = @_;
    my $gcolour       = $glyph->colour();
    my $gbordercolour = $glyph->bordercolour();

    my $x = $self->X($glyph);
    my $w = $self->W($glyph);
    my $h = $self->H($glyph);
    my $y = $self->Y($glyph);

    if(defined $gcolour) {
      unless( $gcolour eq 'transparent' ) {
        $self->fillcolor( $gcolour );
        $self->strokecolor( $gcolour );
	$self->rect($x,$y,$w,$h);
        # $self->stroke();
        $self->fill();
      }
    } elsif(defined $gbordercolour) {
      unless( $gcolour eq 'transparent' ) {
        $self->strokecolor( $gbordercolour );
	$self->rect($x,$y,$w,$h);
        $self->stroke();
      }
    }
}

sub render_Text {
    my ($self, $glyph) = @_;
    my $font = $glyph->font();
#    return;

    my $gcolour = $glyph->colour() || "black";
    my $text    = $glyph->text();
    my $x = $self->X($glyph);
    my $w = $self->W($glyph);
    my $y = $self->Y($glyph);
    my $h = $self->H($glyph);

    my $S = $glyph->{'ptsize'}||8;
    my $T = $self->{'canvas'}{'t'};
       $T->font( $self->{'canvas'}{'font'}, $S );
       $T->fillcolor( $gcolour ); 
    if( $glyph->{'valign'} eq 'top' ) {
      $y += $h - $S;
    } elsif( $glyph->{'valign'} eq 'bottom' ) {
      $y += 0;
    } else {
      $y += $h/2 - $S/2;
    }

    if( $glyph->{'halign'} eq 'right' ) {
      $T->translate( $x+$w, $y );
      $T->text_right( $text );
    } elsif( $glyph->{'halign'} eq 'center' ) {
      $T->translate( $x+$w/2, $y );
      $T->text_center( $text );
    } else {
      $T->translate( $x, $y );
      $T->text( $text );
    }
}

sub render_Circle {
#    die "Not implemented in pdf yet!";
}

sub render_Ellipse {
#    die "Not implemented in pdf yet!";
}

sub render_Intron {
    my ($self, $glyph) = @_;
    my $gcolour = $glyph->colour();

    my $x = $self->X($glyph);
    my $w = $self->W($glyph)/2;
    my $h = $self->H($glyph)/2 * ( $glyph->strand == -1 ? -1 : 1 );
    my $y = $self->Y($glyph);
    
    $x = $glyph->pixelx();
    $y = $self->Y($glyph) - ($glyph->strand() == -1 ? $h*2 : 0 );


    $self->strokecolor( $gcolour );
    $self->move( $x , $y + $h );
    $self->line( $x+$w , $y+2*$h );
    $self->line( $x+2*$w , $y+$h );
    $self->stroke();
}

sub render_Line {
    my ($self, $glyph) = @_;

    my $gcolour = $glyph->colour();
    return if $gcolour eq 'transparent';

    $glyph->transform($self->{'transform'});

    my $x = $self->X($glyph);
    my $w = $glyph->pixelwidth();
       $w = $self->W($glyph) if $w;
    my $h = $glyph->pixelheight();
       $h = $self->H($glyph) if $h;
    my $y = $self->Y($glyph);

    $self->strokecolor( $gcolour );
    $self->{'canvas'}{'g'}->linedash(5,5) if defined $glyph->dotted();
    $self->move( $x, $y );
    $self->line( $x+$w , $y+$h );
    $self->stroke();
    $self->{'canvas'}{'g'}->linedash() if defined $glyph->dotted();
}

sub render_Poly {
    my ($self, $glyph) = @_;
    my $gbordercolour = $glyph->bordercolour();
    my $gcolour       = $glyph->colour();

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
  my $spritename     = $glyph->{'sprite'} || "unknown";
  my $config         = $self->config();

  unless(exists $config->{'_spritecache'}->{$spritename}) {
    my $libref = $config->get_parameter(  "spritelib");
    my $lib    = $libref->{$glyph->{'spritelib'} || "default"};
    my $fn     = "$lib/$spritename.png";
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
