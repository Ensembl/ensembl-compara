#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::GlyphSet;
use strict;
use Exporter;
use Sanger::Graphics::Glyph::Diagnostic;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Root;
use Sanger::Graphics::Glyph::Space;

use base qw( Sanger::Graphics::Root );

#########
# constructor
#
sub new {
    my ($class, $Container, $Config, $highlights, $strand, $extra_config) = @_;
    my $self = {
	'glyphs'     => [],
	'x'          => undef,
	'y'          => undef,
	'width'      => undef,
	'highlights' => $highlights,
	'strand'     => $strand,
	'minx'       => undef,
	'miny'       => undef,
	'maxx'       => undef,
	'maxy'       => undef,
	'label'      => undef,
        'bumped'     => undef,
        'bumpbutton' => undef,
	'label2'     => undef,	
	'container'  => $Container,
	'config'     => $Config,
	'extras'     => $extra_config,
    };

    bless($self, $class);
    $self->init_label() if($self->can('init_label'));
    return $self;
}

#########
# _init creates masses of Glyphs from a data source.
# It should executes bumping and globbing on the fly and also
# keep track of x,y,width,height as it goes.
#
sub _init {
    my ($self) = @_;
    print STDERR qq($self unimplemented\n);
}

# Gets the number of Base Pairs per pixel
sub basepairs_per_pixel {
    my ($self) = @_;
    my $pixels = $self->{'config'}->get_parameter( 'width' );
    return (defined $pixels && $pixels) ? $self->{'container'}->length() / $pixels : undef; 
}    

sub glob_bp {
    my ($self) = @_;
    return int( $self->basepairs_per_pixel()*2 );
}


# join_tag joins between glyphsets in different tracks
#$self->join_tag(
#  $tglyph,         # A glyph you've drawn...
#  $key,            # Key for glyph
#  $T,              # X position in glyph (0-1)
#  0,               # Y position in glyph (0-1) 0 nearest contigs
#  $colour,         # colour to draw shape
#  'fill',          # whether to fill or draw line
#  -99              # z-index 
#);

sub join_tag {
  my( $self, $glyph, $tag, $x_pos, $y_pos, $col, $style, $zindex, $href, $alt ) = @_;
  if( ref($x_pos) eq 'HASH' ) {
    CORE::push @{$self->{'tags'}{$tag}}, {
      %$x_pos,
      'glyph' => $glyph
    };
  } else {
    CORE::push @{$self->{'tags'}{$tag}}, {
      'glyph' => $glyph,
      'x'     => $x_pos,
      'y'     => $y_pos,
      'col'   => $col, 
      'style' => $style,
      'z'     => $zindex,
      'href'  => $href,
      'alt'   => $alt
    };
  }
}

#########
# return our list of glyphs
#
sub glyphs {
    my ($self) = @_;
    return @{$self->{'glyphs'}};
}

#########
# push either a Glyph or a GlyphSet on to our list
#
sub push {
    my $self = CORE::shift;
    my ($gx, $gx1, $gy, $gy1);
    
    foreach my $Glyph (@_) {
    	CORE::push @{$self->{'glyphs'}}, $Glyph;

    	$gx  =       $Glyph->x() || 0;
    	$gx1 = $gx + ($Glyph->width() || 0);
	$gy  =       $Glyph->y() || 0;
    	$gy1 = $gy + ($Glyph->height() || 0);

    ######### track max and min dimensions
        $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
        $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
        $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
        $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
    }
}

#########
# unshift a Glyph or GlyphSet onto our list
#
sub unshift {
    my $self = CORE::shift;

    my ($gx, $gx1, $gy, $gy1);
    
    foreach my $Glyph (reverse @_) {
        CORE::unshift @{$self->{'glyphs'}}, $Glyph;

      	$gx  =       $Glyph->x();
       	$gx1 = $gx + $Glyph->width();
        $gy  =       $Glyph->y();
       	$gy1 = $gy + $Glyph->height();
    
        $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
        $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
        $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
        $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
    }
}

########## pop/shift a Glyph off our list
# needs to shrink glyphset dimensions if the glyph/glyphset we pop off 

sub pop {
    my ($self) = @_;
    return CORE::pop @{$self->{'glyphs'}};
}

sub shift {
    my ($self) = @_;
    return CORE::shift @{$self->{'glyphs'}};
}

########## read-only getters
sub x {
    my ($self) = @_;
    return $self->{'x'};
}

sub y {
    my ($self) = @_;
    return $self->{'y'};
}

sub highlights {
  my ($self) = @_;
  return defined $self->{'highlights'} ? @{$self->{'highlights'}} : ();
}

########## read-write get/setters...

sub minx {
    my ($self, $minx) = @_;
    $self->{'minx'} = $minx if(defined $minx);
    return $self->{'minx'};
}

sub miny {
    my ($self, $miny) = @_;
    $self->{'miny'} = $miny if(defined $miny);
    return $self->{'miny'};
}

sub maxx {
    my ($self, $maxx) = @_;
    $self->{'maxx'} = $maxx if(defined $maxx);
    return $self->{'maxx'};
}

sub maxy {
    my ($self, $maxy) = @_;
    $self->{'maxy'} = $maxy if(defined $maxy);
    return $self->{'maxy'};
};

sub strand {
    my ($self, $strand) = @_;
    $self->{'strand'} = $strand if(defined $strand);
    return $self->{'strand'};
}

sub label {
    my ($self, $val) = @_;
    $self->{'label'} = $val if(defined $val);
    return $self->{'label'};
}

sub bumped {
    my ($self, $val) = @_;
    $self->{'bumped'} = $val if(defined $val);
    return $self->{'bumped'};
}

##
## additional derived functions
##

sub height {
    my ($self) = @_;
    return abs($self->{'maxy'}-$self->{'miny'});
}

sub width {
    my ($self) = @_;
    return abs($self->{'maxx'}-$self->{'minx'});
}

sub length {
    my ($self) = @_;
    return scalar @{$self->{'glyphs'}};
}

sub transform {
    my ($self) = @_;
    my $T = $self->{'config'}->{'transform'};
    foreach( @{$self->{'glyphs'}} ) {
	$_->transform($T);
    }
}

sub _dump {
  my($self) = CORE::shift;
  $self->push( new Sanger::Graphics::Glyph::Diagnostic({
    'x'      =>0 ,
    'y'      =>0 ,
    'track'  => ref($self),
    'strand' => $self->strand(),
    'glyphs' => scalar @{$self->{'glyphs'}},
    @_
  }));
  return;
}

sub errorTrack {
    my ($self, $message, $x, $y) = @_;
    my $length = $self->{'config'}->image_width();
    my $w      = $self->{'config'}->texthelper()->width('Tiny');
    my $h      = $self->{'config'}->texthelper()->height('Tiny');
    my $h2     = $self->{'config'}->texthelper()->height('Small');
    $self->push( new Sanger::Graphics::Glyph::Text({
    	'x'         => $x || int( ($length - $w * CORE::length($message))/2 ),
        'y'         => $y || int( ($h2-$h)/2 ),
    	'height'    => $h2,
        'font'      => 'Tiny',
        'colour'    => "red",
        'text'      => $message,
        'absolutey' => 1,
        'absolutex' => 1,
        'absolutewidth' => 1,
        'pixperbp'  => $self->{'config'}->{'transform'}->{'scalex'} ,
    }) );
    
    return;
}

sub commify { CORE::shift; local $_ = reverse $_[0]; s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g; return scalar reverse $_; }

sub check {
  my $self   = CORE::shift;
  my ($name) = ref($self) =~ /::([^:]+)$/;
  return $name;
} 
1;
