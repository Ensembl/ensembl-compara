package Bio::EnsEMBL::Renderer::wmf;
use strict;
use lib ".";
use Bio::EnsEMBL::Renderer::gif;
use vars qw(@ISA);
use lib "../../../../../modules";
use WMF;
@ISA = qw(Bio::EnsEMBL::Renderer::gif);

sub init_canvas {
    my ($this, $config, $im_width, $im_height) = @_;
    my $canvas = new WMF($im_width, $im_height);
    $canvas->colorAllocate($config->colourmap()->rgb_by_id($config->bgcolor()));
    $this->canvas($canvas);
}

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->wmf();
    }
}

1;
