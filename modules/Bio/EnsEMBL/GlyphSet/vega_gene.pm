package Bio::EnsEMBL::GlyphSet::vega_gene;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::vega_gene::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub features {
    my ($self, $logic_name, $database) = @_;

    # check data availability
    my $chr = $self->{'container'}->seq_region_name;
    my $avail = (split(/ /, $self->my_config('available')))[1]
                . "." . $self->{'container'}->seq_region_name;
    return ([]) unless(EnsWeb::species_defs->get_config(
                EnsWeb::species_defs->name, 'DB_FEATURES')->{uc($avail)});
    
    my $db = $self->{'container'}->adaptor->db->get_db_adaptor('vega');
    return $db->get_GeneAdaptor->fetch_all_by_Slice_and_author($self->{'container'}, $self->my_config('author'), $logic_name);
}

sub my_label {
    my $self = shift;
    return $self->my_config('label');
}

sub legend_captions {
  return {
     'Known'                 => 'Known gene',
     'Known_in_progress'     => 'Known gene (in progress)',
     'Novel_CDS'             => 'Novel CDS',
     'Novel_CDS_in_progress' => 'Novel CDS (in progress)',
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
