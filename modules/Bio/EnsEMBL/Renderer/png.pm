package Bio::EnsEMBL::Renderer::png;
use strict;
use lib ".";
use Bio::EnsEMBL::Renderer::gif;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Renderer::gif);

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->png();
    }
}

1;
