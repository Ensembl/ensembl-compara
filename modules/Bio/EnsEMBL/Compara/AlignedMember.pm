=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
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

A subclass of SeqMember which extends it to allow it to be aligned with other AlignedMember objects.
General enough to allow for global, local, pair-wise and multiple alignments.
At the moment used primarily in NestedSet Tree data-structure, but there are plans to extend its usage.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::AlignedMember
  +- Bio::EnsEMBL::Compara::SeqMember

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::AlignedMember;

use strict;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::SeqMember');


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

  # The following does not Work if the initial object is only a Member
  if (UNIVERSAL::isa($self, 'Bio::EnsEMBL::Compara::AlignedMember')) {
    $mycopy->cigar_line($self->cigar_line);
    $mycopy->cigar_start($self->cigar_start);
    $mycopy->cigar_end($self->cigar_end);
    $mycopy->perc_cov($self->perc_cov);
    $mycopy->perc_id($self->perc_id);
    $mycopy->perc_pos($self->perc_pos);
    $mycopy->method_link_species_set_id($self->method_link_species_set_id);
  }

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


sub set {
    my $self = shift;
    return $self->{'set'};
}


#####################
# Alignment strings #
#####################

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
  Exceptions  : see _compose_sequence_with_cigar
  Caller      : general
  Status      : Stable

=cut

sub alignment_string {
  my $self = shift;
  my $exon_cased = shift;

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
    $self->{$key} = $self->_compose_sequence_with_cigar($sequence);
  }

  return $self->{$key};
}

sub alignment_string_generic {
  my $self = shift;
  my $seq_type = shift;

  my $key = 'alignment_string';
  if ($seq_type) {
    $key .= "_$seq_type";
  }

  unless (defined $self->{$key}) {
    my $sequence;
    if ($seq_type) {
      $sequence = $self->get_other_sequence($seq_type);
    } else {
      $sequence = $self->sequence;
    }
    $self->{$key} = $self->_compose_sequence_with_cigar($sequence);
  }

  return $self->{$key};
}


=head2 alignment_string_bounded

  Arg [1]     : none
  Example     : my $alignment_string_bounded = $object->alignment_string_bounded();
  Description : Returns the aligned sequence for this object with padding characters
                representing the introns.
  Returntype  : string
  Exceptions  : see _compose_sequence_with_cigar
  Caller      : general
  Status      : Stable

=cut

sub alignment_string_bounded {
  my $self = shift;

  unless (defined $self->{'alignment_string_bounded'}) {
    my $sequence_exon_bounded = $self->sequence_exon_bounded;
    $sequence_exon_bounded =~ s/b|o|j/\ /g;
    $self->{'alignment_string_bounded'} = $self->_compose_sequence_with_cigar($sequence_exon_bounded);
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
  Exceptions : see _compose_sequence_with_cigar
  Caller     : general

=cut

sub cdna_alignment_string {
  my $self = shift;

  # For ncRNAs, the default alignment string is already at the DNA level
  return $self->alignment_string() if $self->source_name eq 'ENSEMBLTRANS';

  unless (defined $self->{'cdna_alignment_string'}) {

    my $cdna;
    eval { $cdna = $self->sequence_cds;};
    if ($@) {
      throw("can't connect to CORE to get transcript and cdna for "
            . "genome_db_id:" . $self->genome_db_id )
        unless($self->get_Transcript);
      $cdna = $self->get_Transcript->translateable_seq;
    }

    $self->{'cdna_alignment_string'} = $self->_compose_sequence_with_cigar($cdna, 3);
  }
  
  return $self->{'cdna_alignment_string'};
}


=head2 _compose_sequence_with_cigar

  Arg [1]    : String $sequence
  Arg [2]    : Integer $expansion_factor (default: 1)
  Example    : my $alignment_string = $aligned_member->_compose_sequence_with_cigar($aligned_member->sequence_cds, 3)
  Description: Converts the given sequence into an alignment string
               by composing it with the cigar_line. $expansion_factor
               can be set to accomodate CDS sequences
  Returntype : string
  Exceptions : throws if the cigar_line is not defined for this object or if the
                cigar_start or cigar_end are defined.
  Caller     : internal

=cut

sub _compose_sequence_with_cigar {
    my $self = shift;
    my $sequence = shift;
    my $expansion_factor = shift || 1;

    unless (defined $self->cigar_line && $self->cigar_line ne "") {
        throw("To get an alignment_string, the cigar_line needs to be define\n");
    }

    # cigar_start and cigar_end
    if (defined $self->cigar_start || defined $self->cigar_end) {
        unless (defined $self->cigar_start && defined $self->cigar_end) {
            throw("both cigar_start and cigar_end should be defined");
        }
        my $offset = ($self->cigar_start - 1) * $expansion_factor;
        my $length = ($self->cigar_end - $self->cigar_start + 1) * $expansion_factor;
        $sequence = substr($sequence, $offset, $length);
    }

    my $cigar_line = $self->cigar_line;
    $cigar_line =~ s/([MD])/$1 /g;
    my @cigar_segments = split " ", $cigar_line;
    my $alignment_string = "";
    my $seq_start = 0;
    foreach my $segment (@cigar_segments) {
        if ($segment =~ /^(\d*)D$/) {
            
            # Gap
            my $length = $1 || 1;
            $alignment_string .= "-" x ($length * $expansion_factor);

        } elsif ($segment =~ /^(\d*)M$/) {

            # Match
            my $length = $1 || 1;
            $length *= $expansion_factor;
            my $substring = substr($sequence,$seq_start,$length);
            if ($substring =~ /\ /) {
                my $num_boundaries = $substring =~ s/(\ )/$1/g;
                $length += $num_boundaries;
                $substring = substr($sequence,$seq_start,$length);
            }
            if (length($substring) < $length) {
                $substring .= ('N' x ($length - length($substring)));
            }
            $alignment_string .= $substring;
            $seq_start += $length;
        }
    }
    return $alignment_string;
}


1;
