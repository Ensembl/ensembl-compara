package Bio::EnsEMBL::Renderer;
use strict;
use Exporter;
use vars qw(@ISA);
use lib "../../../../modules";
use ColourMap;
use Bio::EnsEMBL::Glyph::Rect;

@ISA = qw(Exporter);

sub new {
    my ($class, $config, $container, $glyphsets_ref, $transform_ref) = @_;

    my $spacing = 5;

    #########
    # set up the type to be gif|wmf|ps|whatever
    # 
    my $type = $class;
    $type =~ s/.*:://;

    #########
    # calculate scaling factors and canvas dimensions
    #
    my $im_height = $spacing;
    for my $glyphset (@{$glyphsets_ref}) {
	$im_height += $glyphset->height() + $spacing;
    }

    my $im_width = $config->image_width();
    $$transform_ref{'scalex'} = $config->scalex();

    my $self = {
	'glyphsets' => $glyphsets_ref,
	'transform' => $transform_ref,
	'canvas'    => undef,
	'colourmap' => $config->colourmap(),
	'config'    => $config,
	'container' => $container,
	'type'      => undef,
	'spacing'   => $spacing,
    };

    bless($self, $class);

    #########
    # create a fresh canvas
    #
    if($self->can('init_canvas')) {
	$self->init_canvas($config, $im_width, $im_height);
    }

    $self->render();

    return $self;
}

sub render {
    my ($this) = @_;

    my ($cstart, $cend);

    $cstart = 0;
    $cend   = $this->{'container'}->length();

    #########
    # give us a top margin
    #
#    $this->{'transform'}->{'translatey'} += $this->{'transform'}->{'spacing'};

    #########
    # pull out alternating background colours for this script
    #
    my $config = $this->{'config'};
    my $white  = $config->bgcolour() || $config->colourmap->id_by_name('white');
    my $bgcolours = {
	'0' => $config->get($config->script(), '_settings', 'bgcolour1') || $white,
	'1' => $config->get($config->script(), '_settings', 'bgcolour2') || $white,
    };

    my $yoffset = $this->{'spacing'};
    my $iteration = 0;
    for my $glyphset (@{$this->{'glyphsets'}}) {

	#########
	# remove any whitespace at the top of this row
	#
	my $gminy = $glyphset->miny();

	$this->{'transform'}->{'translatey'} = -$gminy + $yoffset + ($iteration * $this->{'spacing'});

	#########
	# colour the area behind this strip
	#
	my $background = new Bio::EnsEMBL::Glyph::Rect({
	    'x'         => 0,
	    'y'         => $glyphset->miny(),
	    'width'     => $this->{'config'}->image_width(),
	    'height'    => $glyphset->maxy() - $glyphset->miny(),
	    'colour'    => $$bgcolours{$iteration % 2},
	    'absolutex' => 1,
	});

	$glyphset->unshift($background);

	for my $glyph ($glyphset->glyphs()) {

	    my $method = $this->method($glyph);
	    if($this->can($method)) {
		$this->$method($glyph);
	    } else {
		print STDERR qq(Bio::EnsEMBL::Renderer::render: Don't know how to $method\n);
	    }
	}

	#########
	# translate the top of the next row to the bottom of this one
	#
	$yoffset += $glyphset->height();
	$iteration ++;
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
