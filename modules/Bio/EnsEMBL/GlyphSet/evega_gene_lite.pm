package Bio::EnsEMBL::GlyphSet::evega_gene_lite;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::evega_gene_lite::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub my_label { return 'Vega Genes'; }

sub legend_captions {
  return {
     'Novel_CDS'               => 'Curated novel CDS',
     'Putative'                => 'Curated putative',
     'Known'                   => 'Curated known genes',
     'Novel_Transcript'        => 'Curated novel Trans',
     'Pseudogene'              => 'Curated pseudogenes',
     'Processed_pseudogene'    => 'Curated processed pseudogenes',
     'Unprocessed_pseudogene'  => 'Curated unprocessed pseudogenes',
     'Ig_Segment'              => 'Curated Ig Segment',
     'Ig_Pseudogene_Segment'   => 'Curated Ig Pseudogene',
     'Predicted_Gene'          => 'Curated predicted',
     'Transposon'              => 'Curated Transposon',
     'Polymorphic'             => 'Curated Polymorphic',
  };
}

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
