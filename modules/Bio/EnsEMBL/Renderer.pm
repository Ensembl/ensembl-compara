package Bio::EnsEMBL::Renderer;
use strict;
use Exporter;
use vars qw(@ISA);
use lib "../../../../modules";
use ColourMap;
@ISA = qw(Exporter);

sub new {
    my ($class, $glyphsets_ref, $transform_ref, $canvas) = @_;

    my $self = {
	'glyphsets' => $glyphsets_ref,
	'transform' => $transform_ref,
	'canvas'    => $canvas,
	'colourmap' => new ColourMap,
	'supported' => [qw(Bio::EnsEMBL::Glyph::Composite Bio::EnsEMBL::Glyph::Rect Bio::EnsEMBL::Glyph::Circle Bio::EnsEMBL::Glyph::Ellipse Bio::EnsEMBL::Glyph::Intron Bio::EnsEMBL::Glyph::Text Bio::EnsEMBL::Glyph::Poly)],
    };
    bless($self, $class);
    $self->render();

    return $self;
}

sub render {
    my ($this) = @_;
    for my $glyphset (@{$this->{'glyphsets'}}) {
	for my $glyph ($glyphset->glyphs()) {
	    my $method = $this->method($glyph);
	    if($this->can($method)) {
		$this->$method($glyph);
	    } else {
		print STDERR qq(Bio::EnsEMBL::Renderer::render: Don't know how to $method\n);
	    }
	}
    }
}

sub canvas {
    my ($this, $canvas) = @_;
    $this->{'canvas'} = $canvas if(defined $canvas);
    return $this->{'canvas'};
}

sub method {
    my ($this, $glyph) = @_;

    for my $supported (@{$this->{'supported'}}) {
	if($glyph->isa($supported)) {
	    my ($suffix) = $supported =~ /.*::(.*)/;
	    return qq(render_$suffix);
	}
    }
}

sub render_Composite {
    my ($this, $glyph) = @_;

    for my $subglyph (@{$glyph->{'composite'}}) {
	my $method = $this->method($subglyph);
	if($this->can($method)) {
	    $this->$method($subglyph);
	} else {
	    print STDERR qq(Bio::EnsEMBL::Renderer::render_Composite: Don't know how to $method\n);
	}
    }
}

1;
