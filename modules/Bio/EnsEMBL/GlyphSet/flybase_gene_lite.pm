package Bio::EnsEMBL::GlyphSet::flybase_gene_lite;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::flybase_gene_lite::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub my_label { return 'FlyBase Genes'; }

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

sub legend_captions {
  return {
    '_KNOWN' => 'FlyBase predicted genes (known)',
    '_PRED' => 'FlyBase predicted genes (pred)',
    '_ORTHO' => 'FlyBase predicted genes (ortholog)',
    '_PSEUDO' => 'FlyBase predicted genes (known)',
    '_' => 'FlyBase predicted genes (novel)',
  }
}

1;
