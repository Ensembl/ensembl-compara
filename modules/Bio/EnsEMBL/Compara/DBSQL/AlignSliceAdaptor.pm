package Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::Compara::AlignSlice;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  return $self;
}


sub fetch_by_Slice_MethodLinkSpeciesSet {
  my ($self, $reference_slice, $method_link_species_set) = @_;

  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor;
  my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $method_link_species_set,
          $reference_slice
      );

  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(
          -adaptor => $self,
          -reference_Slice => $reference_slice,
          -Genomic_Align_Blocks => $genomic_align_blocks,
      );

  return $align_slice;
}

1;
