#
# Ensembl module for Bio::EnsEMBL::Compara::AlignSlice
#
# Cared for by Javier Herrero <jherrero@ebi.ac.uk>
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself
#
# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::AlignSlice - Container of Bio::EnsEMBL::Compara::GenomicAlignBlock objects
corresponding to a given Bio::EnsEMBL::Slice object

=head1 SYNOPSIS
  
  use Bio::EnsEMBL::Compara::AlignSlice;
  
  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(
          -adaptor => $align_slice_adaptor,
          -reference_Slice => $reference_Slice,
          -genomicAlignBlocks => $all_genomicAlignBlocks,
      );

SET VALUES
  $align_slice->adaptor($align_slice_adaptor);
  $align_slice->reference_Slice($reference_slice);
  $align_slice->add_GenomicAlignBlock($genomic_align_block_1);
  $align_slice->add_GenomicAlignBlock($genomic_align_block_2);
  $align_slice->add_GenomicAlignBlock($genomic_align_block_3);

GET VALUES
  my $align_slice_adaptor = $align_slice->adaptor();
  my $reference_slice = $align_slice->reference_Slice();
  my $all_genomic_align_blocks = $align_slice->get_all_GenomicAlignBlock();

=head1 OBJECT ATTRIBUTES

=over

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor object to access DB

=item reference_slice

Bio::EnsEMBL::Slice object used to create this Bio::EnsEBML::Compara::AlignSlice object

=item all_GenomicAlignBlocks

a listref of Bio::EnsEMBL::Compara::GenomicAlignBlock objects found using the reference_Slice

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


package Bio::EnsEMBL::Compara::AlignSlice;

use strict;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::Compara::AlignSlice::Transcript;
use Bio::EnsEMBL::Compara::AlignSlice::Exon;

=head2 new (CONSTRUCTOR)

  Arg[1]     : a reference to a hash where keys can be:
                 -adaptor
                 -reference_slice
                 -genomic_align_blocks
  Example    : my $align_slice =
                   new Bio::EnsEMBL::Compara::AlignSlice(
                       -adaptor => $align_slice_adaptor,
                       -reference_slice => $reference_slice,
                       -genomic_align_blocks => [$gab1, $gab2],
                   );
  Description: Creates a new Bio::EnsEMBL::Compara::AlignSlice object
  Returntype : Bio::EnsEMBL::Compara::AlignSlice object
  Exceptions : none
  Caller     : general

=cut

sub new {
  my ($class, @args) = @_;

  my $self = {};
  bless $self,$class;

  my ($adaptor, $reference_slice, $genomic_align_blocks) =
      rearrange([qw(
          ADAPTOR REFERENCE_SLICE GENOMIC_ALIGN_BLOCKS
      )], @args);

  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->reference_Slice($reference_slice) if (defined ($reference_slice));
  if (defined($genomic_align_blocks)) {  
    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
      $self->add_GenomicAlignBlock($this_genomic_align_block);
    }
  }

  return $self;
}


=head2 adaptor

  Arg[1]     : (optional) Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor $align_slice_adaptor
  Example    : my $align_slice_adaptor = $align_slice->adaptor
  Example    : $align_slice->adaptor($align_slice_adaptor)
  Description: getter/setter for the adaptor attribute
  Returntype : Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor object
  Exceptions : throw if arg is not a Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor
  Caller     : $object->methodname

=cut

sub adaptor {
  my ($self, $adaptor) = @_;

  if (defined($adaptor)) {
    throw "[$adaptor] must be a Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor object"
        unless ($adaptor and $adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor"));
    $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}


=head2 reference_Slice

  Arg[1]     : (optional) Bio::EnsEMBL::Slice $slice
  Example    : my $reference_slice = $align_slice->reference_slice
  Example    : $align_slice->reference_Slice($reference_slice)
  Description: getter/setter for the attribute reference_slice
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : throw if arg is not a Bio::EnsEMBL::Slice object
  Caller     : $object->methodname

=cut

sub reference_Slice {
  my ($self, $reference_slice) = @_;

  if (defined($reference_slice)) {
    throw "[$reference_slice] must be a Bio::EnsEMBL::Slice object"
        unless ($reference_slice and $reference_slice->isa("Bio::EnsEMBL::Slice"));
    $self->{'reference_slice'} = $reference_slice;
  }

  return $self->{'reference_slice'};
}


=head2 add_GenomicAlignBlock

  Arg[1]     : Bio::EnsEMBL::Compara::GenomicAlignBlock $genomicAlignBlock
  Example    : $align_slice->add_GenomicAlignBlock($genomicAlignBlock)
  Description: add a Bio::EnsEMBL::Compara::GenomicAlignBlock object to the array
               stored in the attribute all_genomic_align_blocks
  Returntype : none
  Exceptions : throw if arg is not a Bio::EnsEMBL::Compara::GenomicAlignBlock
  Caller     : $object->methodname

=cut

sub add_GenomicAlignBlock {
  my ($self, $genomic_align_block) = @_;

  if (!defined($genomic_align_block)) {
    throw "Too few arguments for Bio::EnsEMBL::Compara::AlignSlice->add_GenomicAlignBlock()";
  }
  if (!$genomic_align_block or !$genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
    throw "[$genomic_align_block] must be a Bio::EnsEMBL::Compara::GenomicAlignBlock object";
  }

  push(@{$self->{'all_genomic_align_blocks'}}, $genomic_align_block);
}


=head2 get_all_GenomicAlignBlocks

  Arg[1]     : none
  Example    : my $all_GenomicAlignBlocks = $align_slice->get_all_GenomicAlignBlocks
  Description: getter for the attribute all_genomic_align_blocks
  Returntype : listref of Bio::EnsEMBL::Compara::GenomicAlignBlock objects
  Exceptions : none
  Caller     : $object->methodname

=cut

sub get_all_GenomicAlignBlocks {
  my ($self) = @_;

  return $self->{'all_genomic_align_blocks'};
}


=head2 get_all_Genes_by_genome_db_id

  Arg[1]     : integer $genome_db_id
  Example    : my $mouse_genes = $align_slice->get_all_Genes_by_genome_db_id($mouse_genome_db->dbID)
  Description: get all the Bio::EnsEMBL::Gene objects corresponding to the
               Bio::EnsEMBL::Compara::GenomeDB object defined by the genome_db_id
               which are associated with this Bio::EnsEMBL::Compara::AlignSlice object.
               Those genes contain Bio::EnsEMBL::Transcripts which contain
               Bio::EnsEMBL::Compara::AlignSlice::Exon objects. This is done by filling in
               cache information at the beginning. Not all the methods of
               Bio::EnsEMBL::Gene and Bio::EnsEMBL::Transcript are guarantee to work as
               expected. For instance, if you flush Exons from Transcripts, it won't be possible
               to get the aligned exons anymore and the API will try to fetch the original ones
               from the database. The method Bio::EnsEMBL::Transcript::get_all_Introns (at the
               time of writting) returns a list of Introns build with the pieces of sequence
               which do not belong to an Exon. You may find several Intron fused during the
               mapping as some Exons could not be mapped.
  Returntype : listref of Bio::EnsEMBL::Gene objects. It is possible to get several
               times the same gene if it overlaps several
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
  Exceptions : none
  Caller     : $object->methodname

=cut

sub get_all_Genes_by_genome_db_id {
  my ($self, $genome_db_id) = @_;

  if (!defined($self->{'all_genes_from_'.$genome_db_id})) {
    my $all_genes;
  
    my $this_slice_adaptor;
    foreach my $this_genomic_align_block (@{$self->{'all_genomic_align_blocks'}}) {
# print STDERR "GenomicAlignBlock: $this_genomic_align_block->{dbID}\n";
      my $all_genomic_aligns = $this_genomic_align_block->genomic_align_array;
      foreach my $this_genomic_align (@$all_genomic_aligns) {
        my $this_genome_db = $this_genomic_align->dnafrag->genome_db;
# print STDERR "GenomicAlign: ($this_genome_db->{dbID}:$this_genomic_align->{dnafrag}->{name}) [$this_genomic_align->{dnafrag_start} - $this_genomic_align->{dnafrag_end}]\n";
        next if ($this_genome_db->dbID != $genome_db_id);
        $this_slice_adaptor = $this_genome_db->db_adaptor->get_SliceAdaptor if (!$this_slice_adaptor);
        my $this_slice = $this_slice_adaptor->fetch_by_region(
                $this_genomic_align->dnafrag->coord_system_name,
                $this_genomic_align->dnafrag->name,
                $this_genomic_align->dnafrag_start,
                $this_genomic_align->dnafrag_end
            );
        my $these_genes = $this_slice->get_all_Genes;
        foreach my $this_gene (@$these_genes) {
#   print STDERR "\n1.GENE ($this_gene->{stable_id}) $this_gene\n";
          ## Keep track of the corresponding genomic_alig
          $this_gene->{'genomic_align'} = $this_genomic_align;
          ## Keep track of the corresponding genome_db_id
          $this_gene->{'genome_db_id'} = $this_genome_db->dbID;
          my $mapped_gene = $self->get_mapped_Gene($this_gene);
          $mapped_gene = $self->get_mapped_Gene($this_gene);
          if (@{$mapped_gene->get_all_Transcripts}) {
            push(@$all_genes, $mapped_gene);
          }
#           $self->_set_all_overlapping_Transcripts_and_Exons_for_a_Gene($this_gene);
#           $self->_set_all_overlapping_Transcripts_and_Exons_for_a_Gene($this_gene);
#           if (@{$this_gene->get_all_Transcripts}) {
#             push(@$all_genes, $this_gene);
#           }
        }
      }
    }
  
    $self->{'all_genes_from_'.$genome_db_id} = $all_genes;
  }

  return $self->{'all_genes_from_'.$genome_db_id};
}


sub get_mapped_Gene {
  my ($self, $gene) = @_;

  ## Create an exact copy of the original gene object
  my $mapped_gene = $gene->new();
  while (my ($key, $value) = each %$gene) {
    $mapped_gene->{$key} = $value;
#     print STDERR "$gene -> {$key} = $gene->{$key}\n" if (defined($value));
#     print STDERR "$mapped_gene -> {$key} = $value\n" if (defined($value));
  }

  my $slice_length = $mapped_gene->slice->end - $mapped_gene->slice->start + 1;

  my $these_transcripts = [];
#   print STDERR "\n1.GENE: ", $mapped_gene->stable_id, " (", $mapped_gene->start, "-", $mapped_gene->end, ")\n";
#   foreach my $this_transcript (@{$mapped_gene->get_all_Transcripts}) {
#     print STDERR " + 1.TRANSCRIPT: ", $this_transcript->stable_id, " (", $this_transcript->start, "-", $this_transcript->end, ") [", $this_transcript->strand, "]\n";
#     foreach my $this_exon (@{$this_transcript->get_all_Exons}) {
#       print STDERR "   + 1.EXON: ", $this_exon->stable_id, " (", $this_exon->start, "-", $this_exon->end, ") [", $this_exon->strand, "]\n";
#     }
#   }
  foreach my $this_transcript (@{$mapped_gene->get_all_Transcripts}) {
    my $these_exons = [];
    foreach my $this_exon (@{$this_transcript->get_all_Exons}) {
      if ($this_exon->start < $slice_length and $this_exon->end > 0) {
        my $this_align_exon = new Bio::EnsEMBL::Compara::AlignSlice::Exon(
                -EXON => $this_exon,
                -ALIGN_SLICE => $self->reference_Slice,
                -FROM_MAPPER => $mapped_gene->{'genomic_align'}->get_Mapper,
                -TO_MAPPER => $mapped_gene->{'genomic_align'}->genomic_align_block->reference_genomic_align->get_Mapper,
#                 -GENOMIC_ALIGN => $mapped_gene->{'genomic_align'},
            );
        push(@{$these_exons}, $this_align_exon);
      } else {
        info("Exon ".$this_exon->stable_id." cannot be mapped using".
            " Bio::EnsEMBL::Compara::GenomicAlign #".$mapped_gene->{'genomic_align'}->dbID);
      }
    }
    if (@$these_exons) {
      my $new_transcript = $this_transcript->new(
              -stable_id => $this_transcript->stable_id,
              -exons => $these_exons,
          );
      push(@{$these_transcripts}, $new_transcript);
    } else {
      info("No exon of transcript ".$this_transcript->stable_id." can be mapped using".
          " Bio::EnsEMBL::Compara::GenomicAlign #".$gene->{'genomic_align'}->dbID);
    }
  }
  if (!@$these_transcripts) {
    info("No transcript of gene ".$mapped_gene->stable_id." can be mapped using".
        " Bio::EnsEMBL::Compara::GenomicAlign #".$mapped_gene->{'genomic_align'}->dbID);
  }
  $mapped_gene->{'_transcript_array'} = $these_transcripts;
  $mapped_gene->recalculate_coordinates();

  return $mapped_gene;
}


sub get_GenomicAlign_by_dbID {
  my ($self, $genomic_align_id) = @_;

  my $all_genomic_align_blocks = $self->get_all_GenomicAlignBlocks();
  foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
    my $these_genomic_aligns = $this_genomic_align_block->genomic_align_array();
    foreach my $this_genomic_align (@$these_genomic_aligns) {
      if ($this_genomic_align->dbID == $genomic_align_id) {
        return $this_genomic_align;
      }
    }
  }

  return undef;
}








#####################################################################
##
## OLD METHODS USED DURING DEVELOPMENT PROCESS (TO BE ERASED)
##


=head2 get_all_Genes

  Arg[1]     : none
  Example    : my $all_genes = $align_slice->get_all_Genes
  Description: get all the Bio::EnsEMBL::Gene objects associated with this
               Bio::EnsEMBL::Compara::AlignSlice object.
  Returntype : listref of Bio::EnsEMBL::Gene objects. It is possible to get several
               times the same gene if it overlaps several
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
  Exceptions : none
  Caller     : $object->methodname

=cut

sub get_all_Genes {
  my ($self, $genome_db) = @_;

  if (!defined($self->{'all_genes'})) {
    my $all_genes;

    foreach my $this_genomic_align_block (@{$self->{'all_genomic_align_blocks'}}) {
      my $all_genomic_aligns = $this_genomic_align_block->genomic_align_array;
      foreach my $this_genomic_align (@$all_genomic_aligns) {
        my $this_genome_db = $this_genomic_align->dnafrag->genome_db;
        my $this_slice_adaptor = $this_genome_db->db_adaptor->get_SliceAdaptor;
        my $this_slice = $this_slice_adaptor->fetch_by_region(
                $this_genomic_align->dnafrag->coord_system_name,
                $this_genomic_align->dnafrag->name,
                $this_genomic_align->dnafrag_start,
                $this_genomic_align->dnafrag_end
            );
        my $these_genes = $this_slice->get_all_Genes;
        foreach my $this_gene (@$these_genes) {
          ## Keep track of the corresponding genomic_align
          $this_gene->{'genomic_align'} = $this_genomic_align;
          ## Keep track of the corresponding genome_db_id
          $this_gene->{'genome_db_id'} = $this_genome_db->dbID;
          push(@{$self->{'all_genes'}}, $this_gene);
        }
      }
    }
  }

  if (defined($genome_db)) {
    my $genome_db_id = $genome_db->dbID;
    my $these_genes;
    foreach my $this_gene (@{$self->{'all_genes'}}) {
      push(@$these_genes, $this_gene) if ($this_gene->{'genome_db_id'} == $genome_db_id);
    }
    return $these_genes;
  }

  return $self->{'all_genes'};
}


sub _set_all_overlapping_Transcripts_and_Exons_for_a_Gene {
  my ($self, $gene) = @_;

  my $slice_length = $gene->slice->end - $gene->slice->start + 1;

  my $these_transcripts = [];
  
  print STDERR "\n1.GENE: ", $gene->stable_id, " (", $gene->start, "-", $gene->end, ")\n";
  foreach my $this_transcript (@{$gene->get_all_Transcripts}) {
#     print STDERR " + 1.TRANSCRIPT ($this_transcript->{stable_id}) $this_transcript\n";
    print STDERR " + 1.TRANSCRIPT: ", $this_transcript->stable_id, " (", $this_transcript->start, "-", $this_transcript->end, ") [", $this_transcript->strand, "]\n";
    foreach my $this_exon (@{$this_transcript->get_all_Exons}) {
#       print STDERR "   + 1.EXON ($this_exon->{stable_id}) $this_exon\n";
        print STDERR "   + 1.EXON: ", $this_exon->stable_id, " (", $this_exon->start, "-", $this_exon->end, ") [", $this_exon->strand, "]\n";
    }
  }
  foreach my $this_transcript (@{$gene->get_all_Transcripts}) {
    my $these_exons = [];
    foreach my $this_exon (@{$this_transcript->get_all_Exons}) {
      if ($this_exon->start < $slice_length and $this_exon->end > 0) {
        my $this_align_exon = new Bio::EnsEMBL::Compara::AlignSlice::Exon(
                -EXON => $this_exon,
                -ALIGN_SLICE => $self->reference_Slice,
                -FROM_MAPPER => $gene->{'genomic_align'}->get_Mapper,
                -TO_MAPPER => $gene->{'genomic_align'}->genomic_align_block->reference_genomic_align->get_Mapper,
#                 -GENOMIC_ALIGN => $gene->{'genomic_align'},
            );
        push(@{$these_exons}, $this_align_exon);
      } else {
        info("Exon ".$this_exon->stable_id." cannot be mapped using".
            " Bio::EnsEMBL::Compara::GenomicAlign #".$gene->{'genomic_align'}->dbID);
      }
    }
    if (@$these_exons) {
      my $new_transcript = $this_transcript->new(-exons => $these_exons);
      push(@{$these_transcripts}, $new_transcript);
    } else {
      info("No exon of transcript ".$this_transcript->stable_id." can be mapped using".
          " Bio::EnsEMBL::Compara::GenomicAlign #".$gene->{'genomic_align'}->dbID);
    }
  }
  if (!@$these_transcripts) {
    info("No transcript of gene ".$gene->stable_id." can be mapped using".
        " Bio::EnsEMBL::Compara::GenomicAlign #".$gene->{'genomic_align'}->dbID);
  }
  $gene->{'_transcript_array'} = $these_transcripts;
  $gene->recalculate_coordinates();
}



=head2 get_all_Transcripts

  Arg[1]     : none
  Example    : my $all_Transcripts = $align_slice->get_all_Transcripts
  Description: get all the Bio::EnsEMBL::Transcript objects associated with this
               Bio::EnsEMBL::Compara::AlignSlice object.
  Returntype : listref of Bio::EnsEMBL::Transcipts objects
  Exceptions : none
  Caller     : $object->methodname

=cut

sub get_all_Transcripts {
  my ($self, $genome_db) = @_;

  if (!defined($self->{'all_transcripts'})) {
    $self->_set_all_overlapping_Transcripts_and_Exons;
  }

  if (defined($genome_db)) {
    my $genome_db_id = $genome_db->dbID;
    my $these_transcripts;
    foreach my $this_transcript (@{$self->{'all_transcripts'}}) {
      push(@$these_transcripts, $this_transcript)
          if ($this_transcript->{'genome_db_id'} == $genome_db_id);
    }
    return $these_transcripts;
  }

  return $self->{'all_transcripts'};
}


=head2 get_all_Exons

  Arg[1]     : none
  Example    : my $all_Exons = $align_slice->get_all_Exons
  Description: get all the Bio::EnsEMBL::Exon objects associated with this
               Bio::EnsEMBL::Compara::AlignSlice object.
  Returntype : listref of Bio::EnsEMBL::Exon objects
  Exceptions : none
  Caller     : $object->methodname

=cut

sub get_all_Exons {
  my ($self, $genome_db) = @_;

  if (!defined($self->{'all_exons'})) {
    $self->_set_all_overlapping_Transcripts_and_Exons;
  }

  foreach my $this_exon (@{$self->{'all_exons'}}) {
#     print STDERR "\n\n",
#         "   ", $this_exon->{'genomic_align'}->dnafrag_start,"   ", $this_exon->{'genomic_align'}->dnafrag_end, "\n",
#         "   ", $this_exon->{'genomic_align'}->genomic_align_block->starting_genomic_align->dnafrag_start,"   ", $this_exon->{'genomic_align'}->genomic_align_block->starting_genomic_align->dnafrag_end, "\n",
#         "   ", $this_exon->stable_id, ": ", $this_exon->start, "-", $this_exon->end, "[", $this_exon->strand, "]\n",
#         "   ", $this_exon->slice->seq_region_name, ": ", $this_exon->slice->start, "-", $this_exon->slice->end, "\n",
#         "   ", join(" - ", values %{$this_exon->{'genomic_aligns'}}), "\n",
#         "   ", $this_exon->seq->seq, "\n",
#         "   ", $this_exon->slice->subseq($this_exon->start, $this_exon->end, $this_exon->strand), "\n",
#         "   ", $this_exon->{'genomic_align'}->genomic_align_block->starting_genomic_align->original_sequence, "\n",
#         "   ", $this_exon->{'genomic_align'}->cigar_line, "\n",
#         "   ", $this_exon->{'genomic_align'}->genomic_align_block->starting_genomic_align->cigar_line, "\n",
#         ;
    $this_exon->get_mapped_sequence();
  }
  
  if (defined($genome_db)) {
    my $genome_db_id = $genome_db->dbID;
    my $these_exons;
    foreach my $this_exon (@{$self->{'all_exons'}}) {
      push(@$these_exons, $this_exon) if ($this_exon->{'genome_db_id'} == $genome_db_id);
    }
    return $these_exons;
  }

  return $self->{'all_exons'};
}


sub _set_all_overlapping_Transcripts_and_Exons {
  my ($self) = @_;

  my $all_transcripts;

  my $all_genes = $self->get_all_Genes;
  foreach my $this_gene (@$all_genes) {
    my $this_genomic_align  = $this_gene->{'genomic_align'};
    my $dnafrag_length = $this_genomic_align->dnafrag_end - $this_genomic_align->dnafrag_start;

    print STDERR "\nGene: ", $this_gene->stable_id, " ", $this_gene->slice->start, "\n";
    foreach my $this_transcript (@{$this_gene->get_all_Transcripts}) {
      print STDERR " + Transcript: ", $this_transcript->stable_id, "\n";
      my $does_this_transcript_overlap = 0;
      foreach my $this_exon (@{$this_transcript->get_all_Exons}) {
        if ($this_exon->start < $dnafrag_length and $this_exon->end > 0) {
          my $this_align_exon = new Bio::EnsEMBL::Compara::AlignSlice::Exon(
                  -EXON => $this_exon,
                  -ALIGN_SLICE => $self->reference_Slice,
                  -GENOMIC_ALIGN => $this_genomic_align,
                  -GENOME_DB_ID => $this_gene->{'genome_db_id'},
              );
          print STDERR "   + Exon: ", $this_align_exon->stable_id, " (", $this_align_exon->start, "-", $this_align_exon->end, ") [", $this_align_exon->strand, "]\n";
#           my $seq;
#           if ($this_align_exon->strand == 1) {
#             $seq = ("." x 50).$this_align_exon->seq->seq.("." x 50);
#           } else {
#             $seq = ("." x 50).$this_align_exon->seq->revcom->seq.("." x 50);
#           }
#           my $aseq = $self->reference_Slice->subseq($this_align_exon->start-50, $this_align_exon->end+50);
#           throw if (length($seq) != length($aseq));
#           $seq =~ s/(.{80})/$1\n/g;
#           $aseq =~ s/(.{80})/$1\n/g;
#           $seq =~ s/(.{20})/$1 /g;
#           $aseq =~ s/(.{20})/$1 /g;
#           my @seq = split("\n", $seq);
#           my @aseq = split("\n", $aseq);
#           if ($this_gene->{'genome_db_id'} == 3) {
#             for (my $a=0; $a<@seq; $a++) {
#               print STDERR "   ", $seq[$a], "\n";
#               print STDERR "   ", $aseq[$a], "\n";
#               print STDERR "\n";
#             }
#           }
          push(@{$self->{'all_exons'}}, $this_align_exon);
          
          $does_this_transcript_overlap = 1;

        }
      }
      if ($does_this_transcript_overlap) {
        my $this_align_transcript = new Bio::EnsEMBL::Compara::AlignSlice::Transcript(
                  -TRANSCRIPT => $this_transcript,
                  -GENOMIC_ALIGN => $this_genomic_align,
                  -GENOME_DB_ID => $this_gene->{'genome_db_id'},
            );
        push(@{$self->{'all_transcripts'}}, $this_align_transcript);
      }
    }
  }
}


1;
