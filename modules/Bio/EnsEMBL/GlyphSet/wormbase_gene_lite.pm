package Bio::EnsEMBL::GlyphSet::wormbase_gene_lite;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::wormbase_gene_lite::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub my_label { return 'WormBase Genes'; }

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
    '_KNOWN' => 'WormBase predicted genes (known)',
    '_PRED' => 'WormBase predicted genes (pred)',
    '_ORTHO' => 'WormBase predicted genes (ortholog)',
    '_PSEUDO' => 'WormBase predicted genes (known)',
    '_' => 'WormBase predicted genes (novel)',
  }
}

1;
