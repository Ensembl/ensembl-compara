package Rectangle;

use strict;

sub new {
  my ($class,$x,$y,$width,$height) = @_;
  my $obj = bless {
  				_x					=>  0,
  				_y					=>  0,
                _width	            =>  0,
                _height             =>  0,
                }, $class;
	$obj->_initialise($x,$y,$width,$height);
	return $obj;
}

sub x {
	my ($self,$x) = @_;
	if (defined $x){
		$self->{'_x'} = $x;
	} else {
		return($self->{'_x'});
	}
}

sub y {
	my ($self,$y) = @_;
	if (defined $y){
		$self->{'_y'} = $y;
	} else {
		return($self->{'_y'});
	}
}

sub width {
	my ($self,$width) = @_;
	if (defined $width){
		$self->{'_width'} = $width;
	} else {
		return($self->{'_width'});
	}
}

sub height {
	my ($self,$height) = @_;
	if (defined $height){
		$self->{'_height'} = $height;
	} else {
		return($self->{'_height'});
	}
}

sub _initialise {
    my ($self,$x,$y,$width,$height) = @_;
	$self->x($x);
	$self->y($y);
	$self->width($width);
	$self->height($height);
}

1;
