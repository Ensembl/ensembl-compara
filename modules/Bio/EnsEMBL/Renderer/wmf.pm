package Bio::EnsEMBL::Renderer::wmf;
use strict;
use lib ".";
use Bio::EnsEMBL::Renderer::gif;
use vars qw(@ISA);
use lib "../../../../../modules";
use WMF;
@ISA = qw(Bio::EnsEMBL::Renderer::gif);

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->wmf();
    }
}

1;
