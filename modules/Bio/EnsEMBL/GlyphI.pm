package GlyphI;
use strict;
use Exporter;
use vars qw(@ISA $AUTOLOAD);
use Matrix;

use lib "../modules";
use ColourMap;
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
    };

    #########
    # initialise all fields except type
    #
    for my $field (qw(x y width height text colour bordercolour font onmouseover onmouseout zmenu href pen brush background id)) {
	$self->{$field} = $$params_ref{$field} if(defined $$params_ref{$field});
    }

    bless($self, $class);
#    $self->_init();

    return $self;
}

#sub render {
#    my ($this, $imagetype, $content_ref, $offset_ref) = @_;
#
#    my $fun = qq(render_$imagetype);
#    if($this->can($fun)) {
#	$this->$fun($content_ref, $offset_ref);
#    } else {
#	print STDERR qq(GlyphI::render don't know how to render $imagetype\n);
#    }
#}

#########
# pure virtual initialisation function
#
#sub _init {
#    print STDERR qq(GlyphI::_init unimplemented\n);
#}

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
    my $clipx      = $$transform_ref{'clipx'}      || 0;
    my $clipy      = $$transform_ref{'clipy'}      || 0;
    my $clipwidth  = $$transform_ref{'clipwidth'}  || 0;
    my $clipheight = $$transform_ref{'clipheight'} || 0;
    my $rotation      = $$transform_ref{'rotation'}   || 0;

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
    # apply mirror along x=y, flip along x=0 & translate x+=width
    # this is nasty rotation without the even nastier matrix manipulation
    #
    if($rotation == 90) {
	#########
	# mirror in x=y
	#
	my $t1 = $this->pixelx();
	$this->pixelx($this->pixely());
	$this->pixely($t1);

	my $t2 = $this->pixelwidth();
	$this->pixelwidth($this->pixelheight());
	$this->pixelheight($t2);

	#########
	# flip along x=0
	#
	$this->pixelx(-$this->pixelx());

	#########
	# translate x+=width
	#
	$this->pixelx($this->pixelx() + $clipwidth);
    }
#    #########
#    # full matrix rotation!
#    #
#    my $rotation = new Matrix(2,2, [
#				  [cos $angle, sin $angle],
#				  [-sin $angle, cos $angle],
#				 ]);
#    my $newcoords = new Matrix(1,2, [[0],[0]]);
#    my $coords = new Matrix(1,2, [
#				  [$this->pixelx(),],
#				  [$this->pixely(),],
#				]);
#    $coords->dump();
#    $rotation->dump();
#
#    #########
#    # apply rotation
#    #
#    my $n = 2;
#    for (my $i = 0; $i < $n; $i++) {
#	for (my $j = 0; $j < $n; $j++) {
#	    for (my $k = 0; $k < $n; $k++) {
#		$newcoords->coords($i,$j,
#		    ($newcoords->coords($i,$j) + $rotation->coords($i,$k) * $coords->coords($k, $j))
#		);
#	    }
#	}
#    }
#    $newcoords->coords(0,0, int($newcoords->coords(0,0)));
#    $newcoords->coords(0,1, int($newcoords->coords(0,1)));
#    print STDERR qq(coords before: ), $coords->coords(0,0), ", ", $coords->coords(0,1), qq(\n);
#    print STDERR qq(coords after: ), $newcoords->coords(0,0), ", ", $newcoords->coords(0,1), qq(\n);
#    $this->pixelx($newcoords->coords(0,0));
#    $this->pixely($newcoords->coords(0,1));

    #########
    # apply clipping
    #

}
