package Bio::EnsEMBL::Renderer;
use strict;
use Exporter;
use vars qw(@ISA);
use lib "../../../../modules";
use ColourMap;
use Bio::EnsEMBL::Glyph::Clip;
use WMF;
use GD;

@ISA = qw(Exporter);

sub new {
    my ($class, $config, $container, $glyphsets_ref, $transform_ref) = @_;

    #########
    # set up the type to be gif|wmf|ps|whatever
    # 
    my $type = $class;
    $type =~ s/.*:://;

    #########
    # calculate scaling factors and canvas dimensions
    #
    my $im_height = 2;
    for my $glyphset (@{$glyphsets_ref}) {
	$glyphset->maxy($glyphset->maxy()+2);
	$im_height += ($glyphset->maxy() - $glyphset->miny());
    }

    my $im_width = $config->image_width();
    %{$transform_ref}->{'scalex'} = $config->scalex();
    %{$transform_ref}->{'translatey'} += 2;

    #########
    # create a fresh canvas
    #
    my $canvas;
    if($type eq "gif") {
	$canvas = new GD::Image($im_width, $im_height);
	$canvas->colorAllocate($config->colourmap()->rgb_by_id($config->bgcolor()));

    } elsif($type eq "wmf") {
	$canvas = new WMF($im_width, $im_height);
	$canvas->colorAllocate($config->colourmap()->rgb_by_id($config->bgcolor()));
    }

    my $self = {
	'glyphsets' => $glyphsets_ref,
	'transform' => $transform_ref,
	'canvas'    => $canvas,
	'colourmap' => $config->colourmap(),
	'config'    => $config,
	'container' => $container,
	'type'      => undef,
    };
    bless($self, $class);

    $self->render();

    return $self;
}

sub render {
    my ($this) = @_;
    my $previous_maxy = 0;

    my ($cstart, $cend);

    $cstart = 0;
    $cend   = $this->{'container'}->length();

    for my $glyphset (@{$this->{'glyphsets'}}) {

	#########
	# slide this row to the bottom of the previous row
	# also remove any whitespace at the top of this row
	# lastly add a teensy gap between the rows
	#
	# NB: this is rotation-sensitive!
	#
	$this->{'transform'}->{'translatey'} += $previous_maxy - $glyphset->miny();

	for my $glyph ($glyphset->glyphs()) {

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
