package Sanger::Graphics::Renderer::png;
use strict;
use Sanger::Graphics::Renderer::gif;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::Renderer::gif);

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->png();
    }
}

1;
