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

Bio::EnsEMBL::Compara::AlignSlice - An AlignSlice can be used to map genes from one species onto another one

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
use Bio::EnsEMBL::Utils::Exception qw(throw warning info verbose);
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

  return ($self->{'all_genomic_align_blocks'} || []);
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
  my ($self, $genome_db_id, @flags) = @_;

  if (!defined($self->{'all_genes_from_'.$genome_db_id})) {
    my $all_genes = [];

    my $these_genomic_aligns = [];
    foreach my $this_genomic_align_block (@{$self->get_all_GenomicAlignBlocks}) {
      # print STDERR "GenomicAlignBlock: $this_genomic_align_block->{dbID}\n";
      my $all_genomic_aligns = $this_genomic_align_block->genomic_align_array;
      foreach my $this_genomic_align (@$all_genomic_aligns) {
        my $this_genome_db = $this_genomic_align->dnafrag->genome_db;
        # print STDERR "GenomicAlign: ($this_genome_db->{dbID}:$this_genomic_align->{dnafrag}->{name}) [$this_genomic_align->{dnafrag_start} - $this_genomic_align->{dnafrag_end}]\n";
        next if ($this_genome_db->dbID != $genome_db_id);
        push(@$these_genomic_aligns, $this_genomic_align);
      }
    }
    if (!@$these_genomic_aligns) {
      $self->{'all_genes_from_'.$genome_db_id} = [];
      return [];
    }

    my $all_slices_coordinates;
    my $this_slice_coordinates;
    my $this_slice_adaptor = $these_genomic_aligns->[0]->dnafrag->genome_db->db_adaptor->get_SliceAdaptor;
    foreach my $this_genomic_align (sort {
            $a->dnafrag->name cmp $b->dnafrag->name or
            $a->dnafrag_start <=> $b->dnafrag_start }
          @$these_genomic_aligns) {
      if ($this_slice_coordinates and
          ($this_slice_coordinates->{name} eq $this_genomic_align->dnafrag->name) and
          (($this_genomic_align->dnafrag_start - $this_slice_coordinates->{end}) < 10000000)) {
        $this_slice_coordinates->{end} = $this_genomic_align->dnafrag_end;
      } else {
        push(@$all_slices_coordinates, {
                "coord_system_name" => $this_slice_coordinates->{coord_system_name},
                "name" => $this_slice_coordinates->{name},
                "start" => $this_slice_coordinates->{start},
                "end" => $this_slice_coordinates->{end},
                "genomic_aligns" => $this_slice_coordinates->{genomic_aligns}
            }) if ($this_slice_coordinates->{name});
        $this_slice_coordinates->{coord_system_name} = $this_genomic_align->dnafrag->coord_system_name;
        $this_slice_coordinates->{name} = $this_genomic_align->dnafrag->name;
        $this_slice_coordinates->{start} = $this_genomic_align->dnafrag_start;
        $this_slice_coordinates->{end} = $this_genomic_align->dnafrag_end;
        $this_slice_coordinates->{genomic_aligns} = [];
      }
      push(@{$this_slice_coordinates->{genomic_aligns}}, $this_genomic_align);
    }
    push(@$all_slices_coordinates, $this_slice_coordinates) if ($this_slice_coordinates);

    foreach $this_slice_coordinates (@$all_slices_coordinates) {
      my $this_slice = $this_slice_adaptor->fetch_by_region(
              $this_slice_coordinates->{coord_system_name},
              $this_slice_coordinates->{name},
              $this_slice_coordinates->{start},
              $this_slice_coordinates->{end}
          );

      ## Do not load transcript immediately or the cache could produce
      ## some troubles in some special cases! Moreover, in this way we will have
      ## the genes, the transcripts and the exons in the same slice!!
      my $these_genes = $this_slice->get_all_Genes();
      foreach my $this_genomic_align (@{$this_slice_coordinates->{genomic_aligns}}) {
        foreach my $this_gene (@$these_genes) {
          $this_gene->{original_slice} = $this_gene->slice if (!defined($this_gene->{original_slice}));
          # print STDERR "\n1.GENE ($this_gene->{stable_id}) $this_gene\n";
          my $mapped_gene = $self->_get_mapped_Gene($this_gene, $this_genomic_align);
#           $mapped_gene = $self->_get_mapped_Gene($this_gene, $this_genomic_align);
          if ($mapped_gene and @{$mapped_gene->get_all_Transcripts}) {
            push(@$all_genes, $mapped_gene);
          }
        }
      }
    }

    $all_genes = _compile_mapped_Genes($all_genes, @flags);

    $self->{'all_genes_from_'.$genome_db_id} = $all_genes;
  }

  return $self->{'all_genes_from_'.$genome_db_id};
}


=head2 _get_mapped_Gene

  Arg[1]     : Bio::EnsEMBL::Gene $original_gene
  Arg[2]     : Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
  Example    : my $mapped_gene = $align_slice->get_mapped_Gene($orignal_gene, $genomic_align);
  Description: returns a new Bio::EnsEMBL::Gene object. Mapping is based on exons.
               The object returned contains Bio::EnsEMBL::Transcripts objects. Those
               mapped transcripts contain Bio::EnsEMBL::Compara::AlignSlice::Exon objects.
               If no exon can be mapped, the returned object will contain an empty array of
               transcripts. Since mapped objects are not stored in the DB, they have no dbID
               and no adaptor.
  Returntype : Bio::EnsEMBL::Gene object. (new object)
  Exceptions : none
  Caller     : $object->methodname

=cut

sub _get_mapped_Gene {
  my ($self, $gene, $genomic_align) = @_;

  my $range_start = $genomic_align->{dnafrag_start} - $gene->slice->start + 1;
  my $range_end = $genomic_align->{dnafrag_end} - $gene->slice->start + 1;
  my $slice_length = $gene->slice->end - $gene->slice->start + 1;
  return undef if (($gene->start > $range_end) or ($gene->end < $range_start));

  my $from_mapper = $genomic_align->get_Mapper;
  my $to_mapper = $genomic_align->genomic_align_block->reference_genomic_align->get_Mapper;

  my $these_transcripts = [];

  foreach my $this_transcript (@{$gene->get_all_Transcripts}) {
    $this_transcript->{this_slice} = $this_transcript->slice;
    my $these_exons = [];
    foreach my $this_exon (@{$this_transcript->get_all_Exons}) {
      if (!defined($this_exon->{original_slice})) {
        $this_exon->{original_slice} = $this_exon->slice;
        $this_exon->{original_start} = $this_exon->start;
        $this_exon->{original_end} = $this_exon->end;
      }
      $this_exon->{this_slice} = $this_exon->slice;
throw if ($this_exon->slice->start != $gene->slice->start);
#       $range_start = $genomic_align->{dnafrag_start} - $this_exon->slice->start + 1;
#       $range_end = $genomic_align->{dnafrag_end} - $this_exon->slice->start + 1;
      if ($this_exon->start < $range_end and $this_exon->end > $range_start) {
        my $this_align_exon = new Bio::EnsEMBL::Compara::AlignSlice::Exon(
                -EXON => $this_exon,
                -ALIGN_SLICE => $self->reference_Slice,
                -FROM_MAPPER => $from_mapper,
                -TO_MAPPER => $to_mapper,
            );
        push(@{$these_exons}, $this_align_exon) if ($this_align_exon);
      } else {
        info("Exon ".$this_exon->stable_id." cannot be mapped using".
            " Bio::EnsEMBL::Compara::GenomicAlign #".$genomic_align->dbID);
      }
    }
    if (@$these_exons) {
      my $new_transcript = $this_transcript->new(
              -stable_id => $this_transcript->stable_id,
              -version => $this_transcript->version,
              -external_db => $this_transcript->external_db,
              -external_name => $this_transcript->external_name,
              -external_status => $this_transcript->external_status,
              -display_xref => $this_transcript->display_xref,
              -analysis => $this_transcript->analysis,
              -exons => $these_exons,
          );
      push(@{$these_transcripts}, $new_transcript);
    } else {
      info("No exon of transcript ".$this_transcript->stable_id." can be mapped using".
          " Bio::EnsEMBL::Compara::GenomicAlign #".$genomic_align->dbID);
    }
  }
  if (!@$these_transcripts) {
    info("No transcript of gene ".$gene->stable_id." can be mapped using".
        " Bio::EnsEMBL::Compara::GenomicAlign #".$genomic_align->dbID);
    return undef;
  }
  ## Create a new gene object. This is needed in order to avoid
  ## troubles with cache. Attach mapped transcripts.
  my $mapped_gene = $gene->new(
          -ANALYSIS => $gene->analysis,
          -SEQNAME => $gene->seqname,
          -STABLE_ID => $gene->stable_id,
          -VERSION => $gene->version,
          -EXTERNAL_NAME => $gene->external_name,
          -TYPE => $gene->type,
          -EXTERNAL_DB => $gene->external_db,
          -EXTERNAL_STATUS => $gene->external_status,
          -DISPLAY_XREF => $gene->display_xref,
          -DESCRIPTION => $gene->description,
          -TRANSCRIPTS => $these_transcripts
      );

  return $mapped_gene;
}



sub _compile_mapped_Genes {
  my ($mapped_genes, @flags) = @_;

  my $verbose = verbose();
  verbose(0); # Avoid warnings when mapped transcripts are not in the same strand
  
  ## Compile genes: group transcripts by gene->stable_id
  my $gene_by_gene_stable_id;
  my $transcripts_by_gene_stable_id;
  foreach my $mapped_gene (@$mapped_genes) {
    if (!$gene_by_gene_stable_id->{$mapped_gene->stable_id}) {
      $gene_by_gene_stable_id->{$mapped_gene->stable_id} = $mapped_gene;
    }
    ## Group all the transcripts by gene stable_id...
    push(@{$transcripts_by_gene_stable_id->{$mapped_gene->stable_id}},
        @{$mapped_gene->get_all_Transcripts});
  }
#   $mapped_genes = [values %$genes_by_stable_id];

  ## Compile transcripts: group exons by transcript->stable_id
  while (my ($gene_stable_id, $set_of_transcripts) = each %$transcripts_by_gene_stable_id) {
    my $transcript_by_transcript_stable_id;
    my $exons_by_transcript_stable_id;
    foreach my $transcript (@{$set_of_transcripts}) {
      if (!$transcript_by_transcript_stable_id->{$transcript->stable_id}) {
        $transcript_by_transcript_stable_id->{$transcript->stable_id} = $transcript;
      }
      ## Group all the exons by the transcript stable_id...
      push(@{$exons_by_transcript_stable_id->{$transcript->stable_id}},
          @{$transcript->get_all_Exons});
    }

    ## Try to merge splitted exons whenever possible
    while (my ($transcript_stable_id, $set_of_exons) = each %$exons_by_transcript_stable_id) {
      $exons_by_transcript_stable_id->{$transcript_stable_id} =
          _merge_Exons($set_of_exons, @flags);
    }
    my $all_transcripts;
    while (my ($transcript_stable_id, $set_of_exons) = each %$exons_by_transcript_stable_id) {
#       my $sets_of_compatible_exons = [$set_of_exons];
      my $sets_of_compatible_exons = _separate_in_incompatible_sets_of_Exons($set_of_exons, @flags);

        my $old_transcript = $transcript_by_transcript_stable_id->{$transcript_stable_id};
#       # Save first set of exons in the 
#       my $first_set_of_compatible_exons = shift(@{$sets_of_compatible_exons});
#       my $first_transcript = $transcript_by_transcript_stable_id->{$transcript_stable_id};
#       $first_transcript->flush_Exons();
#       foreach my $exon (@$first_set_of_compatible_exons) {
#         $first_transcript->add_Exon($exon);
#       }
#       push(@$all_transcripts, $first_transcript);

      foreach my $this_set_of_compatible_exons (@{$sets_of_compatible_exons}) {
        my $new_transcript = $old_transcript->new(
                -stable_id => $old_transcript->stable_id,
                -version => $old_transcript->version,
                -external_db => $old_transcript->external_db,
                -external_name => $old_transcript->external_name,
                -external_status => $old_transcript->external_status,
                -display_xref => $old_transcript->display_xref,
                -analysis => $old_transcript->analysis,
                -EXONS => $this_set_of_compatible_exons
            );
        push(@$all_transcripts, $new_transcript);
      }
    }
    
    $gene_by_gene_stable_id->{$gene_stable_id}->{'_transcript_array'} = $all_transcripts;
    # adjust start, end, strand and slice
    $gene_by_gene_stable_id->{$gene_stable_id}->recalculate_coordinates;
  }
  verbose($verbose);

  return [values %$gene_by_gene_stable_id];
}


=head2 _merge_Exons

  Arg[1]     : listref of Bio::EnsEMBL::Compara::AlignSlice::Exon $set_of_exons
  Arg[2...]  : %flags
  Example    : my $merged_exons = _merge_Exons($exons_to_be_merged, -CHECK_ORDER=>0);
  Description: Takes a list of Bio::EnsEMBL::Compara::AlignSlice::Exon and tries to
               merge them according to exon stable_id and some rules that can be
               tunned using flags. This method can overwrite some of the exon in the
               $set_of_exons
  Flags      : MAX_REPETITION_LENGTH. In principle you want to merge together pieces
                   of an exon which do not overlap (the beginning and the end of the
                   exon). With this flag you can to set up what amount of the original
                   exon is allowed on two aligned exons to be merged. (default is 100)
               MAX_GAP_LENGTH. If the distance between two pieces of exons in the
                   aligned slice is larger than this parameter, they will not be
                   merged. (default is 1000 bp)
               STRICT_EXON_PIECES_ORDER. This flag allows you to decide whether two
                   pieces of an exon should be merged or not if they are not in the
                   right order, for instance if the end of the original exon will
                   appear before the start on the merged exon. (default is 1, exons are
                   merged only if they are in the right order)
  Returntype : lisref of Bio::EnsEMBL::Compara::AlignSlice::Exon objects.
  Exceptions : none
  Caller     : methodname

=cut

sub _merge_Exons {
  my ($set_of_exons, @flags) = @_;
  my $merged_exons = []; # returned value

  my ($max_repetition_length,
      $max_gap_length,
      $strict_exon_pieces_order) = rearrange([qw(
          MAX_REPETITION_LENGTH
          MAX_GAP_LENGTH
          STRICT_EXON_PIECES_ORDER
      )], @flags);
  $max_repetition_length = 100 if (!defined($max_repetition_length));
  $max_gap_length = 1000 if (!defined($max_gap_length));
  $strict_exon_pieces_order = 1 if (!defined($strict_exon_pieces_order));

  my $exon_by_stable_id;
  # Group exons by stable_id
  foreach my $exon (@$set_of_exons) {
    push(@{$exon_by_stable_id->{$exon->stable_id}}, $exon);
  }
      
  # Merge compatible pieces of exons
  foreach my $these_exons (values %$exon_by_stable_id) {
    # Sort exons according to 
    $these_exons= [sort {$a->start <=> $b->start} @$these_exons];
  
    while (my $first_exon = shift @$these_exons) {
      for (my $count=0; $count<@$these_exons; $count++) {
        my $second_exon = $these_exons->[$count];
        # Check strands
        next if ($first_exon->strand != $second_exon->strand);

        my $gap_between_pieces_of_exon = $second_exon->start - $first_exon->end - 1;
        # Check whether both mapped parts do not overlap
        next if ($gap_between_pieces_of_exon < 0);

        # Check maximum gap between both pieces of exon
        next if ($gap_between_pieces_of_exon > $max_gap_length);

        # Check whether both mapped parts are in the right order
        if ($strict_exon_pieces_order) {
          if ($first_exon->strand == 1) {
            next if ($first_exon->get_aligned_start > $second_exon->get_aligned_start);
          } else {
            next if ($first_exon->get_aligned_end > $second_exon->get_aligned_end);
          }
        }

        # Check maximum overlapping within original exon, i.e. how much of the
        # same exon can be mapped twice
        my $repetition_length = $first_exon->get_aligned_end - $second_exon->get_aligned_start + 1;
        next if ($repetition_length > $max_repetition_length);
  
        ## Merge exons!!
        $second_exon = splice(@$these_exons, $count, 1); # remove exon from the list
        $first_exon->end($second_exon->end);
        if ($first_exon->strand == 1) {
          $first_exon->seq(new Bio::Seq(-seq =>
                  $first_exon->seq->seq.("-"x$gap_between_pieces_of_exon).$second_exon->seq->seq));
        } else {
          $first_exon->seq(new Bio::Seq(-seq =>
                  $second_exon->seq->seq.("-"x$gap_between_pieces_of_exon).$first_exon->seq->seq));
        }
        $first_exon->cigar_line(
            $first_exon->cigar_line.
            $gap_between_pieces_of_exon."D".
            $second_exon->cigar_line);
      }
      push(@$merged_exons, $first_exon);
    }
  }

  return $merged_exons;
}


=head2 _separate_in_incompatible_sets_of_Exons

  Arg[1]     : listref of Bio::EnsEMBL::Compara::AlignSlice::Exon $set_of_exons
  Arg[2...]  : %flags
  Example    : my $sets_of_exons = _separate_in_incompatible_sets_of_Exons(
                   $set_of_exons, -MAX_INTRON_LENGTH=>100000);
  Description: Takes a list of Bio::EnsEMBL::Compara::AlignSlice::Exon and separate
               them in sets of comaptible exons. Compatibility is defined taking into
               account 5 parameters:
                 - exons must be in the same strand
                 - exons cannot overlap on the align_slice
                 - distance between exons cannot be larger than MAX_INTRON_LENGTH
                 - two exons with the same stable_id can belong to the same transcript
                   only if they represent diferent parts of the original exon. Some
                   overlapping is allowed (see MAX_REPETITION_LENGTH flag).
                 - exons must be in the same order as in the original transcript
                   if the STRICT_EXON_ORDER flag is on.
  Flags      : MAX_REPETITION_LENGTH. In principle you want to link together pieces
                   of an exon which do not overlap (the beginning and the end of the
                   exon). With this flag you can to set up what amount of the original
                   exon is allowed on two aligned exons to be linked. (default is 100)
               MAX_INTRON_LENGTH. If the distance between two exons in the aligned slice
                   is larger than this parameter, they will not be linked. (default is
                   100000 bp)
               STRICT_EXON_ORDER. This flag allows you to decide whether two
                   exons should be linked or not if they are not in the
                   original order. (default is 0, exons are linked even if they are not
                   in the right order)
  Returntype : listref of lisrefs of Bio::EnsEMBL::Compara::AlignSlice::Exon objects.
  Exceptions : none
  Caller     : methodname

=cut

sub _separate_in_incompatible_sets_of_Exons {
  my ($set_of_exons, @flags) = @_;
  my $sets_of_exons = [];

  my ($max_repetition_length,
      $max_intron_length,
      $strict_exon_order) = rearrange([qw(
          MAX_REPETITION_LENGTH
          MAX_INTRON_LENGTH
          STRICT_EXON_ORDER
      )], @flags);
  $max_repetition_length = 100 if (!defined($max_repetition_length));
  $max_intron_length = 100000 if (!defined($max_intron_length));
  $strict_exon_order = 0 if (!defined($strict_exon_order));
  
  my $last_exon;
  my $this_set_of_exons = [];
  foreach my $this_exon (sort {$a->start <=> $b->start} @$set_of_exons) {
    if ($last_exon) {
        # Calculate intron length
        my $intron_length = $this_exon->start - $last_exon->end - 1;
        # Calculate whether both mapped parts are in the right order
        my $order_is_ok = 1;
        if ($strict_exon_order) {
          if ($this_exon->strand == 1) {
            $order_is_ok = 0 if ($this_exon->exon->start < $last_exon->exon->start);
          } else {
            $order_is_ok = 0 if ($this_exon->exon->start > $last_exon->exon->start);
          }
        }
        my $repetition_length = 0;
        if ($last_exon->stable_id eq $this_exon->stable_id) {
          $repetition_length = $last_exon->get_aligned_end - $this_exon->get_aligned_start + 1;
        }

        if (($last_exon->strand != $this_exon->strand) or
            ($intron_length < 0) or
            ($intron_length > $max_intron_length) or
            (!$order_is_ok) or
            ($repetition_length > $max_repetition_length)) {
          # this_exon and last_exon should be in separate sets. Save current
          # set_of_exons and start a new set_of_exons
          push(@$sets_of_exons, $this_set_of_exons);
          $this_set_of_exons = [];
      }
    }
    push(@$this_set_of_exons, $this_exon);
    $last_exon = $this_exon;
  }
  push(@$sets_of_exons, $this_set_of_exons);

  return $sets_of_exons;
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


1;
