#
# Ensembl module for Bio::EnsEMBL::Compara::AlignSlice::Exon
#
# Original author: Javier Herrero <jherrero@ebi.ac.uk>
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

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

=item attribute

this one

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


package Bio::EnsEMBL::Compara::AlignSlice::Exon;

use strict;
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
  Inheritance: Calls new() method from SUPER class.
  Returntype : Bio::EnsEMBL::Compara::AlignSlice::Exon object
  Exceptions : return undef if 

=cut

sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args);

  my ($exon, $align_slice, $from_mapper, $to_mapper) =
      rearrange([qw(
          EXON ALIGN_SLICE FROM_MAPPER TO_MAPPER
      )], @args);

  $self->exon($exon) if (defined ($exon));
#   $self->genomic_align($genomic_align) if (defined($genomic_align));
#   $self->from_genomic_align_id($from_genomic_align_id) if (defined($from_genomic_align_id));
#   $self->to_genomic_align_id($to_genomic_align_id) if (defined($to_genomic_align_id));
  $self->slice($align_slice) if (defined($align_slice));

  return $self->map_Exon_on_Slice($from_mapper, $to_mapper);
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

=head2 map_Exon_on_Slice

  Arg[1]     : none
  Example    : $align_exon->slice($reference_slice);
  Example    : $reference_slice = $align_exon->slice();
  Description: Get/set the attribute slice. This method is overloaded in order
               to map original coordinates onto the reference Slice.
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : 
  Caller     : new

=cut

sub map_Exon_on_Slice {
  my ($self, $from_mapper, $to_mapper) = @_;
  my $original_exon = $self->exon;
  my $slice = $self->slice;

  if (!defined($slice) or !defined($original_exon) or !defined($from_mapper) or !defined($to_mapper)) {
    warn("[$self] cannot be mapped on reference Slice");
    return undef;
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
          my $length = $alignment_coord->start - $last_alignment_coord_end - 1;
          $aligned_cigar .= $length if ($length>1);
          $aligned_cigar .= "D";
        }
        $last_alignment_coord_end = $alignment_coord->end;
        $global_alignment_coord_start = $alignment_coord->start if (!$global_alignment_coord_start);
        $global_alignment_coord_end = $alignment_coord->end;
      } else {
        if ($last_alignment_coord_start) {
          my $length = $last_alignment_coord_start - $alignment_coord->end - 1;
          $aligned_cigar .= $length if ($length>1);
          $aligned_cigar .= "D";
        }
        $last_alignment_coord_start = $alignment_coord->start;
        $global_alignment_coord_end = $alignment_coord->end if (!$global_alignment_coord_end);
        $global_alignment_coord_start = $alignment_coord->start;
      }
    } else {
      my $length = $alignment_coord->length;
      $aligned_cigar .= $length if ($length>1);
      $aligned_cigar .= "I";
      next;
    }

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
        $aligned_cigar .= "M";
      } else {
        my $num = $mapped_coord->end - $mapped_coord->start + 1;
        $aligned_cigar .= $num if ($num > 1);
        $aligned_cigar .= "I";
      }
    }
  }

  if ($aligned_strand == 0) {
    ## the whole sequence maps on a gap
    return undef;
  }

  $aligned_start += 1 - $slice->start;
  $aligned_end += 1 - $slice->start;
  $self->start($aligned_start);
  $self->end($aligned_end);
  $self->strand($aligned_strand);
  $self->cigar_line($aligned_cigar);

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


=head2 genomic_align

  Arg[1]     : [optinal] Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
  Example    : $align_exon->genomic_align($genomic_align);
  Example    : $genomic_align = $align_exon->genomic_align();
  Description: Get/set the attribute genomic_align
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : throw if $genomic_align is not a Bio::EnsEMBL::Compara::GenomicAlign object

=cut

sub genomic_align {
  my ($self, $genomic_align) = @_;

  if (defined($genomic_align)) {
    my $type = "Bio::EnsEMBL::Compara::GenomicAlign";
    throw("[$genomic_align] should be a $type object")
        unless ($genomic_align and ref($genomic_align) and $genomic_align->isa($type));
    $self->{'genomic_align'} = $genomic_align;
  }

  return $self->{'genomic_align'};
}


=head2 from_genomic_align_id

  Arg[1]     : [optinal] integer $from_genomic_align_id
  Example    : $align_exon->from_genomic_align_id($from_genomic_align_id);
  Example    : $from_genomic_align_id= $align_exon->from_genomic_align_id();
  Description: Get/set the attribute from_genomic_align_id
  Returntype : integer
  Exceptions : 

=cut

sub from_genomic_align_id {
  my ($self, $from_genomic_align_id) = @_;

  if (defined($from_genomic_align_id)) {
    $self->{'from_genomic_align_id'} = $from_genomic_align_id;
  }

  return $self->{'from_genomic_align_id'};
}


=head2 to_genomic_align_id

  Arg[1]     : [optinal] integer $to_genomic_align_id
  Example    : $align_exon->to_genomic_align_id($to_genomic_align_id);
  Example    : $to_genomic_align_id= $align_exon->to_genomic_align_id();
  Description: Get/set the attribute to_genomic_align_id
  Returntype : integer
  Exceptions : 

=cut

sub to_genomic_align_id {
  my ($self, $to_genomic_align_id) = @_;

  if (defined($to_genomic_align_id)) {
    $self->{'to_genomic_align_id'} = $to_genomic_align_id;
  }

  return $self->{'to_genomic_align_id'};
}


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
    $cigCount = 1 unless $cigCount;

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
    $cigCount = 1 unless $cigCount;

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

  if(!defined($self->{'_seq_cache'})) {
    my $seq = &_get_aligned_sequence_from_original_sequence_and_cigar_line(
        $self->exon->seq->seq,
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
    $cigCount = 1 unless $cigCount;

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
