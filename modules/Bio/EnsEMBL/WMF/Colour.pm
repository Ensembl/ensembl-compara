package Colour;
use strict;

sub new {
  my ($class, $r, $g, $b) = @_;
  my $obj = bless {
                _r               	=>  undef,
                _g	             	=>  undef,
                _b              	=>  undef,
                _a	         	   	=>  undef,
                _rgb          		=>  undef,
                }, $class;
	$obj->_initialise($r, $g, $b);
	return $obj;
}

sub _initialise {
    my ($self, $r, $g, $b) = @_;
	if (defined $r && defined $g && defined $b){
		$self->setColour($r, $g, $b);
	}
}

sub _packColours {
    my ($self) = @_;
	my $rgb = $self->writeInteger(	  $self->red() & 0xFF
									| $self->green() << 8 & 0xFF00
									| $self->blue() << 16 & 0xFF0000 
								 );
	$self->{'_rgb'} = $rgb;
	return ($rgb);
}

sub rgb {
    my ($self, $rgb) = @_;
    if (defined $rgb) {
		$self->{'_rgb'} = $rgb;
    	return $rgb;
    } else {
		return ( $self->{'_rgb'} )
	}
}

sub loWord {
    my ($self, $word) = @_;
	return ($word & 0xFFFF)
}

sub hiWord {
    my ($self, $word) = @_;
	return ($word & 0xFFFF0000) >> 16;
}

sub writeWord {
	my ($self, $int) = @_;
	$self->outputWord($int);
}

sub outputWord {
	my ($self, $int) = @_;
	my $out = undef;
	$out .= pack ("C",  ($int & 0xFF));
	$out .= pack ("C", (($int & 0xFF00)>>8));
	return($out);
}

sub outputInteger {
	my ($self, $int) = @_;
	$self->outputWord($self->loWord($int));
	$self->outputWord($self->hiWord($int));
}

sub writeInteger {
	my ($self, $int) = @_;
	$self->writeWord($self->loWord($int));
	$self->writeWord($self->hiWord($int));
}

sub setColour {
    my ($self, $colour, $col2, $col3, $col4) = @_;
	if (defined $col2 && defined $col3){
		$self->red($colour);
		$self->green($col2);
		$self->blue($col3);
		return($self->_packColours());
	}
    elsif (defined $colour) {
		if ($colour eq "red"){
			$self->red(255);
			$self->green(0);
			$self->blue(0);
		} elsif ($colour eq "green"){
			$self->red(0);
			$self->green(255);
			$self->blue(0);
		} elsif ($colour eq "blue"){
			$self->red(0);
			$self->green(0);
			$self->blue(255);
		} elsif ($colour eq "black"){
			$self->red(0);
			$self->green(0);
			$self->blue(0);
		} else {
			$self->red(255);	# default is white
			$self->green(255);
			$self->blue(255);
		}
		if(defined $self->red() && defined $self->green() && defined $self->blue()){
			return ($self->_packColours());
		} else {
			return (undef);
		}
	}
}

sub red {
    my ($self, $r) = @_;
    if (defined $r) {
		if ($r =~ /^0x/){
			$r = $self->fromHex($r);
		}
		$self->{'_r'} = $r;
    	return $r;
    } else {
		return ( $self->{'_r'} )
	}
}

sub green {
    my ($self, $g) = @_;
    if (defined $g) {
		if ($g =~ /^0x/){
			$g = $self->fromHex($g);
		}
		$self->{'_g'} = $g;
    	return $g;
    } else {
		return ( $self->{'_g'} )
	}
}

sub blue {
    my ($self, $b) = @_;
    if (defined $b) {
		if ($b =~ /^0x/){
			$b = $self->fromHex($b);
		}
		$self->{'_b'} = $b;
    	return $b;
    } else {
		return ( $self->{'_b'} )
	}
}

sub fromHex {
    my ($self, $h) = @_;
	return (hex($h));
}

1;
