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


  throw("[$reference_slice] is not a Bio::EnsEMBL::Slice")
      unless ($reference_slice and ref($reference_slice) and
          $reference_slice->isa("Bio::EnsEMBL::Slice"));
  throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet")
      unless ($method_link_species_set and ref($method_link_species_set) and
          $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  # Use cache whenever possible
  my $key = $reference_slice->name.":".$method_link_species_set->dbID;
  return $self->{'_cache'}->{$key} if (defined($self->{'_cache'}->{$key}));

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
  $self->{'_cache'}->{$key} = $align_slice;

  return $align_slice;
}

1;
