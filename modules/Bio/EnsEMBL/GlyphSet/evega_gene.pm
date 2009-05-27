package Bio::EnsEMBL::GlyphSet::evega_gene;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_gene);

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
  my $type = $g->biotype;
  return $type;
}


=head2 format_vega_name

  Arg [1]    : $self
  Arg [2]    : gene object
  Example    : my $type = $self->format_vega_name($g,$t);
  Description: retrieves status and biotype of a gene and then gets the display name from the Colourmap
  Returntype : string

=cut

sub format_vega_name {
	my ($self,$gene) = @_;
	my %gm = $self->{'config'}->colourmap()->colourSet($self->my_config('colour_set'));
	my $biotype = $gene->biotype();
	my $label = $gm{$biotype}[1];
	return $label;
}


1;
