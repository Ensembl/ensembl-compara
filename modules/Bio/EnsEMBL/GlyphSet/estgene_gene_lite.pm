package Bio::EnsEMBL::GlyphSet::estgene_gene_lite;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::estgene_gene_lite::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub my_label { return 'EST genes'; }

sub legend_captions {
  return {
    'estgene' => 'EST genes'
  };
}

sub ens_ID {
  my( $self, $g ) = @_;
  return '';
}

sub gene_label {
  my( $self, $g ) = @_;
  return $g->stable_id;
}

sub gene_col {
  my( $self, $g ) = @_;
  return 'estgene';
}

1;
