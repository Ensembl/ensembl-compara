package Bio::EnsEMBL::GlyphSet::vega_gene;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::vega_gene::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub my_label {
    my $self = shift;
    return $self->my_config('label');
}

sub legend {
    my ($self, $colours) = @_;
    my %X;
    foreach my $colour ( values %$colours ) {
        $colour->[1] =~ s/Curated (.*)/$1/;
        $X{ucfirst($colour->[1])} = $colour->[0];
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
  $type =~ s/HUMACE-//;
  return $type;
}

1;
