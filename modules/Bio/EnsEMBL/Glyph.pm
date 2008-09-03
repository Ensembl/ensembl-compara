package Bio::EnsEMBL::Glyph;
use strict;
our $AUTOLOAD;

#########
# constructor
# _methods is a hash of valid methods you can call on this object
#
sub new {
    my ($class, $params_ref) = @_;
    my $self = {
	    'background' => 'transparent',
	    'composite'  => undef,          # arrayref for Glyph::Composite to store other glyphs in
	    'points'     => [],		        # listref for Glyph::Poly to store x,y paired points
            ref($params_ref) eq 'HASH' ? %$params_ref : ()
    };
    bless($self, $class);
    ########## initialise all fields except type
    return $self;
}

#########
# read-write methods
#
sub AUTOLOAD {
    my ($this, $val) = @_;
    no strict 'refs';
    (my $field = $AUTOLOAD) =~ s/.*:://;
    *{$AUTOLOAD} = sub { $_[0]->{$field}=$_[1] if defined $_[1]; return $_[0]->{$field}; };
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

    my $scalex     = $$transform_ref{'scalex'} || 1;
    my $scaley     = $$transform_ref{'scaley'} || 1;
    my $translatex = $$transform_ref{'translatex'};
    my $translatey = $$transform_ref{'translatey'};

    #########
    # override transformation if we've set x/y to be absolute (pixel) coords
    #
    if(defined $this->absolutex()) {
	    $scalex = $$transform_ref{'absolutescalex'};
    }

    if(defined $this->absolutey()) {
    	$scaley = $$transform_ref{'absolutescaley'};
    }

    #########
    # copy the real coords & sizes if we don't have them already
    #
    $this->{'pixelx'}      ||= $this->{'x'};
    $this->{'pixely'}      ||= $this->{'y'};
    $this->{'pixelwidth'}  ||= $this->{'width'};
    $this->{'pixelheight'} ||= $this->{'height'};

    #########
    # apply scale
    #
    if(defined $scalex) {
    	$this->pixelx      (int($this->pixelx()      * $scalex));
    	$this->pixelwidth  (int($this->pixelwidth()  * $scalex));
    }
    if(defined $scaley) {
    	$this->pixely      (int($this->pixely()      * $scaley));
    	$this->pixelheight (int($this->pixelheight() * $scaley));
    }

    #########
    # apply translation
    #
    $this->pixelx($this->pixelx() + $translatex) if(defined $translatex);
    $this->pixely($this->pixely() + $translatey) if(defined $translatey);

  #  $this->pixelx($this->pixelx()-1);
  #  $this->pixelwidth($this->pixelwidth()+1);
	
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
