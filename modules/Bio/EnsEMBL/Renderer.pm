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

    my $self = {
	'glyphsets' => $glyphsets_ref,
	'transform' => $transform_ref,
	'canvas'    => undef,
	'colourmap' => $config->colourmap(),
	'config'    => $config,
	'container' => $container,
	'spacing'   => 5,
    };

    bless($self, $class);

    $self->render();

    return $self;
}

sub render {
    my ($this) = @_;

    #########
    # pull out alternating background colours for this script
    #
    my $config = $this->{'config'};
    my $white  = $config->bgcolour() || $config->colourmap->id_by_name('white');
    my $bgcolours = {
	'0' => $config->get($config->script(), '_settings', 'bgcolour1') || $white,
	'1' => $config->get($config->script(), '_settings', 'bgcolour2') || $white,
    };

    my $bgcolour_flag;
    $bgcolour_flag = 1 if($$bgcolours{0} ne $$bgcolours{1});

    my $spacing = $this->{'spacing'};

    #########
    # calculate the maximum label width (plus margin)
    #
    my $label_length_px = 0;

    for my $glyphset (@{$this->{'glyphsets'}}) {
	next if(!defined $glyphset->label());

	$glyphset->label->text($glyphset->label->text());

	my $chars  = length($glyphset->label->text());
	my $pixels = $chars * $config->texthelper->width($glyphset->label->font());
	
	$label_length_px = $pixels if($pixels > $label_length_px);
    }

    #########
    # add spacing before and after labels
    #
    $label_length_px += $spacing * 2;

    #########
    # calculate scaling factors
    #
    my $pseudo_im_width = $config->image_width() - $label_length_px - $spacing;

    #########
    # set scaling factor for base-pairs -> pixels
    #
    $this->{'transform'}->{'scalex'}         = $pseudo_im_width / $config->container_width();

    #########
    # set scaling factor for 'absolutex' coordinates -> real pixel coords
    #
    $this->{'transform'}->{'absolutescalex'} = $pseudo_im_width / $config->image_width();

    #########
    # because our text label starts are < 0, translate everything back onto the canvas
    #
    my $extra_translation = $label_length_px;
    $this->{'transform'}->{'translatex'} += $extra_translation;

    #########
    # now set all our labels up with scaled negative coords
    # and while we're looping, tot up the image height
    #
    my $im_height = 0;

    for my $glyphset (@{$this->{'glyphsets'}}) {
	
	my $fntheight = (defined $glyphset->label())?$config->texthelper->height($glyphset->label->font()):0;
	my $gstheight = $glyphset->height();

	if($gstheight > $fntheight) {
	    $im_height += $gstheight + $spacing;
	} else {
	    $im_height += $fntheight + $spacing;
	}

	next if(!defined $glyphset->label());
	$glyphset->label->x(-($extra_translation - $spacing) / $this->{'transform'}->{'scalex'});
    }

    my $im_width = $config->image_width();

    #########
    # create a fresh canvas
    #
    if($this->can('init_canvas')) {
	$this->init_canvas($config, $im_width, $im_height);
    }

    my $yoffset = $spacing;
    my $iteration = 0;
    for my $glyphset (@{$this->{'glyphsets'}}) {

	#########
	# remove any whitespace at the top of this row
	#
	my $gminy = $glyphset->miny();

	$this->{'transform'}->{'translatey'} = -$gminy + $yoffset + ($iteration * $spacing);

	if(defined $bgcolour_flag) {
	    #########
	    # colour the area behind this strip
	    #
	    my $background = new Bio::EnsEMBL::Glyph::Rect({
		'x'         => 0,
		'y'         => $gminy,
		'width'     => $this->{'config'}->image_width(),
		'height'    => $glyphset->maxy() - $gminy,
		'colour'    => $$bgcolours{$iteration % 2},
		'absolutex' => 1,
	    });
	    $glyphset->unshift($background);
	}

	#########
	# set up the label for this strip
	#
	if(defined $glyphset->label()) {
	    my $gh = $config->texthelper->height($glyphset->label->font());
	    $glyphset->label->y((($glyphset->maxy() - $glyphset->miny() - $gh) / 2) + $glyphset->miny());
	    $glyphset->label->height($gh);
	    $glyphset->push($glyphset->label());
	}

	#########
	# loop through everything and draw it
	#
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
