package Bio::EnsEMBL::GlyphSet::ensembl_gene_label_lite;

use strict;
use Bio::EnsEMBL::GlyphSet_genelabel;
@Bio::EnsEMBL::GlyphSet::ensembl_gene_label_lite::ISA = qw(Bio::EnsEMBL::GlyphSet_genelabel);

sub ens_ID {
  my( $self, $g ) = @_;
  return $g->stable_id;
}

sub gene_label {
  my( $self, $g ) = @_;
  return $g->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $g->type eq 'pseudogene' ? 'Pseudogene' : ( $g->external_name || 'NOVEL' ) );
}

sub gene_col {
  my( $self, $g ) = @_;
  return $g->type eq 'bacterial_contaminant' ? '_BACCOM' : ( $g->type eq 'pseudogene' ? '_PSEUDO' : '_'.$g->external_status );
}


1;
