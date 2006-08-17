#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor
#
# Cared for by Javier Herrero <jherrero@ebi.ac.uk>
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself
#
# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor - An AlignSlice can be used to map genes from one species onto another one. This adaptor is used to fetch all the data needed for an AlignSlice from the database.

=head1 INHERITANCE

This module inherits attributes and methods from Bio::EnsEMBL::DBSQL::BaseAdaptor

=head1 SYNOPSIS
  
  use Bio::EnsEMBL::Registry;

  ## Load adaptors using the Registry
  Bio::EnsEMBL::Registry->load_all();

  ## Fetch the query slice
  my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
          "Homo sapiens", "core", "Slice");
  my $query_slice = $query_slice_adaptor->fetch_by_region(
          "chromosome", "14", 50000001, 50010001);

  ## Fetch the method_link_species_set
  my $mlss_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
          "Compara26", "compara", "MethodLinkSpeciesSet");
  my $method_link_species_set = $mlss_adaptor->fetch_by_method_link_type_registry_aliases(
          "BLASTZ_NET", ["Homo sapiens", "Rattus norvegicus"]);

  ## Fetch the align_slice
  my $align_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
          "Compara26",
          "compara",
          "AlignSlice"
      );
  my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
          $query_slice,
          $method_link_species_set,
          "expanded"
      );

=head1 OBJECT ATTRIBUTES

=over

=item db (from SUPER class)

=back

=head1 AUTHORS

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::Compara::AlignSlice;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 new (CONSTRUCTOR)

  Arg        : 
  Example    : 
  Description: Creates a new AlignSliceAdaptor object
  Returntype : Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor
  Exceptions : none
  Caller     : Bio::EnsEMBL::Registry->get_adaptor

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  return $self;
}


=head2 fetch_by_Slice_MethodLinkSpeciesSet

  Arg[1]     : Bio::EnsEMBL::Slice $query_slice
  Arg[2]     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg[3]     : [optional] boolean $expanded (def. FALSE)
  Arg[4]     : [optional] boolean $solve_overlapping (def. FALSE)
  Arg[5]     : [optional] Bio::EnsEMBL::Slice $target_slice
  Example    :
      my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
              $query_slice, $method_link_species_set);
  Description: Fetches from the database all the data needed for the AlignSlice
               corresponding to the $query_slice and the given
               $method_link_species_set. Setting $expanded to anything different
               from 0 or "" will create an AlignSlice in "expanded" mode. This means
               that gaps are allowed in the reference species in order to allocate
               insertions from other species.
               By default overlapping alignments are ignored. You can choose to
               reconciliate the alignments by means of a fake alignment setting the
               solve_overlapping option to TRUE.
               In order to restrict the AlignSlice to alignments with a given
               genomic region, you can specify a target_slice. All alignments which
               do not match this slice will be ignored.
  Returntype : Bio::EnsEMBL::Compara::AlignSlice
  Exceptions : thrown if wrong arguments are given
  Caller     : $obejct->methodname

=cut

sub fetch_by_Slice_MethodLinkSpeciesSet {
  my ($self, $reference_slice, $method_link_species_set, $expanded, $solve_overlapping, $target_slice) = @_;

  throw("[$reference_slice] is not a Bio::EnsEMBL::Slice")
      unless ($reference_slice and ref($reference_slice) and
          $reference_slice->isa("Bio::EnsEMBL::Slice"));
  throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet")
      unless ($method_link_species_set and ref($method_link_species_set) and
          $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));

  # Use cache whenever possible
  my $key = $reference_slice->name.":".$method_link_species_set->dbID.":".($expanded?"exp":"cond").
      ":".($solve_overlapping?"fake-overlap":"non-overlap");
  if (defined($target_slice)) {
    throw("[$target_slice] is not a Bio::EnsEMBL::Slice")
        unless ($target_slice and ref($target_slice) and
            $target_slice->isa("Bio::EnsEMBL::Slice"));
    $key .= ":".$target_slice->name();
  }
  return $self->{'_cache'}->{$key} if (defined($self->{'_cache'}->{$key}));

  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor;
  my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $method_link_species_set,
          $reference_slice
      );

  ## Remove all alignments not matching the target slice if any
  if (defined($target_slice)) {
    ## Get the DnaFrag for the target Slice
    my $target_dnafrag = $self->db->get_DnaFragAdaptor->fetch_by_Slice($target_slice);
    if (!$target_dnafrag) {
      throw("Cannot get a DnaFrag for the target Slice");
    }

    ## Loop through all the alignment blocks and test whether they match the target slice or not
    for (my $i = 0; $i < @$genomic_align_blocks; $i++) {
      my $this_genomic_align_block = $genomic_align_blocks->[$i];
      my $hits_the_target_slice = 0;
      foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
        if ($this_genomic_align->dnafrag->dbID == $target_dnafrag->dbID and
            $this_genomic_align->dnafrag_start <= $target_slice->end and
            $this_genomic_align->dnafrag_end >= $target_slice->start) {
          $hits_the_target_slice = 1;
          last;
        }
      }
      if (!$hits_the_target_slice) {
        splice(@$genomic_align_blocks, $i, 1);
        $i--;
      }
    }
  }

  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(
          -adaptor => $self,
          -reference_Slice => $reference_slice,
          -Genomic_Align_Blocks => $genomic_align_blocks,
          -method_link_species_set => $method_link_species_set,
          -expanded => $expanded,
          -solve_overlapping => $solve_overlapping,
      );
  $self->{'_cache'}->{$key} = $align_slice;

  return $align_slice;
}


=head2 flush_cache

  Arg[1]     : none
  Example    : $align_slice_adaptor->flush_cache()
  Description: Destroy the cache
  Returntype : none
  Exceptions : none
  Caller     : $obejct->methodname

=cut

sub flush_cache {
  my ($self) = @_;

  undef($self->{'_cache'});
}

1;
