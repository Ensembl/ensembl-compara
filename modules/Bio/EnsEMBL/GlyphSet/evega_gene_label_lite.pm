package Bio::EnsEMBL::GlyphSet::evega_gene_label_lite;

use strict;
use Bio::EnsEMBL::GlyphSet;
@Bio::EnsEMBL::GlyphSet::evega_gene_label_lite::ISA = qw(Bio::EnsEMBL::GlyphSet_genelabel);

sub ens_ID {
  my( $self, $g ) = @_;
  return '';
}

sub gene_label {
  my( $self, $g ) = @_;
  return $g->external_name || $g->stable_id();
}

sub gene_col {
  my( $self, $g ) = @_;
  ( my $type =  $g->type() ) =~ s/HUMACE-//;
  return $type;
}

1;
