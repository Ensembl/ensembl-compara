package Font;

use strict;
use WMF::Colour;
use WMF::Constants;

sub new {
  my ($class,$height,$width,$esc,$ori,$weight,$italic,$underline,
  	  $strikeout,$charset,$outprecision,$clipprecision,$quality,
	  $pitchandfamily,$facename) = @_;
  my $obj = bless {
                _height             =>  -12,
                _width	            =>  0,
                _esc              	=>  0,
                _ori	         	=>  0,
                _weigth          	=>  0,
                _italic             =>  0,
                _underline	        =>  0,
                _strikeout          =>  0,
                _charset	        =>  0,
                _outprecision       =>  0,
                _clipprecision      =>  0,
                _quality	        =>  0,
                _pitchandfamily     =>  0,
                _facename	        =>  "Arial",
                _font          		=>  undef,	# packed font structure
                }, $class;
	$obj->_initialise($height,$width,$esc,$ori,$weight,$italic,$underline,
  	  				  $strikeout,$charset,$outprecision,$clipprecision,$quality,
	  				  $pitchandfamily,$facename);
	return $obj;
}

sub setFont {
    my ($self,$height,$width,$esc,$ori,$weight,$italic,$underline,
  	  	$strikeout,$charset,$outprecision,$clipprecision,$quality,
	  	$pitchandfamily,$facename) = @_;
	$self->{'_height'} 			= $height;
	$self->{'_width'} 			= $width;
	$self->{'_esc'} 			= $esc;
	$self->{'_ori'} 			= $ori;
	$self->{'_weight'} 			= $weight;
	$self->{'_italic'} 			= $italic;
	$self->{'_underline'} 		= $underline;
	$self->{'_strikeout'} 		= $strikeout;
	$self->{'_charset'} 		= $charset;				#byte
	$self->{'_outprecision'} 	= $outprecision;		#byte
	$self->{'_clipprecision'} 	= $clipprecision;		#byte
	$self->{'_quality'} 		= $quality;				#byte
	$self->{'_pitchandfamily'} 	= $pitchandfamily;		#byte
	$self->{'_facename'} 		= $facename;
}

sub isItalic {
	my ($self) = @_;
	return($self->{'_italic'});
}

sub isBold {
	my ($self) = @_;
	if ($self->{'_weight'} >=700){
		return(1);
	} else {
		return(0)
	}
}

sub getFace {
	my ($self) = @_;
	return($self->{'_facename'});
}

sub getSize {
	my ($self) = @_;
	return($self->{'_height'});
}

sub height {
	my ($self) = @_;
	return($self->getSize());
}

sub width {
	my ($self) = @_;
	return($self->{'_width'});
}

sub getWeight {
	my ($self) = @_;
	return($self->{'_weight'});
}

sub toByte {
	my ($self, $byte) = @_;
	$b = unpack("C*", $byte);
	return($byte);
}

sub _initialise {
    my ($self) = shift;
	if (scalar(@_) != 14){
		die("Error: parameter mismatch while creating font!\n");
	}
	$self->setFont(@_);
}

1;
