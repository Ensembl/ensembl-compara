package Bio::EnsEMBL::Glyph;
use strict;
use lib "../../../../modules";
use ColourMap;
use Exporter;
use vars qw(@ISA $AUTOLOAD);
@ISA = qw(Exporter);

#########
# constructor
# _methods is a hash of valid methods you can call on this object
#
sub new {
    my ($class, $params_ref) = @_;
    my $self = {
	'background' => 'transparent',
	'composite'  => undef,           # arrayref for Glyph::Composite to store other glyphs in
	'points'     => [],		 # listref for Glyph::Poly to store x,y paired points
    };
    bless($self, $class);

    #########
    # initialise all fields except type
    #
#    for my $field (qw(x y width height text colour bordercolour font onmouseover onmouseout zmenu href pen brush background id points absolutex absolutey)) {
    for my $field (keys %{$params_ref}) {
	$self->{$field} = $$params_ref{$field} if(defined $$params_ref{$field});
    }

    return $self;
}

#########
# read-write methods
#
sub AUTOLOAD {
    my ($this, $val) = @_;
    my $field = $AUTOLOAD;
    $field =~ s/.*:://;

    $this->{$field} = $val if(defined $val);
    return $this->{$field};
}

#########
# apply a transformation.
# pass in a hashref containing keys
#  - translatex
#  - translatey
#  - scalex
#  - scaley
#
sub transform {
    my ($this, $transform_ref) = @_;

    my $scalex     = $$transform_ref{'scalex'}     || 1;
    my $scaley     = $$transform_ref{'scaley'}     || 1;
    my $translatex = $$transform_ref{'translatex'} || 0;
    my $translatey = $$transform_ref{'translatey'} || 0;
    my $rotation   = $$transform_ref{'rotation'}   || 0;
    my $clipx      = $$transform_ref{'clipx'}      || 0;
    my $clipy      = $$transform_ref{'clipy'}      || 0;
    my $clipwidth  = $$transform_ref{'clipwidth'}  || 0;
    my $clipheight = $$transform_ref{'clipheight'} || 0;

    #########
    # override transformation if we've set x/y to be absolute (pixel) coords
    #
    if(defined $this->absolutex()) {
	$scalex     = $$transform_ref{'absolutescalex'} || 1;
    }

    if(defined $this->absolutey()) {
	$scaley     = $$transform_ref{'absolutescaley'} || 1;
    }

    #########
    # apply scale
    #
    $this->pixelx      (int($this->x()      * $scalex));
    $this->pixely      (int($this->y()      * $scaley));
    $this->pixelwidth  (int($this->width()  * $scalex));
    $this->pixelheight (int($this->height() * $scaley));

    #########
    # apply translation
    #
    $this->pixelx($this->pixelx() + $translatex);
    $this->pixely($this->pixely() + $translatey);

    #########
    # todo: check rotation
    #
}

sub centre {
    my ($this, $arg) = @_;

    my ($x, $y);

    if($arg eq "px") {
	#########
	# return calculated px coords
	# pixel coordinates are only available after a transformation has been applied
	#
        $x = int($this->pixelwidth() / 2) + $this->pixelx();
        $y = int($this->pixelheight() / 2) + $this->pixely();
    } else {
	#########
	# return calculated bp coords
	#
        $x = int($this->width() / 2) + $this->x();
        $y = int($this->height() / 2) + $this->y();
    }

    return ($x, $y);
}

sub end {
    my ($this) = @_;
    return $this->{'x'} + $this->{'width'};
}

1;
