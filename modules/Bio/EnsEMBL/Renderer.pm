package Bio::EnsEMBL::Renderer;
use strict;
use Exporter;
use vars qw(@ISA);
use lib "../../../../modules";
use ColourMap;
use Bio::EnsEMBL::Glyph::Clip;

@ISA = qw(Exporter);

sub new {
    my ($class, $config, $container, $glyphsets_ref, $transform_ref, $canvas) = @_;

    my $self = {
	'glyphsets' => $glyphsets_ref,
	'transform' => $transform_ref,
	'canvas'    => $canvas,
	'colourmap' => new ColourMap,
	'config'    => $config,
	'container' => $container,
    };
    bless($self, $class);
    $self->render();

    return $self;
}

sub render {
    my ($this) = @_;
    my $previous_maxy = 0;

    my ($cstart, $cend);

#    if(ref($this->{'container'}) eq "Bio::EnsEMBL::Protein") {
#	$cstart = $this->{'container'}->start();
#	$cend   = $this->{'container'}->end();
#    } else {
#	$cstart = $this->{'container'}->_global_start() if($this->{'container'}->can('_global_start'));
#	$cend   = $this->{'container'}->_global_end()   if($this->{'container'}->can('_global_end'));
	$cstart = 0;
	$cend   = $this->{'container'}->length();
#    }

#print STDERR qq(Container global start $cstart, global end $cend\n);
    for my $glyphset (@{$this->{'glyphsets'}}) {

	#########
	# slide this row to the bottom of the previous row
	# also remove any whitespace at the top of this row
	# lastly add a teensy gap between the rows
	#
	# NB: this is rotation-sensitive!
	#
	$this->{'transform'}->{'translatey'} += $previous_maxy - $glyphset->miny() + 3;

	for my $glyph ($glyphset->glyphs()) {

	    #########
	    # check glyph edges to see if it crosses a boundary
	    # if it does, substitute it for a Clip object (flat dotted line)
	    #
	    my $gx1 = $glyph->x();
	    my $gw  = $glyph->width();
	    my $gy1 = $glyph->y();
	    my $gh  = $glyph->height();
	    my $gx2 = $gx1 + $gw;
	    my $gy2 = $gy1 + $gh;

	    if(!defined $glyph->absolutex()) {
#print STDERR qq(glyph $glyph not absolutex\n);
		if($gx2 < $cstart) {
		    #########
		    # whole glyph is waaay off to the left
		    #
#print STDERR qq(invisible glyph $glyph waay off to the left ($gx1 to $gx2)\n);
		    next;
		}
	
		if($gx1 > $cend) {
		    #########
		    # whole glyph is waaay off to the right
		    #
#print STDERR qq(invisible glyph $glyph waay off to the right ($gx1 to $gx2)\n);
		    next;
		}

		if($gx1 < $cstart && $gx2 > $cstart) {
		    #########
		    # glyph straddles left hand side boundary
		    #
		    my $clipglyph = new Bio::EnsEMBL::Glyph::Clip({
			'colour' => $glyph->colour(),
			'x'      => $cstart,
			'y'      => $glyph->y(),
			'width'  => $gx2 - $cstart,
			'height' => 1,
		    });
#print STDERR qq(partial   glyph $glyph straddles left hand boundary ($gx1, $gx2)\n);
		    $glyph = $clipglyph;

		} elsif($gx1 < $cend && $gx2 > $cend) {
		    #########
		    # glyph straddles right hand side boundary
		    #
		    my $clipglyph = new Bio::EnsEMBL::Glyph::Clip({
			'colour' => $glyph->colour(),
			'x'      => $gx1,
			'y'      => $glyph->y(),
			'width'  => $cend - $gx1,
			'height' => 1,
		    });
#print STDERR qq(partial   glyph $glyph straddles right hand boundary ($gx1, $gx2)\n);
		    $glyph = $clipglyph;
		}
	    }

	    my $method = $this->method($glyph);
	    if($this->can($method)) {
		$this->$method($glyph);
	    } else {
		print STDERR qq(Bio::EnsEMBL::Renderer::render: Don't know how to $method\n);
	    }
	}

	$previous_maxy = $glyphset->maxy();
    }
}

sub canvas {
    my ($this, $canvas) = @_;
    $this->{'canvas'} = $canvas if(defined $canvas);
    return $this->{'canvas'};
}

sub method {
    my ($this, $glyph) = @_;

    my ($suffix) = ref($glyph) =~ /.*::(.*)/;
    return qq(render_$suffix);
}

sub render_Composite {
    my ($this, $glyph) = @_;

    #########
    # we've already applied the transformation in the 'render' routine,
    # so work here is in pixel coordinates
    #
    my $xoffset = $glyph->x();
    my $yoffset = $glyph->y();
#print STDERR qq(render_Composite: offsetting children by $xoffset, $yoffset\n);

    for my $subglyph (@{$glyph->{'composite'}}) {
	my $method = $this->method($subglyph);

	if($this->can($method)) {
	    #########
	    # offset child glyphs by the composite coordinates
	    #
	    $subglyph->x($subglyph->x() + $xoffset);
	    $subglyph->y($subglyph->y() + $yoffset);

	    $this->$method($subglyph);
	} else {
	    print STDERR qq(Bio::EnsEMBL::Renderer::render_Composite: Don't know how to $method\n);
	}
    }
}

#########
# empty stub for Blank spacer objects with no rendering at all
#
sub render_Blank {
}

1;
