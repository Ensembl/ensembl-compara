package Bio::EnsEMBL::GlyphSet::ensembl_gene_lite;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::ensembl_gene_lite::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub my_label { return 'Ensembl Genes'; }

sub legend_captions {
  return {
    '_KNOWN' => 'Ensembl predicted genes (known)',
    '_PRED' => 'Ensembl predicted genes (pred)',
    '_ORTHO' => 'Ensembl predicted genes (ortholog)',
    '_PSEUDO' => 'Ensembl predicted genes (known)',
    '_' => 'Ensembl predicted genes (novel)',
  }
}

sub ens_ID {
  my( $self, $g ) = @_;
  return $g->stable_id;
}

sub gene_label {
  my( $self, $g ) = @_;
  return $g->external_name || 'NOVEL';
}

sub gene_col {
  my( $self, $g ) = @_;
  return '_'.$g->external_status;
}


1;
