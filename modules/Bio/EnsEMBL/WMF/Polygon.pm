package Polygon;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = "1.00";
$DEBUG   = 0;

sub new {
  my ($class) = shift;
  my @vertices = @_;
  my $obj = bless {
  				_vertices			=>  [],
				_xvertices			=>  [],
  				_yvertices			=>  [],
  				_numvertices		=>  0,
                }, $class;
	$obj->_initialise(@vertices);
	return $obj;
}

sub addPt {
    my ($self,$x,$y) = @_;
	unless (defined $x && defined $y){
		die("Cannot create polygon: x/y vertex coordinate number mismatch\n");
	}
	push (@{$self->{'_xvertices'}},$x);
	push (@{$self->{'_yvertices'}},$y);
	push (@{$self->{'_vertices'}},$x);
	push (@{$self->{'_vertices'}},$y);
	$self->{'_numvertices'}++;
	print STDERR "Added polygon vertex ",$self->{'_numvertices'},"\n" if $DEBUG;
}

sub getPt {
    my ($self,$p) = @_;
	return($self->{'_xvertices'}->[$p],$self->{'_yvertices'}->[$p]);
}

sub toPt {
    my ($self,$x,$y) = @_;
	$self->addPt($x,$y);
}

sub setPt {
    my ($self,$p,$x,$y) = @_;
	$self->{'_xvertices'}->[$p] = $x;
	$self->{'_yvertices'}->[$p] = $y;
}

sub vertices {
    my ($self) = @_;
	return(@{$self->{'_vertices'}});
}

sub _xvertices {
    my ($self) = @_;
	return($self->{'_xvertices'});
}

sub _yvertices {
    my ($self) = @_;
	return($self->{'_yvertices'});
}

sub length {
    my ($self) = @_;
	return($self->{'_numvertices'});
}

sub bounds {
    my $self = shift;
    my($top,$bottom,$left,$right) = @_;
    $top =    99999999;
    $bottom =-99999999;
    $left =   99999999;
    $right = -99999999;
    my $v;
    for (my $v=0; $v < scalar(@$self->_vertices);$v++) {
        $left = $self->{'_xvertices'}->[$v] if $left > $self->{'_xvertices'}->[$v];
        $right = $self->{'_xvertices'}->[$v] if $right < $self->{'_xvertices'}->[$v];
        $top = $self->{'_yvertices'}->[$v] if $top > $self->{'_yvertices'}->[$v];
        $bottom = $self->{'_yvertices'}->[$v] if $bottom < $self->{'_yvertices'}->[$v];
    }
    return ($left,$top,$right,$bottom);
}

sub offset {
    my($self,$dh,$dv) = @_;
    my $size = $self->length();
    my($i);
    for ($i=0;$i<$size;$i++) {
        my($x,$y)=$self->getPt($i);
        $self->setPt($i,$x+$dh,$y+$dv);
    }
}

sub delete {		# think this is bugged
    my($self,$index) = @_;
    my($xvertex) = splice(@{$self->{'_xvertices'}},$index,1);
    my($yvertex) = splice(@{$self->{'_yvertices'}},$index,1);
    return ($xvertex,$yvertex);
}

sub map {
    my($self,$srcL,$srcT,$srcR,$srcB,$destL,$destT,$destR,$destB) = @_;
    my($factorV) = ($destB-$destT)/($srcB-$srcT);
    my($factorH) = ($destR-$destL)/($srcR-$srcL);
    my($vertices) = $self->length;
    my($i);
    for ($i=0;$i<$vertices;$i++) {
        my($x,$y) = $self->getPt($i);
        $x = int($destL + ($x - $srcL) * $factorH);
        $y = int($destT + ($y - $srcT) * $factorV);
        $self->setPt($i,$x,$y);
    }
}

sub transform($$$$$$$) {
    # see PostScript Ref. page 154
    my($self, $a, $b, $c, $d, $tx, $ty) = @_;
    my $size = $self->length;
    for (my $i=0;$i<$size;$i++) {
        my($x,$y)=$self->getPt($i);
        $self->setPt($i, $a*$x+$c*$y+$tx, $b*$x+$d*$y+$ty);
    }
    
}

sub scale {
    my($self, $sx, $sy) = @_;
    $self->transform($sx,0,0,$sy,0,0);
}

sub _initialise {
    my ($self) = shift;
}

1;
