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
	'supported' => [qw(Bio::EnsEMBL::Glyph::Composite Bio::EnsEMBL::Glyph::Rect Bio::EnsEMBL::Glyph::Circle Bio::EnsEMBL::Glyph::Ellipse Bio::EnsEMBL::Glyph::Intron Bio::EnsEMBL::Glyph::Text)],
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
	    $this->$method($glyph);
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

sub render_Rect {
}

sub render_Text {
}

sub render_Circle {
}

sub render_Ellipse {
}

sub render_Intron {
}

sub render_Composite {
    my ($this, $glyph) = @_;

    for my $subglyph (@{$glyph->{'composite'}}) {
	my $method = $this->method($subglyph);
	$this->$method($subglyph);
    }
}

1;
