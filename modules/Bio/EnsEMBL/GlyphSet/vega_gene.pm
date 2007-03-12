package Bio::EnsEMBL::GlyphSet::vega_gene;

use strict;

use Bio::EnsEMBL::GlyphSet::evega_gene;
@Bio::EnsEMBL::GlyphSet::vega_gene::ISA = qw(Bio::EnsEMBL::GlyphSet::evega_gene);

sub legend {
    my ($self, $colours) = @_;
	my %sourcenames = (
					   'otter'          => 'Havana ',
					   'otter_external' => 'External ',
					   'otter_corf'     => 'CORF ',
					   'otter_igsf'     => 'IgSF ',
                       'otter_eucomm'   => 'Knockout genes',
					  );
	my $logic_name =  $self->my_config('logic_name');
    my %X;
    foreach my $colour ( values %$colours ) {
		my $l = $sourcenames{$logic_name};
		$l .= $colour->[1];
        $X{$l} = $colour->[0];
    }
    my @legend = %X;
    return \@legend;
}

1;
