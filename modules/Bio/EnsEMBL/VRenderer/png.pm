package Bio::EnsEMBL::VRenderer::png;
use strict;
use Bio::EnsEMBL::VRenderer::gif;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::VRenderer::gif);

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->png();
    }
}

1;
