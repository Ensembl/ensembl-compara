package WMF;
# Copyright 2001 Tony Cox.  See accompanying README file for
# usage information

require 5.00323;
require Exporter;
use strict;
use WMF::Constants;
use WMF::Colour;
use WMF::Font;
use WMF::Rectangle;
use WMF::Polygon;
use WMF::Image;
use vars qw($VERSION @ISA @EXPORT $AUTOLOAD);
$VERSION = "1.00";

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
        gdBrushed
        gdDashSize
        gdMaxColors
        gdStyled
        gdStyledBrushed
        gdTiled
        gdTransparent
        gdTinyFont
        gdSmallFont
        gdMediumBoldFont
        gdLargeFont
        gdGiantFont
);

sub _initialise {
    my ($self,$x,$y) = @_;
	$self->{'_x'} = $x;
	$self->{'_y'} = $y;
	$self->{'_bgcolour'} = new Colour(255,255,255);
	$self->{'_wmf'} = new Image();
	$self->{'_wmf'}->setROP2($R2_COPYPEN);
	$self->{'_wmf'}->setWindowExt($x,$y);
	$self->{'_wmf'}->setMapMode($MM_TEXT);
	$self->{'_wmf'}->setWindowOrg(0,0);
}

sub new {
  my ($class,$x,$y) = @_;
  my $obj = bless {
                _filename               =>  undef,
				_wmf					=>  undef,
				_x						=>  $x,
				_y						=>  $y,
				_bgcolour				=>  undef,
				_trans					=>  0,
				_ncolours				=>  0,
                }, $class;

	$obj->_initialise($x,$y);
	return $obj;
}

sub string {
	my ($self,$font,$x,$y,$string,$c) = @_;
	# we have been passed a font object so 
	# need to make a GDI object and handle from it
	if ($font->isa("Font")){
		my $hFont = $self->{'_wmf'}->createFontIndirect(
			$font->{'_height'},
			$font->{'_width'},
			$font->{'_esc'},
			$font->{'_ori'},
			$font->{'_weigth'},
			$font->{'_italic'},
			$font->{'_underline'},
			$font->{'_strikeout'},
			$self->{'_wmf'}->toByte($font->{'_charset'}),
			$self->{'_wmf'}->toByte($font->{'_outprecision'}),
			$self->{'_wmf'}->toByte($font->{'_clipprecision'}),
			$self->{'_wmf'}->toByte($font->{'_quality'}),
			$self->{'_wmf'}->toByte($font->{'_pitchandfamily'}),
			$font->{'_facename'},
		    );
		$self->{'_wmf'}->setTextColour($c);
		$self->{'_wmf'}->setBKMode($TRANSPARENT);
		$self->{'_wmf'}->setTextAlign($TA_TOP);
		$self->{'_wmf'}->selectObject($hFont);
		$self->{'_wmf'}->textOut($x,$y,$string);
		$self->{'_wmf'}->deleteObject($hFont);
		return(1);
	} else {
		die "Error: string function requires a valid Font object!\n";
	}
}

sub filledString {
	my ($self,$font,$x,$y,$string,$c,$c2) = @_;
	# we have been passed a font object so 
	# need to make a GDI object and handle from it
	if ($font->isa("Font")){
		my $hFont = $self->{'_wmf'}->createFontIndirect(
			$font->{'_height'},
			$font->{'_width'},
			$font->{'_esc'},
			$font->{'_ori'},
			$font->{'_weigth'},
			$font->{'_italic'},
			$font->{'_underline'},
			$font->{'_strikeout'},
			$self->{'_wmf'}->toByte($font->{'_charset'}),
			$self->{'_wmf'}->toByte($font->{'_outprecision'}),
			$self->{'_wmf'}->toByte($font->{'_clipprecision'}),
			$self->{'_wmf'}->toByte($font->{'_quality'}),
			$self->{'_wmf'}->toByte($font->{'_pitchandfamily'}),
			$font->{'_facename'},
		    );
		$self->{'_wmf'}->setTextColour($c);
		$self->{'_wmf'}->setBKColour($c2);
		$self->{'_wmf'}->setBKMode($OPAQUE);
		my $hBrush = $self->{'_wmf'}->createBrushIndirect($BS_SOLID,$c2,0);	
		$self->{'_wmf'}->selectObject($hBrush);	
		$self->{'_wmf'}->setTextAlign($TA_TOP);
		$self->{'_wmf'}->selectObject($hFont);
		$self->{'_wmf'}->textOut($x,$y,$string);
		$self->{'_wmf'}->deleteObject($hBrush);
		$self->{'_wmf'}->deleteObject($hFont);
		return(1);
	} else {
		die "Error: string function requires a valid Font object!\n";
	}
}

sub gdTinyFont {
	my $font = new Font(-10,0,0,0,$FW_BOLD,0,0,0,
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
			    unpack("C*", $FF_SWISS),
			   "Arial");
	return($font);
}

sub gdSmallFont {
	my $font = new Font(-11,0,0,0,$FW_BOLD,0,0,0,
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
			    unpack("C*", $FF_SWISS),
			   "Arial");
	return($font);
}

sub gdMediumBoldFont {
	my $font = new Font(-14,0,0,0,$FW_BOLD,0,0,0,
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
			    unpack("C*", $FF_SWISS),
			   "Arial");
	return($font);
}

sub gdLargeFont {
	my $font = new Font(-15,0,0,0,$FW_BOLD,0,0,0,
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
			    unpack("C*", $FF_SWISS),
			   "Arial");
	return($font);
}

sub gdGiantFont {
	my $font = new Font(-17,0,0,0,$FW_NORMAL,0,0,0,
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
               	unpack("C*", 0),
			    unpack("C*", $FF_SWISS),
			   "Arial");
	return($font);
}

sub getBounds {
	my ($self) = @_;
	return($self->{'_x'},$self->{'_y'});
}

sub fill {
	my ($self,$x,$y,$c) = @_;
	my $hBrush = $self->{'_wmf'}->createBrushIndirect($BS_SOLID,$c,0);	
	$self->{'_wmf'}->selectObject($hBrush);	
	$self->{'_wmf'}->floodFill($x, $y, $c);
	$self->{'_wmf'}->deleteObject($hBrush);
	return(1);
}

sub fillToBorder {
	my ($self,$x,$y,$c) = @_;
	print STDERR "The fillToBorder method is not implemented yet\n";
	# The GDI funtion number for extFloodFill seems to have problems
	# Although published it is not supported on NT4.
	return(1);
	my $hBrush = $self->{'_wmf'}->createBrushIndirect($BS_SOLID,$c,0);	
	$self->{'_wmf'}->selectObject($hBrush);	
	$self->{'_wmf'}->extFloodFill($x, $y, $c,$FLOODFILLSURFACE);
	$self->{'_wmf'}->deleteObject($hBrush);
	return(1);
}

sub polygon {
    my ($self,$poly,$c) = @_;
	my $hPen = $self->{'_wmf'}->createPenIndirect($PS_SOLID,0,$c);	
	$self->{'_wmf'}->selectObject($hPen);	
	my $hBrush = $self->{'_wmf'}->createBrushIndirect($BS_HOLLOW,$c,0);	
	$self->{'_wmf'}->selectObject($hBrush);	
	my $x_vertices = $poly->_xvertices();
	my $y_vertices = $poly->_yvertices();
	if ($poly->length() >= 3){
		$self->{'_wmf'}->polygon($x_vertices,$y_vertices,$poly->length());
	} else {
		die("Cannot create polygon with fewer than 3 vertices!");
	}
	$self->{'_wmf'}->deleteObject($hPen);
	$self->{'_wmf'}->deleteObject($hBrush);
	return(1);
}

sub filledPolygon {
    my ($self,$poly,$c) = @_;
	my $hPen = $self->{'_wmf'}->createPenIndirect($PS_SOLID,0,$c);	
	$self->{'_wmf'}->selectObject($hPen);	
	my $hBrush = $self->{'_wmf'}->createBrushIndirect($BS_SOLID,$c,0);	
	$self->{'_wmf'}->selectObject($hBrush);	
	my $x_vertices = $poly->_xvertices();
	my $y_vertices = $poly->_yvertices();
	if ($poly->length() >= 3){
		$self->{'_wmf'}->polygon($x_vertices,$y_vertices,$poly->length());
	} else {
		die("Cannot create polygon with fewer than 3 vertices!");
	}
	$self->{'_wmf'}->deleteObject($hPen);
	$self->{'_wmf'}->deleteObject($hBrush);
	return(1);
}

sub line {
    my ($self,$x1,$y1,$x2,$y2,$c) = @_;
	my $hPen = $self->{'_wmf'}->createPenIndirect($PS_SOLID,0,$c);	
	$self->{'_wmf'}->selectObject($hPen);	
	$self->{'_wmf'}->moveTo($x1,$y1);	
	$self->{'_wmf'}->lineTo($x2,$y2);	
	$self->{'_wmf'}->deleteObject($hPen);
	return(1);
}

sub dashedLine {
    my ($self,$x1,$y1,$x2,$y2,$c) = @_;
	my $hPen = $self->{'_wmf'}->createPenIndirect($PS_DOT,0,$c);	
	$self->{'_wmf'}->selectObject($hPen);	
	$self->{'_wmf'}->moveTo($x1,$y1);	
	$self->{'_wmf'}->lineTo($x2,$y2);	
	$self->{'_wmf'}->deleteObject($hPen);
	return(1);
}

sub setPixel {
    my ($self,$x,$y,$c) = @_;
	my $hPen = $self->{'_wmf'}->createPenIndirect($PS_SOLID,0,$c);	
	$self->{'_wmf'}->selectObject($hPen);	
	$self->{'_wmf'}->setPixel($x,$y,$c);	
	$self->{'_wmf'}->deleteObject($hPen);
	return(1);
}

sub arc {
    my ($self,$x,$y,$x2,$y2,$ax1,$ay1,$ax2,$ay2,$c) = @_;
	my $hPen = $self->{'_wmf'}->createPenIndirect($PS_SOLID,0,$c);	
	$self->{'_wmf'}->selectObject($hPen);	
	$self->{'_wmf'}->arc($x,$y,$x2,$y2,$ax1,$ay1,$ax2,$ay2,$c);	
	$self->{'_wmf'}->deleteObject($hPen);
	return(1);
}

sub rectangle {
    my ($self,$x1,$y1,$x2,$y2,$c) = @_;
	my $hPen = $self->{'_wmf'}->createPenIndirect($PS_SOLID,0,$c);	
	$self->{'_wmf'}->selectObject($hPen);	
	my $hBrush = $self->{'_wmf'}->createBrushIndirect($BS_HOLLOW,$c,0);	
	$self->{'_wmf'}->selectObject($hBrush);	
	$self->{'_wmf'}->rectangle($x1,$y1,$x2,$y2);	
	$self->{'_wmf'}->deleteObject($hPen);
	$self->{'_wmf'}->deleteObject($hBrush);
	return(1);
}

sub filledRectangle {
    my ($self,$x1,$y1,$x2,$y2,$c) = @_;
	print STDERR "Rectangle: $x1,$y1,$x2,$y2\n";		# DEBUG ONLY
	my $hPen = $self->{'_wmf'}->createPenIndirect($PS_SOLID,0,$c);	
	$self->{'_wmf'}->selectObject($hPen);	
	my $hBrush = $self->{'_wmf'}->createBrushIndirect($BS_SOLID,$c,0);	
	#my $hBrush = $self->{'_wmf'}->createBrushIndirect($BS_HOLLOW,$c,0);	# DEBUG ONLY
	$self->{'_wmf'}->selectObject($hBrush);	
	$self->{'_wmf'}->rectangle($x1,$y1,$x2,$y2);	
	$self->{'_wmf'}->deleteObject($hPen);
	$self->{'_wmf'}->deleteObject($hBrush);
	return(1);
}
	
sub colorAllocate {
    my ($self,$r,$g,$b) = @_;
	my $colour = new Colour($r,$g,$b);
	$self->{'_ncolours'}++;
	return($colour);
}

sub colorDeallocate {
    my ($self,$c) = @_;
	$c = undef;
}

sub colorsTotal {
    my ($self) = @_;
	return($self->{'_ncolours'});
}

sub rgb {
    my ($self, $c) = @_;
	my $r = $c->red();
	my $g = $c->green();
	my $b = $c->blue();
	return($r,$g,$b);
}

sub wmf {
    my ($self) = @_;
	$self->{'_wmf'}->deleteObjects();	# clean up undeleted GDI handles
	$self->{'_wmf'}->metaRecord(0,0);
	return($self->{'_wmf'}->wmf($self->{'_x'},$self->{'_y'}));
}

1;

