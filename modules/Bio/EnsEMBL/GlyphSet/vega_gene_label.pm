package Bio::EnsEMBL::GlyphSet::vega_gene_label;

use strict;
use Bio::EnsEMBL::GlyphSet_genelabel;
@Bio::EnsEMBL::GlyphSet::vega_gene_label::ISA = qw(Bio::EnsEMBL::GlyphSet_genelabel);

sub features {
    my ($self, $logic_name, $database) = @_;
    my $db = EnsEMBL::DB::Core::get_databases('vega');
    return $db->{'vega'}->get_GeneAdaptor->fetch_all_by_Slice_and_author($self->{'container'}, $self->my_config('author'), $logic_name);
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
