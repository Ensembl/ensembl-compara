=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=cut

=head1 NAME

AlignedMember - DESCRIPTION of Object

=head1 DESCRIPTION

A subclass of Member which extends it to allow it to be aligned with other AlignedMember objects.
General enough to allow for global, local, pair-wise and multiple alignments.
At the moment used primarily in NestedSet Tree data-structure, but there are plans to extend its usage.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::AlignedMember
  +- Bio::EnsEMBL::Compara::Member

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::AlignedMember;

use strict;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::Member');

##################################
# overriden superclass methods
##################################

=head2 copy

  Arg [1]     : none
  Example     : $copy = $aligned_member->copy();
  Description : Creates a new AlignedMember object from an existing one
  Returntype  : Bio::EnsEMBL::Compara::AlignedMember
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = @_ ? shift : {};     # extending or from scratch?
               $self->SUPER::copy($mycopy);
  bless $mycopy, 'Bio::EnsEMBL::Compara::AlignedMember';

  $mycopy->cigar_line($self->cigar_line);
  $mycopy->cigar_start($self->cigar_start);
  $mycopy->cigar_end($self->cigar_end);
  $mycopy->perc_cov($self->perc_cov);
  $mycopy->perc_id($self->perc_id);
  $mycopy->perc_pos($self->perc_pos);
  $mycopy->method_link_species_set_id($self->method_link_species_set_id);
  
  return $mycopy;
}


#####################################################


=head2 cigar_line

  Arg [1]     : (optional) $cigar_line
  Example     : $object->cigar_line($cigar_line);
  Example     : $cigar_line = $object->cigar_line();
  Description : Getter/setter for the cigar_line attribute. The cigar line
                represents the modifications that are required to go from
                the original sequence to the aligned sequence. In particular,
                it shows the location of the gaps in the sequence. The cigar
                line is built with a series of numbers and characters where
                the number represents the number of positions in the mode
                defined by the next charcater. When the number is 1, it can be
                omitted. For example, the cigar line '23MD4M' means that there
                are 23 matches or mismatches, then 1 deletion (gap) and then
                another 4 matches or mismatches. The aligned sequence is
                obtained by inserting 1 gap at the right location.
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub cigar_line {
  my $self = shift;
  $self->{'_cigar_line'} = shift if(@_);
  return $self->{'_cigar_line'};
}


=head2 cigar_start

  Arg [1]     : (optional) $cigar_start
  Example     : $object->cigar_start($cigar_start);
  Example     : $cigar_start = $object->cigar_start();
  Description : Getter/setter for the cigar_start attribute. For non-global
                alignments, this represent the starting point of the local
                alignment.
                Currently the data provided as AlignedMembers (leaves of the
                GeneTree) are obtained using global alignments and the
                cigar_start is always undefined.
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub cigar_start {
  my $self = shift;
  $self->{'_cigar_start'} = shift if(@_);
  return $self->{'_cigar_start'};
}


=head2 cigar_end

  Arg [1]     : (optional) $cigar_end
  Example     : $object->cigar_end($cigar_end);
  Example     : $cigar_end = $object->cigar_end();
  Description : Getter/setter for the cigar_end attribute. For non-global
                alignments, this represent the ending point of the local
                alignment.
                Currently the data provided as AlignedMembers (leaves of the
                GeneTree) are obtained using global alignments and the
                cigar_end is always undefined.
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub cigar_end {
  my $self = shift;
  $self->{'_cigar_end'} = shift if(@_);
  return $self->{'_cigar_end'};
}


=head2 perc_cov

  Arg [1]     : (optional) $perc_cov
  Example     : $object->perc_cov($perc_cov);
  Example     : $perc_cov = $object->perc_cov();
  Description : Getter/setter for the perc_cov attribute. For non-global
                alignments, this represent the coverage of the alignment in
                percentage of the total length of the sequence.
                Currently the data provided as AlignedMembers (leaves of the
                GeneTree) are obtained using global alignments (the whole
                sequence is always included) and the perc_cov is always undefined.
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub perc_cov {
  my $self = shift;
  $self->{'perc_cov'} = shift if(@_);
  return $self->{'perc_cov'};
}


=head2 perc_id

  Arg [1]     : (optional) $perc_id
  Example     : $object->perc_id($perc_id);
  Example     : $perc_id = $object->perc_id();
  Description : Getter/setter for the perc_id attribute. This is generally
                used for pairwise relationships. The percentage identity
                reprensents the number of positions that are identical in
                the alignment in both sequences.
                Currently the data provided as AlignedMembers (leaves of the
                GeneTree) are obtained using multiple alignments and the
                perc_id is always undefined.
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub perc_id {
  my $self = shift;
  $self->{'perc_id'} = shift if(@_);
  return $self->{'perc_id'};
}


=head2 perc_pos

  Arg [1]     : (optional) $perc_pos
  Example     : $object->perc_pos($perc_pos);
  Example     : $perc_pos = $object->perc_pos();
  Description : Getter/setter for the perc_pos attribute. This is generally
                used for pairwise relationships. The percentage positivity
                reprensents the number of positions that are positive in
                the alignment in both sequences. Currently, this is calculated
                for protein sequences using the BLOSUM62 scoring matrix.
                Currently the data provided as AlignedMembers (leaves of the
                GeneTree) are obtained using multiple alignments and the
                perc_cov is always undefined.
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub perc_pos {
  my $self = shift;
  $self->{'perc_pos'} = shift if(@_);
  return $self->{'perc_pos'};
}


=head2 method_link_species_set_id

  Arg [1]     : (optional) $method_link_species_set_id
  Example     : $object->method_link_species_set_id($method_link_species_set_id);
  Example     : $method_link_species_set_id = $object->method_link_species_set_id();
  Description : Getter/setter for the method_link_species_set_id attribute. Please,
                refer to the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet module
                for more information on the method_link_species_set_id.
  Returntype  : int
  Exceptions  : Returns 0 if the method_link_species_set_id is not defined.
  Caller      : general
  Status      : Stable

=cut

sub method_link_species_set_id {
  my $self = shift;
  $self->{'method_link_species_set_id'} = shift if(@_);
  $self->{'method_link_species_set_id'} = 0 unless(defined($self->{'method_link_species_set_id'}));
  return $self->{'method_link_species_set_id'};
}


=head2 alignment_string

  Arg [1]     : (optional) bool $exon_cased
  Example     : my $alignment_string = $object->alignment_string();
  Example     : my $alignment_string = $object->alignment_string(1);
  Description : Returns the aligned sequence for this object. For sequences
                split in exons, the $exon_cased flag permits to request
                that each exon is represented in alternative upper and lower
                case.
                For local alignments, when the alignment does not cover the
                whole protein, only the part of the sequence in the alignemnt
                is returned. Currently only global alignments are provided.
                Therefore the alignment_string always returns the whole aligned
                sequence.
  Returntype  : string
  Exceptions  : throws if the cigar_line is not defined for this object.
  Caller      : general
  Status      : Stable

=cut

sub alignment_string {
  my $self = shift;
  my $exon_cased = shift;

  unless (defined $self->cigar_line && $self->cigar_line ne "") {
    throw("To get an alignment_string, the cigar_line needs to be define\n");
  }

  # Use different keys for exon-cased and non exon-cased sequences
  my $key = 'alignment_string';
  if ($exon_cased) {
    $key = 'alignment_string_cased';
  } elsif (defined $self->{'alignment_string_cased'} and !defined($self->{'alignment_string'})) {
    # non exon-cased sequence can be easily obtained from the exon-cased one.
    $self->{'alignment_string'} = uc($self->{'alignment_string_cased'})
  }

  unless (defined $self->{$key}) {
    my $sequence;
    if ($exon_cased) {
      $sequence = $self->sequence_exon_cased;
    } else {
      $sequence = $self->sequence;
    }
    if (defined $self->cigar_start || defined $self->cigar_end) {
      unless (defined $self->cigar_start && defined $self->cigar_end) {
        throw("both cigar_start and cigar_end should be defined");
      }
      my $offset = $self->cigar_start - 1;
      my $length = $self->cigar_end - $self->cigar_start + 1;
      $sequence = substr($sequence, $offset, $length);
    }

    my $cigar_line = $self->cigar_line;
    $cigar_line =~ s/([MD])/$1 /g;

    my @cigar_segments = split " ",$cigar_line;
    my $alignment_string = "";
    my $seq_start = 0;
    foreach my $segment (@cigar_segments) {
      if ($segment =~ /^(\d*)D$/) {
        my $length = $1;
        $length = 1 if ($length eq "");
        $alignment_string .= "-" x $length;
      } elsif ($segment =~ /^(\d*)M$/) {
        my $length = $1;
        $length = 1 if ($length eq "");
        $alignment_string .= substr($sequence,$seq_start,$length);
        $seq_start += $length;
      }
    }
    $self->{$key} = $alignment_string;
  }

  return $self->{$key};
}


=head2 alignment_string_bounded

  Arg [1]     : none
  Example     : my $alignment_string_bounded = $object->alignment_string_bounded();
  Description : Returns the aligned sequence for this object with padding characters
                representing the introns.
  Returntype  : string
  Exceptions  : throws if the cigar_line is not defined for this object or if the
                cigar_start or cigar_end are defined.
  Caller      : general
  Status      : Stable

=cut

sub alignment_string_bounded {
  my $self = shift;

  unless (defined $self->cigar_line && $self->cigar_line ne "") {
    throw("To get an alignment_string, the cigar_line needs to be define\n");
  }
  unless (defined $self->{'alignment_string_bounded'}) {
    my $sequence_exon_bounded = $self->sequence_exon_bounded;
    if (defined $self->cigar_start || defined $self->cigar_end) {
      throw("method doesnt implement defined cigar_start and cigar_end");
    }
    $sequence_exon_bounded =~ s/b|o|j/\ /g;
    my $cigar_line = $self->cigar_line;
    $cigar_line =~ s/([MD])/$1 /g;

    my @cigar_segments = split " ",$cigar_line;
    my $alignment_string_bounded = "";
    my $seq_start = 0;
    my $exon_count = 1;
    foreach my $segment (@cigar_segments) {
      if ($segment =~ /^(\d*)D$/) {
        my $length = $1;
        $length = 1 if ($length eq "");
        $alignment_string_bounded .= "-" x $length;
      } elsif ($segment =~ /^(\d*)M$/) {
        my $length = $1;
        $length = 1 if ($length eq "");
        my $substring = substr($sequence_exon_bounded,$seq_start,$length);
        if ($substring =~ /\ /) {
          my $num_boundaries = $substring =~ s/(\ )/$1/g;
          $length += $num_boundaries;
          $substring = substr($sequence_exon_bounded,$seq_start,$length);
        }
        $alignment_string_bounded .= $substring;
        $seq_start += $length;
      }
    }
    $self->{'alignment_string_bounded'} = $alignment_string_bounded;
  }

  return $self->{'alignment_string_bounded'};
}


=head2 cdna_alignment_string

  Arg [1]    : none
  Example    : my $cdna_alignment = $aligned_member->cdna_alignment_string();
  Description: Converts the peptide alignment string to a cdna alignment
               string.  This only works for EnsEMBL peptides whose cdna can
               be retrieved from the attached core databse.
               If the cdna cannot be retrieved undef is returned and a
               warning is thrown.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub cdna_alignment_string {
  my $self = shift;

  unless (defined $self->{'cdna_alignment_string'}) {

    my $cdna;
    eval { $cdna = $self->sequence_cds;};
    if ($@) {
      throw("can't connect to CORE to get transcript and cdna for "
            . "genome_db_id:" . $self->genome_db_id )
        unless($self->transcript);
      $cdna = $self->transcript->translateable_seq;
    }

    if (defined $self->cigar_start || defined $self->cigar_end) {
      unless (defined $self->cigar_start && defined $self->cigar_end) {
        throw("both cigar_start and cigar_end should be defined");
      }
      my $offset = $self->cigar_start * 3 - 3;
      my $length = ($self->cigar_end - $self->cigar_start + 1) * 3;
      $cdna = substr($cdna, $offset, $length);
    }

    my $cdna_len = length($cdna);
    my $start = 0;
    my $cdna_align_string = '';

    # foreach my $pep (split(//, $self->alignment_string)) { # Speed up below
    my $alignment_string = $self->alignment_string;
    foreach my $pep (unpack("A1" x length($alignment_string), $alignment_string)) {
      if($pep eq '-') {
        $cdna_align_string .= '--- ';
      } else {
        my $codon = substr($cdna, $start, 3);
        unless (length($codon) == 3) {
          # sometimes the last codon contains only 1 or 2 nucleotides.
          # making sure that it has 3 by adding as many Ns as necessary
          $codon .= 'N' x (3 - length($codon));
        }
        $cdna_align_string .= $codon . ' ';
        $start += 3;
      }
    }
    $self->{'cdna_alignment_string'} = $cdna_align_string
  }
  
  return $self->{'cdna_alignment_string'};
}


1;
