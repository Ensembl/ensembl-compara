=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::BaseGenomicAlignSet - Base class for GenomicAlignBlock and GenomicAlignTree

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::EnsEMBL::Compara::BaseGenomicAlignSet;

use strict;
use warnings;

# Object preamble
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info deprecate verbose);


=head2 slice

  Arg [1]    : (optional) Bio::EnsEMBL::Slice $reference_slice
  Example    : my $slice = $genomic_align_block->slice;
  Example    : $genomic_align_block->slice($slice);
  Description: get/set for attribute slice.
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : 
  Caller     : general
  Status     : Stable

=cut

sub slice {
  my ($self, $reference_slice) = @_;

  if (defined($reference_slice)) {
#     throw "[$reference_slice] is not a Bio::EnsEMBL::Slice"
#         unless $reference_slice->isa("Bio::EnsEMBL::Slice");
    $self->{'reference_slice'} = $reference_slice;
  }

  return $self->{'reference_slice'};
}

=head2 reference_slice

  Arg [1]    : (optional) Bio::EnsEMBL::Slice $reference_slice
  Example    : my $reference_slice = $genomic_align_block->reference_slice;
  Example    : $genomic_align_block->reference_slice($slice);
  Description: Alias for slice method. TO BE DEPRECATED.
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : 
  Caller     : general
  Status     : Stable

=cut

sub reference_slice {
  my ($self, $reference_slice) = @_;

  return $self->slice($reference_slice);
}

=head2 start

  Arg [1]    : (optional) integer $start
  Example    : my $start = $genomic_align_block->start;
  Example    : $genomic_align_block->start(1035);
  Description: get/set for attribute reference_slice_start. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub start {
  my $self = shift;
  return $self->reference_slice_start(@_);
}


=head2 reference_slice_start

  Arg [1]    : integer $reference_slice_start
  Example    : my $reference_slice_start = $genomic_align_block->reference_slice_start;
  Example    : $genomic_align_block->reference_slice_start(1035);
  Description: get/set for attribute reference_slice_start. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub reference_slice_start {
    my ($self, $reference_slice_start) = @_;
    
    if (defined($reference_slice_start)) {
	$self->{'reference_slice_start'} = ($reference_slice_start or undef);
    }
    
    return $self->{'reference_slice_start'};
}


=head2 end

  Arg [1]    : (optional) integer $end
  Example    : my $end = $genomic_align_block->end;
  Example    : $genomic_align_block->end(1283);
  Description: get/set for attribute reference_slice_end. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub end {
  my $self = shift;
  return $self->reference_slice_end(@_);
}


=head2 reference_slice_end

  Arg [1]    : integer $reference_slice_end
  Example    : my $reference_slice_end = $genomic_align_block->reference_slice_end;
  Example    : $genomic_align_block->reference_slice_end(1283);
  Description: get/set for attribute reference_slice_end. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub reference_slice_end {
  my ($self, $reference_slice_end) = @_;
 
  if (defined($reference_slice_end)) {
    $self->{'reference_slice_end'} = ($reference_slice_end or undef);
  }
  
  return $self->{'reference_slice_end'};

}

=head2 strand

  Arg [1]    : integer $strand
  Example    : my $strand = $genomic_align_block->strand;
  Example    : $genomic_align_block->strand(-1);
  Description: get/set for attribute strand. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub strand {
    my ($self, $reference_slice_strand) = @_;
    
    if (defined($reference_slice_strand)) {
	$self->{'reference_slice_strand'} = ($reference_slice_strand or undef);
    }
    
    return $self->{'reference_slice_strand'};
}

=head2 reference_slice_strand

  Arg [1]    : integer $reference_slice_strand
  Example    : my $reference_slice_strand = $genomic_align_block->reference_slice_strand;
  Example    : $genomic_align_block->reference_slice_strand(-1);
  Description: get/set for attribute reference_slice_strand. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub reference_slice_strand {
  my ($self, $reference_slice_strand) = @_;
 
  if (defined($reference_slice_strand)) {
    $self->{'reference_slice_strand'} = ($reference_slice_strand or undef);
  }
  
  return $self->{'reference_slice_strand'};
}


=head2 restricted_aln_start

  Args       : none
  Example    : my $restricted_aln_start = $genomic_align_block->restricted_aln_start();
  Description: getter/setter of restricted_aln_start attribute. This is the position of the start in alignment coords of a 
               restricted GenomicAlignBlock or GenomicAlignTree
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub restricted_aln_start {
  my ($self, $restricted_aln_start) = @_;

  if (defined $restricted_aln_start) {
    $self->{_restricted_aln_start} = $restricted_aln_start;
  }

  return $self->{_restricted_aln_start};
}

=head2 restricted_aln_end

  Args       : none
  Example    : my $restricted_aln_end = $genomic_align_block->restricted_aln_end();
  Description: getter/setter of restricted_aln_start attribute. This is the position of the end in alignment coords of a 
               restricted GenomicAlignBlock or GenomicAlignTree
  Returntype : none 
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub restricted_aln_end {
  my ($self, $restricted_aln_end) = @_;

  if (defined $restricted_aln_end) {
    $self->{_restricted_aln_end} = $restricted_aln_end;
  }

  return $self->{_restricted_aln_end};
}

=head2 original_dbID

  Args       : none
  Example    : my $original_dbID = $genomic_align_block->original_dbID
  Description: getter/setter of original_dbID attribute. When a GenomicAlignBlock or GenomicAlignTree is restricted, this attribute is set to the dbID of the original GenomicAlignBlock or GenomicAlignTree object
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub original_dbID {
  my ($self, $original_dbID) = @_;

  if (defined $original_dbID) {
    $self->{_original_dbID} = $original_dbID;
  }

  return $self->{_original_dbID};
}

=head2 original_strand

  Args       : none
  Example    : my $original_strand = $genomic_align_block->original_strand
  Description: getter/setter of original_strand attribute. When a GenomicAlignBlock or GenomicAlignTree is restricted, this attribute keeps track of the reverse complementing of the original GenomicAlignBlock or GenomicAlignTree object

  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub original_strand {
  my ($self, $original_strand) = @_;

  #set
  if (defined $original_strand) {
    $self->{_original_strand} = $original_strand;
  }

  #initialise 
  if (!defined($self->{_original_strand})) {
    $self->{_original_strand} = 1;
  }

  return $self->{_original_strand};
}


=head2 is_restricted

  Args       : none
  Example    : my $is_restricted = $genomic_align_block->is_restricted;
  Description: returns true if orignal_dbID is set, else returns false. original_dbID is only set if the block has been restricted.
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub is_restricted {
  my ($self) = @_;

  if (defined $self->{_original_dbID}) {
      return 1;
  } else {
      return 0;
  }
}

=head2 restrict_between_reference_positions

  Arg[1]     : [optional] int $start, refers to the reference_dnafrag
  Arg[2]     : [optional] int $end, refers to the reference_dnafrag
  Arg[3]     : [optional] Bio::EnsEMBL::Compara::GenomicAlign $reference_GenomicAlign
  Arg[4]     : [optional] boolean $skip_empty_GenomicAligns
  Example    : none
  Description: restrict this GenomicAlignBlock. It returns a new object unless no
               restriction is needed. In that case, it returns the original unchanged
               object
               It might be the case that the restricted region coincide with a gap
               in one or several GenomicAligns. By default these GenomicAligns are
               returned with a dnafrag_end equals to its dnafrag_start + 1. For instance,
               a GenomicAlign with dnafrag_start = 12345 and dnafrag_end = 12344
               correspond to a block which goes on this region from before 12345 to
               after 12344, ie just between 12344 and 12345. You can choose to remove
               these empty GenomicAligns by setting $skip_empty_GenomicAligns to any
               true value.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object in scalar context. In
               list context, returns the previous object and the start and end
               positions of the restriction in alignment coordinates (from 1 to
               alignment_length)
  Exceptions : return undef if reference positions lie outside of the alignment
  Caller     : general
  Status     : At risk

=cut

sub restrict_between_reference_positions {
  my ($self, $start, $end, $reference_genomic_align, $skip_empty_GenomicAligns) = @_;
  my $genomic_align_set;
  my $new_reference_genomic_align;
  my $new_genomic_aligns = [];
  
  $reference_genomic_align ||= $self->reference_genomic_align;
  throw("A reference Bio::EnsEMBL::Compara::GenomicAlign must be given") if (!$reference_genomic_align);
  $start = $reference_genomic_align->dnafrag_start if (!defined($start));
  $end = $reference_genomic_align->dnafrag_end if (!defined($end));

  if ($start > $reference_genomic_align->dnafrag_end or $end < $reference_genomic_align->dnafrag_start) {
    # restricting outside of boundaries => return undef object
    warn("restricting outside of boundaries => return undef object: $start-$end (".$reference_genomic_align->dnafrag_start."-".$reference_genomic_align->dnafrag_end.")");
    return wantarray ? (undef, undef, undef) : undef;
  }
  my $number_of_base_pairs_to_trim_from_the_start = $start - $reference_genomic_align->dnafrag_start;
  my $number_of_base_pairs_to_trim_from_the_end  = $reference_genomic_align->dnafrag_end - $end;

  my $is_ref_low_coverage = 0;
  if ($reference_genomic_align->cigar_line =~ /X/) {
      $is_ref_low_coverage = 1;
  }

  ## Skip if no restriction is needed. Return original object! We are still going on with the
  ## restriction when either excess_at_the_start or excess_at_the_end are 0 as a (multiple)
  ## alignment may start or end with gaps in the reference species. In that case, we want to
  ## trim these gaps from the alignment as they fall just outside of the region of interest

  ##Exception if the reference species is low coverage, then need to continue 
  ##with this routine to find out the correct align positions
  if ($number_of_base_pairs_to_trim_from_the_start < 0 and $number_of_base_pairs_to_trim_from_the_end < 0 and !$is_ref_low_coverage) {
    return wantarray ? ($self, 1, $self->length) : $self;
  }

  my $negative_strand = ($reference_genomic_align->dnafrag_strand == -1);

  ## Create a new Bio::EnsEMBL::Compara::GenomicAlignBlock object
  throw("Reference GenomicAlign not found!") if (!$reference_genomic_align);

  my @reference_cigar = grep {$_} split(/(\d*[GDMXI])/, $reference_genomic_align->cigar_line);
  if ($negative_strand) {
    @reference_cigar = reverse @reference_cigar;
  }

  #If this is negative, eg when a slice starts in one block and ends in
  #another, need to set to 0 to ensure we enter the loop below. This
  #fixes a bug when using a 2x species as the reference and fetching using
  #an expanded align slice. 
  if ($number_of_base_pairs_to_trim_from_the_start < 0) {
      $number_of_base_pairs_to_trim_from_the_start = 0;
  }

  ## Parse start of cigar_line for the reference GenomicAlign
  my $counter_of_trimmed_columns_from_the_start = 0; # num. of bp in the alignment to be trimmed

  if ($number_of_base_pairs_to_trim_from_the_start >= 0) {
    my $counter_of_trimmed_base_pairs = 0; # num of bp in the reference sequence we trim (from the start)
    ## Loop through the cigar pieces
    while (my $cigar = shift(@reference_cigar)) {
      # Parse each cigar piece
      my ($num, $type) = ($cigar =~ /^(\d*)([GDMXI])/);
      $num = 1 if ($num eq "");

      # Insertions are not part of the alignment, don't count them
      if ($type ne "I") {
        $counter_of_trimmed_columns_from_the_start += $num;
      }

      # Matches and insertions are actual base pairs in the reference
      if ($type eq "M" or $type eq "I") {
        $counter_of_trimmed_base_pairs += $num;
        # If this cigar piece is too long and we overshoot the number of base pairs we want to trim,
        # we substitute this cigar piece by a shorter one
        if ($counter_of_trimmed_base_pairs > $number_of_base_pairs_to_trim_from_the_start) {
          my $new_cigar_piece = "";
          # length of the new cigar piece
          my $length = $counter_of_trimmed_base_pairs - $number_of_base_pairs_to_trim_from_the_start;
          if ($length > 1) {
            $new_cigar_piece = $length.$type;
          } elsif ($length == 1) {
            $new_cigar_piece = $type;
          }
          unshift(@reference_cigar, $new_cigar_piece) if ($new_cigar_piece);

          # There is no need to correct the counter of trimmed columns if we are in an insertion
          # when we overshoot
          if ($type eq "M") {
            $counter_of_trimmed_columns_from_the_start -= $length;
          }

          ## We don't want to start with an insertion or a deletion. Trim them!
          while (@reference_cigar and $reference_cigar[0] =~ /[DI]/) {
            my ($num, $type) = ($reference_cigar[0] =~ /^(\d*)([DIGMX])/);
            $num = 1 if ($num eq "");
            # only counts deletions, insertions are not part of the aligment
            $counter_of_trimmed_columns_from_the_start += $num if ($type eq "D");
            shift(@reference_cigar);
          }
          last;
        }
      }
    }
  }

  #If this is negative, eg when a slice starts in one block and ends in
  #another, need to set to 0 to ensure we enter the loop below. This
  #fixes a bug when using a 2x species as the reference and fetching using
  #an expanded align slice. 
  if ($number_of_base_pairs_to_trim_from_the_end < 0) {
      $number_of_base_pairs_to_trim_from_the_end = 0;
  }

  ## Parse end of cigar_line for the reference GenomicAlign
  my $counter_of_trimmed_columns_from_the_end = 0; # num. of bp in the alignment to be trimmed
  if ($number_of_base_pairs_to_trim_from_the_end >= 0) {
    my $counter_of_trimmed_base_pairs = 0; # num of bp in the reference sequence we trim (from the end)
    ## Loop through the cigar pieces
    while (my $cigar = pop(@reference_cigar)) {
      # Parse each cigar piece
      my ($num, $type) = ($cigar =~ /^(\d*)([DIGMX])/);
      $num = 1 if ($num eq "");

      # Insertions are not part of the alignment, don't count them
      if ($type ne "I") {
        $counter_of_trimmed_columns_from_the_end += $num;
      }

      # Matches and insertions are actual base pairs in the reference
      if ($type eq "M" or $type eq "I") {
        $counter_of_trimmed_base_pairs += $num;
        # If this cigar piece is too long and we overshoot the number of base pairs we want to trim,
        # we substitute this cigar piece by a shorter one
        if ($counter_of_trimmed_base_pairs > $number_of_base_pairs_to_trim_from_the_end) {
          my $new_cigar_piece = "";
          # length of the new cigar piece
          my $length = $counter_of_trimmed_base_pairs - $number_of_base_pairs_to_trim_from_the_end;
          if ($length > 1) {
            $new_cigar_piece = $length.$type;
          } elsif ($length == 1) {
            $new_cigar_piece = $type;
          }
          push(@reference_cigar, $new_cigar_piece) if ($new_cigar_piece);

          # There is no need to correct the counter of trimmed columns if we are in an insertion
          # when we overshoot
          if ($type eq "M") {
            $counter_of_trimmed_columns_from_the_end -= $length;
          }

          ## We don't want to end with an insertion or a deletion. Trim them!
          while (@reference_cigar and $reference_cigar[-1] =~ /[DI]/) {
            my ($num, $type) = ($reference_cigar[-1] =~ /^(\d*)([DIGMX])/);
            $num = 1 if ($num eq "");
            # only counts deletions, insertions are not part of the aligment
            $counter_of_trimmed_columns_from_the_end += $num if ($type eq "D");
            pop(@reference_cigar);
          }
          last;
        }
      }
    }
  }

  ## Skip if no restriction is needed. Return original object! This may happen when
  ## either excess_at_the_start or excess_at_the_end are 0 but the alignment does not
  ## start or end with gaps in the reference species.
  if ($counter_of_trimmed_columns_from_the_start <= 0 and $counter_of_trimmed_columns_from_the_end <= 0) {
    return wantarray ? ($self, 1, $self->length) : $self;
  }

  my ($aln_start, $aln_end);
  if ($negative_strand) {
    $aln_start = $counter_of_trimmed_columns_from_the_end + 1;
    $aln_end = $self->length - $counter_of_trimmed_columns_from_the_start;
  } else {
    $aln_start = $counter_of_trimmed_columns_from_the_start + 1;
    $aln_end = $self->length - $counter_of_trimmed_columns_from_the_end;
  }

  $genomic_align_set = $self->restrict_between_alignment_positions($aln_start, $aln_end, $skip_empty_GenomicAligns);
  $new_reference_genomic_align = $genomic_align_set->reference_genomic_align;

  if (!defined $self->{'restricted_aln_start'}) {
      $self->{'restricted_aln_start'} = 0;
  }
  if (!defined $self->{'restricted_aln_end'}) {
      $self->{'restricted_aln_end'} = 0;
  }
  $genomic_align_set->{'restricted_aln_start'} = $counter_of_trimmed_columns_from_the_start + $self->{'restricted_aln_start'};
  $genomic_align_set->{'restricted_aln_end'} = $counter_of_trimmed_columns_from_the_end + $self->{'restricted_aln_end'};
  #$genomic_align_set->{'original_length'} = $self->length;

  #Need to use original gab length. If original_length is not set, length has
  #not changed. Needed when use 2X genome as reference. 
  if (defined $self->{'original_length'}) {
      $genomic_align_set->{'original_length'} = $self->{'original_length'};
  } else {
      $genomic_align_set->{'original_length'} = $self->length;
  }

  if (defined $self->slice) {
    if ($self->strand == 1) {
      $genomic_align_set->start($new_reference_genomic_align->dnafrag_start -
          $self->slice->start + 1);
      $genomic_align_set->end($new_reference_genomic_align->dnafrag_end -
          $self->slice->start + 1);
      $genomic_align_set->strand(1);
    } else {
      $genomic_align_set->start($self->{reference_slice}->{end} -
          $new_reference_genomic_align->{dnafrag_end} + 1);
      $genomic_align_set->end($self->{reference_slice}->{end} -
          $new_reference_genomic_align->{dnafrag_start} + 1);
      $genomic_align_set->strand(-1);
    }
  }

  return wantarray ? ($genomic_align_set, $aln_start, $aln_end) : $genomic_align_set;
}

1;
