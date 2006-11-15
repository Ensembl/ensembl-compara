package Bio::EnsEMBL::GlyphSet::evega_gene;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::evega_gene::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub my_label {
    my $self = shift;
    return $self->my_config('label');
}

sub legend {
    my ($self, $colours) = @_;
	my %sourcenames = (
					   'otter' => 'Vega Havana ',
					   'otter_external' => 'Vega External ',
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

sub ens_ID {
  my( $self, $g ) = @_;
  return $g->stable_id();
}

sub gene_label {
  my( $self, $g ) = @_;
  return $g->external_name || $g->stable_id();
}

sub gene_col {
  my( $self, $g ) = @_;
  my $type = $g->biotype.'_'.$g->status;
  return $type;
}

1;
