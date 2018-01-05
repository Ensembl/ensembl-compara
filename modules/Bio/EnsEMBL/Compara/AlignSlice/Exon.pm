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

=head1 NAME

Bio::EnsEMBL::Compara::AlignSlice::Exon - Description

=head1 INHERITANCE

This module inherits attributes and methods from Bio::EnsEMBL::Exon module

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::AlignSlice::Exon;
  
  my $exon = new Bio::EnsEMBL::Compara::AlignSlice::Exon(
      );

SET VALUES

GET VALUES

=head1 OBJECT ATTRIBUTES

=over

=item exon

original Bio::EnsEMBL::Exon object

=item slice

Bio::EnsEMBL::Slice object on which this Bio::EnsEMBL::Compara::AlignSlice::Exon is defined

=item cigar_line

A string describing the mapping of this exon on the slice

=item phase

This exon results from the mapping of a real exon. It may suffer indels and duplications
during the process which makes this mapped exon unreadable by a translation machinery.
The phase is set to -1 by default.

=item end_phase

This exon results from the mapping of a real exon. It may suffer indels and duplications
during the process which makes this mapped exon unreadable by a translation machinery.
The end_phase is set to -1 by default.

=back

=head1 AUTHORS

Javier Herrero


=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::AlignSlice::Exon;

use strict;
use warnings;
use Bio::EnsEMBL::Exon;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);

our @ISA = qw(Bio::EnsEMBL::Exon);

=head2 new (CONSTRUCTOR)

  Arg[1]     : a reference to a hash where keys can be:
                 -exon
                 -adaptor
                 -reference_slice
  Example    : my $align_slice =
                   new Bio::EnsEMBL::Compara::AlignSlice(
                       -exon => $original_exon
                       -reference_slice => $reference_slice,
                   );
  Description: Creates a new Bio::EnsEMBL::AlignSlice::Exon object
  Returntype : Bio::EnsEMBL::Compara::AlignSlice::Exon object
  Exceptions : return an object with no start, end nor strand if the
               exon cannot be mapped on the reference Slice.

=cut

sub new {
  my ($class, @args) = @_;

  my $self = {};
  bless($self, $class);

  my ($exon, $align_slice, $from_mapper, $to_mapper, $original_rank) =
      rearrange([qw(
          EXON ALIGN_SLICE FROM_MAPPER TO_MAPPER ORIGINAL_RANK
      )], @args);

  $self->exon($exon) if (defined ($exon));
#   $self->genomic_align($genomic_align) if (defined($genomic_align));
#   $self->from_genomic_align_id($from_genomic_align_id) if (defined($from_genomic_align_id));
#   $self->to_genomic_align_id($to_genomic_align_id) if (defined($to_genomic_align_id));
  $self->slice($align_slice) if (defined($align_slice));
  $self->original_rank($original_rank) if (defined($original_rank));

  $self->phase(-1);
  $self->end_phase(-1);

  return $self->map_Exon_on_Slice($from_mapper, $to_mapper);
}


=head2 copy (CONSTRUCTOR)

  Arg[1]     : none
  Example    : my $new_align_slice = $old_align_slice->copy()
  Description: Creates a new Bio::EnsEMBL::AlignSlice::Exon object which
               is an exact copy of the calling object
  Returntype : Bio::EnsEMBL::Compara::AlignSlice::Exon object
  Exceptions : 
  Caller     : $obeject->methodname

=cut

sub copy {
  my ($self) = @_;

  my $copy;
  while (my ($key, $value) = each %$self) {
    $copy->{$key} = $value;
  }

  bless($copy, ref($self));
  return $copy;
}


=head2 slice

  Arg[1]     : (optional) Bio::EnsEMBL::Slice $reference_slice
  Example    : $align_exon->slice($reference_slice);
  Example    : $reference_slice = $align_exon->slice();
  Description: Get/set the attribute slice. This method is overloaded in order
               to map original coordinates onto the reference Slice.
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : 

=cut

sub slice {
  my ($self, $slice) = @_;

  if (defined($slice)) {
    $self->{'slice'} = $slice;
  }

  return $self->{'slice'};
}


=head2 original_rank

  Arg[1]     : (optional) integer $original_rank
  Example    : $align_exon->original_rank(5);
  Example    : $original_rank = $align_exon->original_rank();
  Description: Get/set the attribute original_rank. The orignal_rank
               is the position of the orginal Exon in the original
               Transcript
  Returntype : integer
  Exceptions : 

=cut

sub original_rank {
  my ($self, $original_rank) = @_;

  if (defined($original_rank)) {
    $self->{'original_rank'} = $original_rank;
  }

  return $self->{'original_rank'};
}


=head2 map_Exon_on_Slice

  Arg[1]     : Bio::EnsEMBL::Mapper $from_mapper
  Arg[2]     : Bio::EnsEMBL::Mapper $to_mapper
  Example    : $align_exon->map_Exon_on_Slice($from_mapper, $to_mapper);
  Description: This function takes the original exon and maps it on the slice
               using the mappers.
  Returntype : Bio::EnsEMBL::Compara::AlignSlice::Exon object
  Exceptions : returns undef if not enough information is provided
  Exceptions : returns undef if no piece of the original exon can be mapped.
  Caller     : new

=cut

sub map_Exon_on_Slice {
  my ($self, $from_mapper, $to_mapper) = @_;
  my $original_exon = $self->exon;
  my $slice = $self->slice;

  if (!defined($slice) or !defined($original_exon) or !defined($from_mapper)) {
    return $self;
  }

  my @alignment_coords = $from_mapper->map_coordinates(
          "sequence", # $self->genomic_align->dbID,
          $original_exon->slice->start + $original_exon->start - 1,
          $original_exon->slice->start + $original_exon->end - 1,
          $original_exon->strand,
          "sequence" # $from_mapper->from
      );

  my $aligned_start;
  my $aligned_end;
  my $aligned_strand = 0;
  my $aligned_sequence = "";
  my $aligned_cigar = "";

  my $global_alignment_coord_start;
  my $global_alignment_coord_end;
  my $last_alignment_coord_end;
  my $last_alignment_coord_start;
  foreach my $alignment_coord (@alignment_coords) {
    ## $alignment_coord refer to genomic_align_block: (1 to genomic_align_block->length) [+]

    if ($alignment_coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
      if ($alignment_coord->strand == 1) {
        if ($last_alignment_coord_end) {
          # Consider gap between this piece and the previous as a deletion
          my $length = $alignment_coord->start - $last_alignment_coord_end - 1;
          $aligned_cigar .= $length if ($length>1);
          $aligned_cigar .= "D" if ($length);
        }
        $last_alignment_coord_end = $alignment_coord->end;
        $global_alignment_coord_start = $alignment_coord->start if (!$global_alignment_coord_start);
        $global_alignment_coord_end = $alignment_coord->end;
      } else {
        if ($last_alignment_coord_start) {
          # Consider gap between this piece and the previous as a deletion
          my $length = $last_alignment_coord_start - $alignment_coord->end - 1;
          $aligned_cigar .= $length if ($length>1);
          $aligned_cigar .= "D" if ($length);
        }
        $last_alignment_coord_start = $alignment_coord->start;
        $global_alignment_coord_end = $alignment_coord->end if (!$global_alignment_coord_end);
        $global_alignment_coord_start = $alignment_coord->start;
      }
    } else {
      # This piece is outside of the alignment -> consider as an insertion
      my $length = $alignment_coord->length;
      $aligned_cigar .= $length if ($length>1);
      $aligned_cigar .= "I" if ($length);
      next;
    }

    if (!defined($to_mapper)) {
      ## Mapping on the alignment (expanded mode)
      if ($alignment_coord->strand == 1) {
        $aligned_strand = 1;
        $aligned_start = $alignment_coord->start if (!$aligned_start);
        $aligned_end = $alignment_coord->end;
      } else {
        $aligned_strand = -1;
        $aligned_start = $alignment_coord->start;
        $aligned_end = $alignment_coord->end if (!$aligned_end);
      }
      my $num = $alignment_coord->end - $alignment_coord->start + 1;
      $aligned_cigar .= $num if ($num > 1);
      $aligned_cigar .= "M" if ($num);

    } else {
      ## Mapping on the reference_Slice (collapsed mode)
      my @mapped_coords = $to_mapper->map_coordinates(
              "alignment", # $self->genomic_align->genomic_align_block->dbID,
              $alignment_coord->start,
              $alignment_coord->end,
              $alignment_coord->strand,
              "alignment" # $to_mapper->to
          );
      foreach my $mapped_coord (@mapped_coords) {
      ## $mapped_coord refer to reference_slice
        if ($mapped_coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
          if ($alignment_coord->strand == 1) {
            $aligned_strand = 1;
            $aligned_start = $mapped_coord->start if (!$aligned_start);
            $aligned_end = $mapped_coord->end;
          } else {
            $aligned_strand = -1;
            $aligned_start = $mapped_coord->start;
            $aligned_end = $mapped_coord->end if (!$aligned_end);
          }
          my $num = $mapped_coord->end - $mapped_coord->start + 1;
          $aligned_cigar .= $num if ($num > 1);
          $aligned_cigar .= "M" if ($num);
        } else {
          my $num = $mapped_coord->end - $mapped_coord->start + 1;
          $aligned_cigar .= $num if ($num > 1);
          $aligned_cigar .= "I" if ($num);
        }
      }
    }
  }

  if ($aligned_strand == 0) {
    ## the whole sequence maps on a gap
    $self->{start} = undef;
    $self->{end} = undef;
    $self->{strand} = undef;
    return $self;
  }

  ## Set coordinates on "slice" coordinates
  $self->start($aligned_start - $slice->start + 1);
  $self->end($aligned_end - $slice->start + 1);
  $self->strand($aligned_strand);
  $self->cigar_line($aligned_cigar);

  if ($self->start > $slice->length or $self->end < 1) {
    $self->{start} = undef;
    $self->{end} = undef;
    $self->{strand} = undef;
    return $self;
  }

  return $self;
}


=head2 exon

  Arg[1]     : (optional) Bio::EnsEMBL::Exon $original_exon
  Example    : $align_exon->exon($original_exon);
  Example    : $start = $align_exon->start();
  Description: Get/set the attribute start. This method is overloaded in order to
               return the starting postion on the AlignSlice instead of the
               original one. Original starting position may be retrieved using
               the SUPER::start() method or the orginal_start() method
  Returntype : Bio::EnsEMBL::Exon object
  Exceptions : 

=cut

sub exon {
  my ($self, $exon) = @_;

  if (defined($exon)) {
    $self->{'exon'} = $exon;
    $self->stable_id($exon->stable_id) if (defined($exon->stable_id));
  }

  return $self->{'exon'};
}


=head2 cigar_line

  Arg[1]     : (optional) string $cigar_line
  Example    : $align_exon->cigar_line($cigar_line);
  Example    : $cigar_line = $align_exon->cigar_line();
  Description: Get/set the attribute cigar_line.
  Returntype : string
  Exceptions : none
  Caller     : object->methodname

=cut

sub cigar_line {
  my ($self, $cigar_line) = @_;

  if (defined($cigar_line)) {
    $self->{'cigar_line'} = $cigar_line;
  }

  return $self->{'cigar_line'};
}


sub get_aligned_start {
  my ($self) = @_;

  my $cigar_line = $self->cigar_line;
  if (defined($cigar_line)) {
    my @cig = ( $cigar_line =~ /(\d*[GMDI])/g );
    my $cigType = substr( $cig[0], -1, 1 );
    my $cigCount = substr( $cig[0], 0 ,-1 );
    $cigCount = 1 unless ($cigCount =~ /^\d+$/);
    next if ($cigCount == 0);

    if ($cigType eq "I") {
      return (1 + $cigCount);
    } else {
      return 1;
    }
  }

  return undef;
}


sub get_aligned_end {
  my ($self) = @_;

  my $cigar_line = $self->cigar_line;
  if (defined($cigar_line)) {
    my @cig = ( $cigar_line =~ /(\d*[GMDI])/g );
    my $cigType = substr( $cig[-1], -1, 1 );
    my $cigCount = substr( $cig[-1], 0 ,-1 );
    $cigCount = 1 unless ($cigCount =~ /^\d+$/);
    next if ($cigCount == 0);

    if ($cigType eq "I") {
      return ($self->exon->end - $self->exon->start + 1 - $cigCount);
    } else {
      return ($self->exon->end - $self->exon->start + 1);
    }
  }

  return undef;
}


=head2 seq

  Arg [1]    : none
  Example    : my $seq_str = $exon->seq->seq;
  Description: Retrieves the dna sequence of this Exon.
               Returned in a Bio::Seq object.  Note that the sequence may
               include UTRs (or even be entirely UTR).
  Returntype : Bio::Seq or undef
  Exceptions : warning if argument passed,
               warning if exon does not have attatched slice
               warning if exon strand is not defined (or 0)
  Caller     : general

=cut

sub seq {
  my ($self, $seq) = @_;

  if (defined($seq)) {
    $self->{'_seq_cache'} = $seq->seq();
  }

  ## Use _template_seq if defined. It is a concatenation of several original
  ## exon sequences and is produced during the merging of align_exons.
  if(!defined($self->{'_seq_cache'})) {
    my $seq = &_get_aligned_sequence_from_original_sequence_and_cigar_line(
        ($self->{'_template_seq'} or $self->exon->seq->seq),
        $self->cigar_line,
        "ref"
    );
    $self->{'_seq_cache'} = $seq;
  }

  return Bio::Seq->new(
          -seq => $self->{'_seq_cache'},
          -id => $self->stable_id,
          -moltype => 'dna',
          -alphabet => 'dna',
      );
}


=head2 append_Exon

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub append_Exon {
  my ($self, $exon, $gap_length) = @_;

  $self->seq(new Bio::Seq(-seq =>
          $self->seq->seq.("-"x$gap_length).$exon->seq->seq));
  
  ## As it is possible to merge two partially repeated parts of an Exon,
  ## the merging is done by concatenating both cigar_lines with the right
  ## number of gaps in the middle. The underlaying sequence must be lengthen
  ## accordingly. This is stored in the _template_seq private attribute
  if (defined($self->{'_template_seq'})) {
    $self->{'_template_seq'} .= $self->exon->seq->seq
  } else {
    $self->{'_template_seq'} = $self->exon->seq->seq x 2;
  }

  if ($gap_length) {
    $gap_length = "" if ($gap_length == 1);
    $self->cigar_line(
        $self->cigar_line.
        $gap_length."D".
        $exon->cigar_line);
  } else {
    $self->cigar_line(
        $self->cigar_line.
        $exon->cigar_line);
  }

  return $self;
}


=head2 prepend_Exon

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub prepend_Exon {
  my ($self, $exon, $gap_length) = @_;

  $self->seq(new Bio::Seq(-seq =>
          $exon->seq->seq.("-"x$gap_length).$self->seq->seq));

  ## As it is possible to merge two partially repeated parts of an Exon,
  ## the merging is done by concatenating both cigar_lines with the right
  ## number of gaps in the middle. The underlaying sequence must be lengthen
  ## accordingly. This is stored in the _template_seq private attribute
  if (defined($self->{'_template_seq'})) {
    $self->{'_template_seq'} .= $self->exon->seq->seq
  } else {
    $self->{'_template_seq'} = $self->exon->seq->seq x 2;
  }

  if ($gap_length) {
    $gap_length = "" if ($gap_length == 1);
    $self->cigar_line(
        $exon->cigar_line.
        $gap_length."D".
        $self->cigar_line);
  } else {
    $self->cigar_line(
        $exon->cigar_line.
        $self->cigar_line);
  }

  return $self;
}


=head2 _get_aligned_sequence_from_original_sequence_and_cigar_line

  Arg [1]    : string $original_sequence
  Arg [1]    : string $cigar_line
  Example    : $aligned_sequence = _get_aligned_sequence_from_original_sequence_and_cigar_line(
                   "CGTAACTGATGTTA", "3MD8M2D3M")
  Description: get gapped sequence from original one and cigar line
  Returntype : string $aligned_sequence
  Exceptions : thrown if cigar_line does not match sequence length
  Caller     : methodname

=cut

sub _get_aligned_sequence_from_original_sequence_and_cigar_line {
  my ($original_sequence, $cigar_line, $mode) = @_;
  my $aligned_sequence = "";
  $mode ||= "";

  return undef if (!$original_sequence or !$cigar_line);

  my $seq_pos = 0;

  my @cig = ( $cigar_line =~ /(\d*[GMDI])/g );
  for my $cigElem ( @cig ) {
    my $cigType = substr( $cigElem, -1, 1 );
    my $cigCount = substr( $cigElem, 0 ,-1 );
    $cigCount = 1 unless ($cigCount =~ /^\d+$/);

    if( $cigType eq "M" ) {
      $aligned_sequence .= substr($original_sequence, $seq_pos, $cigCount);
      $seq_pos += $cigCount;
    } elsif( $cigType eq "G" || $cigType eq "D") {
      $aligned_sequence .=  "-" x $cigCount;
    } elsif( $cigType eq "I") {
      $aligned_sequence .=  "-" x $cigCount if ($mode ne "ref");
      $seq_pos += $cigCount;
    }
  }
  throw("Cigar line ($seq_pos) does not match sequence lenght (".length($original_sequence).")") if ($seq_pos != length($original_sequence));

  return $aligned_sequence;
}

1;
