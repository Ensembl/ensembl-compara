package Bio::EnsEMBL::GlyphSet::vega_gene;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::vega_gene::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub features {
    my ($self, $logic_name, $database) = @_;
    my $db = EnsEMBL::DB::Core::get_databases('vega');
    return $db->{'vega'}->get_GeneAdaptor->fetch_all_by_Slice_and_author($self->{'container'}, $self->my_config('author'), $logic_name);
}

sub my_label {
    my $self = shift;
    return $self->my_config('label');
}

sub legend_captions {
  return {
     'Known'                 => 'Known gene',
     'Novel_CDS'             => 'Novel CDS',
     'Putative'              => 'Putative',
     'Novel_Transcript'      => 'Novel transcript',
     'Pseudogene'            => 'Pseudogene',
     'Processed_pseudogene'  => 'Processed pseudogene',
     'Unprocessed_pseudogene'=> 'Unprocessed pseudogene',
     'Predicted_Gene'        => 'Predicted gene',
     'Ig_Segment'            => 'Immunoglobulin segment',
     'Ig_Pseudogene_Segment' => 'Immunoglobulin pseudogene',
     'Transposon'	    => 'Transposon',
     'Polymorphic'           => 'Polymorphic',
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
