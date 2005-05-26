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

Bio::EnsEMBL::Compara::AlignSlice - An AlignSlice can be used to map genes and features from one species onto another one

=head1 SYNOPSIS
  
  use Bio::EnsEMBL::Compara::AlignSlice;
  
  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(
          -adaptor => $align_slice_adaptor,
          -reference_Slice => $reference_Slice,
          -genomicAlignBlocks => $all_genomic_align_blocks,
      );

  my $mapped_genes =
      $align_slice->get_all_Genes_by_genome_db_id($mouse_genome_db->dbID,
              -MAX_REPETITION_LENGTH => 100,
              -MAX_GAP_LENGTH => 100,
              -MAX_INTRON_LENGTH => 100000,
              -STRICT_ORDER_OF_EXON_PIECES => 1,
              -STRICT_ORDER_OF_EXONS => 0);
          );

  my $simple_align = $align_slice->get_projected_SimpleAlign();

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
  my $mapped_genes = $align_slice->get_all_Genes_by_genome_db_id(3);
  my $simple_align = $align_slice->get_projected_SimpleAlign();

=head1 OBJECT ATTRIBUTES

=over

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor object to access DB

=item reference_slice

Bio::EnsEMBL::Slice object used to create this Bio::EnsEBML::Compara::AlignSlice object

=item all_genomic_align_blocks

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
use Bio::EnsEMBL::Compara::AlignSlice::Slice;
use Bio::SimpleAlign;


=head2 new (CONSTRUCTOR)

  Arg[1]     : a reference to a hash where keys can be:
                 -adaptor
                 -reference_slice
                 -genomic_align_blocks
                 -expanded
  Example    : my $align_slice =
                   new Bio::EnsEMBL::Compara::AlignSlice(
                       -adaptor => $align_slice_adaptor,
                       -reference_slice => $reference_slice,
                       -genomic_align_blocks => [$gab1, $gab2]
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

  my ($adaptor, $reference_slice, $genomic_align_blocks, $method_link_species_set,
      $expanded) =
      rearrange([qw(
          ADAPTOR REFERENCE_SLICE GENOMIC_ALIGN_BLOCKS METHOD_LINK_SPECIES_SET
          EXPANDED 
      )], @args);

  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->reference_Slice($reference_slice) if (defined ($reference_slice));
  if (defined($genomic_align_blocks)) {  
    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
      $self->add_GenomicAlignBlock($this_genomic_align_block);
    }
  }
  $self->{_method_link_species_set} = $method_link_species_set if (defined($method_link_species_set));

  $self->{expanded} = 0;
  if ($expanded) {
    $self->{expanded} = 1;
  }
  $self->_create_underlying_Slices($genomic_align_blocks, $expanded);

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


=head2 _create_underlying_Slices (experimental)

  Arg[1]     : listref of Bio::EnsEMBL::Compara::GenomicAlignBlocks
               $genomic_align_blocks
  Arg[2]     : [optional] boolean $expanded (default = FALSE)
  Example    : 
  Description: Creates a set of Bio::EnsEMBL::Compara::AlignSlice::Slices
               and attach it to this object. 
  Returntype : 
  Exceptions : warns about overlapping GenomicAlignBlocks
  Caller     : 

TODO: check negative strand!!

=cut

sub _create_underlying_Slices {
  my ($self, $genomic_align_blocks, $expanded) = @_;

  ## Calculate the length of the fake_slice
  my $align_slice_length = 0;
# # #   my $align_slice_seq;
  my $last_start_pos = $self->reference_Slice->start;
  my $big_mapper = Bio::EnsEMBL::Mapper->new("sequence", "alignment");

  my @sorted_genomic_align_blocks;
  my $last_end;
  foreach my $genomic_align_block (sort
          {$a->reference_genomic_align->dnafrag_start <=>
          $b->reference_genomic_align->dnafrag_start}
          @{$genomic_align_blocks}) {
    if (!defined($last_end) or $genomic_align_block->reference_genomic_align->dnafrag_start > $last_end) {
      push(@sorted_genomic_align_blocks, $genomic_align_block);
    } else {
      warning("Ignoring Bio::EnsEMBL::Compara::GenomicAlignBlock #".
              ($genomic_align_block->dbID or "-unknown")." because it overlaps".
              " previous Bio::EnsEMBL::Compara::GenomicAlignBlock");
    }
    $last_end = $genomic_align_block->reference_genomic_align->dnafrag_end;
  }

  foreach my $this_genomic_align_block (@sorted_genomic_align_blocks) {
    my $reference_genomic_align = $this_genomic_align_block->reference_genomic_align;
    my $this_pos = $reference_genomic_align->dnafrag_start;
    my $this_gap_between_genomic_align_blocks = $this_pos - $last_start_pos;
    my $excess_at_the_start = $self->reference_Slice->start - $reference_genomic_align->dnafrag_start;
    my $excess_at_the_end  = $reference_genomic_align->dnafrag_end - $self->reference_Slice->end;
    if ($excess_at_the_start > 0) {
      ## First GAB. The slice start inside this GAB...
      my $this_align_slice_seq = $reference_genomic_align->aligned_sequence("+FAKE_SEQ"); # use *fake* aligned seq.
      ## Memory optimization: start looking from $excess_at_the_end from the start
      my $truncated_seq = substr($this_align_slice_seq, 0, $excess_at_the_start);
      substr($this_align_slice_seq, 0, $excess_at_the_start, "");
      my $num_of_nucl = $truncated_seq =~ tr/A-Za-z/A-Za-z/;
      $excess_at_the_start -= $num_of_nucl;
      $this_align_slice_seq =~ s/(\-*([^\-]\-*){$excess_at_the_start})//;
      $truncated_seq = ($1 or "").$truncated_seq;

      ## Truncate GenomicAlignBlock
      $reference_genomic_align->genomic_align_block->dbID(0); # unset dbID
      ## Truncate all the GenomicAligns
      foreach my $genomic_align (@{$this_genomic_align_block->get_all_GenomicAligns}) {
        my $aligned_sequence = $genomic_align->aligned_sequence("+FAKE_SEQ"); # use *fake* aligned seq.
        my $this_truncated_seq = substr($aligned_sequence, 0, length($truncated_seq));
        substr($aligned_sequence, 0, length($truncated_seq), "");
        $genomic_align->aligned_sequence($aligned_sequence);
        $genomic_align->original_sequence(0); # unset original_sequence
        $genomic_align->cigar_line(0); # unset cigar_line (will be build using the new fake aligned_sequence)
        $genomic_align->cigar_line(); # build cigar_line according to fake aligned_seq
        $genomic_align->aligned_sequence(0); # unset the *fake* aligned sequence
        $this_truncated_seq =~ s/\-//g;
        if ($genomic_align->dnafrag_strand == 1) {
          $genomic_align->dnafrag_start($genomic_align->dnafrag_start + CORE::length($this_truncated_seq));
        } else {
          $genomic_align->dnafrag_end($genomic_align->dnafrag_end - CORE::length($this_truncated_seq));
        }
        $genomic_align->dbID(0); # unset dbID
      }
    }
    if ($excess_at_the_end > 0) {
      my $this_align_slice_seq = $reference_genomic_align->aligned_sequence("+FAKE_SEQ"); # use *fake* aligned seq.
      ## Optimization: start looking from $excess_at_the_end from the end because
      ## the pattern match at the end of the string could be very slow
      my $truncated_seq = substr($this_align_slice_seq, -$excess_at_the_end);
      substr($this_align_slice_seq, -$excess_at_the_end, $excess_at_the_end, "");
      my $num_of_nucl = $truncated_seq =~ tr/A-Za-z/A-Za-z/;
      $excess_at_the_end -= $num_of_nucl;
      $this_align_slice_seq =~ s/(\-*([^\-]\-*){$excess_at_the_end})$//;
      $truncated_seq = $1.$truncated_seq;

      ## Truncate GenomicAlignBlock
      $reference_genomic_align->genomic_align_block->dbID(0); # unset dbID
      ## Truncate all the GenomicAligns
      foreach my $genomic_align (@{$this_genomic_align_block->get_all_GenomicAligns}) {
        my $aligned_sequence = $genomic_align->aligned_sequence("+FAKE_SEQ"); # use *fake* aligned seq.
        my $this_truncated_seq = substr($aligned_sequence, - length($truncated_seq));
        substr($aligned_sequence, - length($truncated_seq), length($truncated_seq), "");
        $genomic_align->aligned_sequence($aligned_sequence);
        $genomic_align->original_sequence(0); # unset original_sequence
        $genomic_align->cigar_line(0); # unset cigar_line (will be build using the new fake aligned_sequence)
        $genomic_align->cigar_line(); # build cigar_line according to fake aligned_seq
        $genomic_align->aligned_sequence(0); # unset the *fake* aligned sequence
        $this_truncated_seq =~ s/\-//g;
        if ($genomic_align->dnafrag_strand == 1) {
          $genomic_align->dnafrag_end($genomic_align->dnafrag_end - CORE::length($this_truncated_seq));
        } else {
          $genomic_align->dnafrag_start($genomic_align->dnafrag_start + CORE::length($this_truncated_seq));
        }
        $genomic_align->dbID(0); # unset dbID
      }
    }
    if ($this_gap_between_genomic_align_blocks > 0) {
#       warning("Bio::EnsEMBL::Compara::GenomicAlignBlock(#".
#               $reference_genomic_align->genomic_align_block->dbID.")");
# # #       $align_slice_seq .= $self->reference_Slice->subseq(
# # #           $last_start_pos - $self->reference_Slice->start + 1,
# # #           $this_pos - $self->reference_Slice->start, 1);
      ## Add mapper info for inter-genomic_align_block space
      $big_mapper->add_map_coordinates(
              'sequence',
              $last_start_pos,
              $this_pos,
              $self->reference_Slice->strand,
              'alignment',
              $align_slice_length + 1,
              $align_slice_length + 1 + $this_gap_between_genomic_align_blocks,
          );
      $align_slice_length += $this_gap_between_genomic_align_blocks;
    }
    $reference_genomic_align->genomic_align_block->reference_slice_start($align_slice_length + 1);
    if ($expanded) {
      $align_slice_length += CORE::length($reference_genomic_align->aligned_sequence("+FAKE_SEQ"));
      $big_mapper->add_Mapper($reference_genomic_align->get_Mapper);
    } else {
      $align_slice_length += $reference_genomic_align->dnafrag_end - $reference_genomic_align->dnafrag_start + 1;
      $big_mapper->add_Mapper($reference_genomic_align->get_Mapper(0,1));
    }
    $reference_genomic_align->genomic_align_block->reference_slice_end($align_slice_length);
    $reference_genomic_align->genomic_align_block->reference_slice($self);
# # #     $align_slice_seq .= $reference_genomic_align->aligned_sequence;

    $last_start_pos = $reference_genomic_align->dnafrag_end + 1;
  }
  my $this_pos = $self->reference_Slice->end;
  ## $last_start_pos is the next nucleotide position after the last mapped one.
  my $this_gap_between_genomic_align_blocks = $this_pos - ($last_start_pos - 1);
  if ($this_gap_between_genomic_align_blocks > 0) {
    ## STRAND!!!
# # #     $align_slice_seq .= $self->reference_Slice->subseq(
# # #         $last_start_pos - $self->reference_Slice->start + 1,
# # #         $this_pos - $self->reference_Slice->start + 1, 1);
    $big_mapper->add_map_coordinates(
            'sequence',
            $last_start_pos,
            $this_pos,
            $self->reference_Slice->strand,
            'alignment',
            $align_slice_length + 1,
            $align_slice_length + $this_gap_between_genomic_align_blocks,
            );
    $align_slice_length += $this_gap_between_genomic_align_blocks;
  }

# # #   ## Create a fake seq_region_name
# # #   my $seq_region_name = "AlignSlice";
# # #   $seq_region_name .= "(".$self->reference_Slice->name.")" if ($self->reference_Slice);
# # #   # Add method_link_species_set_id?
# # # # #   $self->seq_region_name($seq_region_name);
# # # 
# # #   ## Create the fake_slice
# # #   my $fake_slice = new Bio::EnsEMBL::Slice(
# # #           -SEQ_REGION_NAME => $seq_region_name,
# # #           -SEQ => $align_slice_seq,
# # #           -START => 1,
# # #           -END => $align_slice_length,
# # #           -STRAND => 1,
# # #       );
# # #   $self->{slice} = $fake_slice;

  foreach my $species (@{$self->{_method_link_species_set}->species_set}) {
    $self->{slices}->{$species->name} = new Bio::EnsEMBL::Compara::AlignSlice::Slice(
            -length => $align_slice_length,
            -requesting_slice => $self->reference_Slice,
            -method_link_species_set => $self->{_method_link_species_set},
            -genome_db => $species,
            -expanded => $expanded,
        );
  }
  my $ref_species =
      $self->reference_Slice->adaptor->db->get_MetaContainer->get_Species->binomial;
  $self->{slices}->{$ref_species}->add_Slice_Mapper_pair(
          $self->reference_Slice,
          $big_mapper,
          1,
          $align_slice_length,
          $self->reference_Slice->strand
      );

  my $slice_adaptors;
  foreach my $this_genomic_align_block (@sorted_genomic_align_blocks) {
    foreach my $this_genomic_align
            (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
      my $species = $this_genomic_align->dnafrag->genome_db->name;
      throw ("This species [$species] is not included in the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet")
          if (!defined($self->{slices}->{$species}));
      if (!defined($slice_adaptors->{$species})) {
        $slice_adaptors->{$species} =
            $this_genomic_align->dnafrag->genome_db->db_adaptor->get_SliceAdaptor;
      }
      my $this_slice = $slice_adaptors->{$species}->fetch_by_region(
              $this_genomic_align->dnafrag->coord_system_name,
              $this_genomic_align->dnafrag->name,
              $this_genomic_align->dnafrag_start,
              $this_genomic_align->dnafrag_end,
              $this_genomic_align->dnafrag_strand
          );

      if ($expanded) {
        $self->{slices}->{$species}->add_Slice_Mapper_pair(
                $this_slice,
                $this_genomic_align->get_Mapper,
                $this_genomic_align->genomic_align_block->reference_slice_start,
                $this_genomic_align->genomic_align_block->reference_slice_end,
                $this_genomic_align->dnafrag_strand
            );
      } else {
        $self->{slices}->{$species}->add_Slice_Mapper_pair(
                $this_slice,
                $this_genomic_align->get_Mapper(0,1),
                $this_genomic_align->genomic_align_block->reference_slice_start,
                $this_genomic_align->genomic_align_block->reference_slice_end,
                $this_genomic_align->dnafrag_strand
            );
      }
      

    }
  }

  $self->{_slices} = [$self->{slices}->{$ref_species}];
  foreach my $species (@{$self->{_method_link_species_set}->species_set}) {
    next if ($species->name eq $ref_species);
    push(@{$self->{_slices}}, $self->{slices}->{$species->name});
  }
#   undef($self->{slices});

  return $self;
}


=head2 get_all_Slices (experimental)

  Arg[1]     : [optional] string $species_name1
  Arg[2]     : [optional] string $species_name2
  Arg[...]   : [optional] string $species_nameN
  Example    : my $slices = $align_slice->get_all_Slices
  Description: getter for all the Slices in this AlignSlice. If a list
               of species is specified, returns only the slices for
               these species. The slices are returned in a "smart"
               order, i.e. the slice corresponding to the reference
               species is returned first and then the remaining slices
               depending on their phylogenetic distance to the first
               one.
  Returntype : listref of Bio::EnsEMBL::Compara::AlignSlice::Slice
               objects.
  Exceptions : 
  Caller     : $object->methodname

=cut

sub get_all_Slices {
  my ($self, @species_names) = @_;
  my $slices;

  if (@species_names) {
    foreach my $slice (@{$self->{_slices}}) {
      foreach my $this_species_name (@species_names) {
        push(@$slices, $slice) if ($this_species_name eq $slice->genome_db->name);
      }
    }
  } else {
    $slices = $self->{_slices};
  }

  return $slices;
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
  Example    : my $all_genomic_align_blocks = $align_slice->get_all_GenomicAlignBlocks
  Description: getter for the attribute all_genomic_align_blocks
  Returntype : listref of Bio::EnsEMBL::Compara::GenomicAlignBlock objects
  Exceptions : none
  Caller     : $object->methodname

=cut

sub get_all_GenomicAlignBlocks {
  my ($self) = @_;

  return ($self->{'all_genomic_align_blocks'} || []);
}


=head2 get_SimpleAlign

  Arg[1]      : none
  Example     : use Bio::AlignIO;
                my $out = Bio::AlignIO->newFh(-fh=>\*STDOUT, -format=> "clustalw");
                print $out $align_slice->get_SimpleAlign();
  Description : This method creates a Bio::SimpleAlign object using the
                Bio::EnsEMBL::Compara::AlignSlice::Slices underlying this
                Bio::EnsEMBL::Compara::AlignSlice object. The SimpleAlign
                describes the alignment where the first sequence
                corresponds to the reference Slice and the remaining
                correspond to the other species.
  Returntype  : Bio::SimpleAlign object
  Exceptions  : 
  Caller      : $object->methodname

=cut

sub get_SimpleAlign {
  my ($self) = @_;
  my $simple_align;

  ## Create a single Bio::SimpleAlign for the projection  
  $simple_align = Bio::SimpleAlign->new();
  $simple_align->id("ProjectedMultiAlign");

  foreach my $slice (@{$self->get_all_Slices}) {
    my $seq = Bio::LocatableSeq->new(
            -SEQ    => $slice->seq,
            -START  => $slice->start,
            -END    => $slice->end,
            -ID     => $slice->genome_db->name,
            -STRAND => $slice->strand
        );
    $simple_align->add_seq($seq);
  }

  return $simple_align;
}


1;
