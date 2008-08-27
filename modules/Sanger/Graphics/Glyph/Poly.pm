#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::Glyph::Poly;
use strict;
use base qw(Sanger::Graphics::Glyph);

sub points {
    my ($this, $points_ref) = @_;
    $this->{'points'} = $points_ref if(defined $points_ref);
    return $this->{'points'};
}

sub x {
    my ($this) = @_;
    my $minx = undef;
    my @pts = @{$this->points()};

    while(defined(my $pt = shift @pts)) {
	shift @pts; # dispose of spare 'y' coord
	$minx = $pt if(!defined $minx || $pt < $minx);
    }
    return $minx;
}

sub y {
    my ($this) = @_;
    my $miny = undef;
    my @pts = @{$this->points()};

    shift @pts; # dispose of 'x'
    while(defined(my $pt = shift @pts)) {
	shift @pts; # dispose of spare 'x' coord
	$miny = $pt if(!defined $miny || $pt < $miny);
    }
    return $miny;
}

sub y_transform {
    my ($this, $delta) = @_;
    my @pts = @{$this->points()};
    my @newpts = ();
    while( my($x,$y) = splice(@pts,0,2) ) {
        push @newpts, $x, $y + $delta
    }
    $this->points( \@newpts );
}

sub width {
    my ($this) = @_;
    my $maxx = undef;
    my @pts = @{$this->points()};

    while(defined(my $pt = shift @pts)) {
	shift @pts; # dispose of spare 'y' coord
	$maxx = $pt if(!defined $maxx || $pt > $maxx);
    }
    my $minx = $this->x() || 0;
    $maxx ||= 0;
    return $maxx - $minx;
}

sub height {
    my ($this) = @_;
    my $maxy   = undef;
    my @pts    = @{$this->points()};

    shift @pts;
    while(defined(my $pt = shift @pts)) {
	shift @pts; # dispose of spare 'x' coord
    	$maxy = $pt if(!defined $maxy || $pt > $maxy);
    }
    my $miny = $this->y() || 0;
    $maxy  ||= 0;
    return $maxy - $miny;
}

sub transform {
    my ($this, $transform_ref) = @_;
#    return if(defined $this->{'read-only'});
#    $this->{'read-only'} = 1;

    my $scalex     = $$transform_ref{'scalex'};
    my $scaley     = $$transform_ref{'scaley'};
    my $translatex = $$transform_ref{'translatex'};
    my $translatey = $$transform_ref{'translatey'};

    #########
    # apply transformation
    #
    my @tmp_points = @{$this->points()};
    $this->{'pixelpoints'} ||= \@tmp_points;

    #########
    # override transformation if we've set x/y to be absolute (pixel) coords
    #
    if(defined $this->absolutex()) {
	$scalex     = $$transform_ref{'absolutescalex'};
    }

    if(defined $this->absolutey()) {
	$scaley     = $$transform_ref{'absolutescaley'};
    }

    #########
    # apply transformation
    #
    my $len = scalar @{$this->{'pixelpoints'}};

    for(my $i=0;$i<$len;$i+=2) {
        my $x = ${$this->{'pixelpoints'}}[$i];
        my $y = ${$this->{'pixelpoints'}}[$i+1];

	#########
	# apply scale
	#
	$x = int($x * $scalex) if(defined $scalex);
	$y = int($y * $scaley) if(defined $scaley);

	#########
	# apply translation
	#
	$x = $x + $translatex if(defined $translatex);
	$y = $y + $translatey if(defined $translatey);

	${$this->{'pixelpoints'}}[$i] = $x;
	${$this->{'pixelpoints'}}[$i+1] = $y;
    }
}
1;
