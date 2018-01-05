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

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::AlignedMember

=head1 DESCRIPTION

A subclass of SeqMember which extends it to allow it to be aligned with other AlignedMember objects.
General enough to allow for global, local, pair-wise and multiple alignments.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::AlignedMember
  `- Bio::EnsEMBL::Compara::SeqMember

=head1 SYNOPSIS

The alignment of this SeqMember:
 - alignment_string()
 - cigar_line()
 - cigar_start()   # always returns undef
 - cigar_end()     # always returns undef

Statistics about the alignment of this SeqMember:
 - perc_cov()
 - perc_id()
 - perc_pos()
 - num_matches()
 - num_pos_matches()
 - num_mismatches()
 - update_alignment_stats()    # to update the above counters

NB: Only Homology::perc_*() are pre-computed. To query num_*() on an Homology
object, or any counter on a GeneTree / Family object, first initialize them with
update_alignment_stats(). The latter is also useful to get the statistics on a
different sequence type (e.g. the CDS sequence instead of the protein sequence).

Links to the AlignedMemberSet:
 - set()
 - method_link_species_set_id()


=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::AlignedMember;

use strict;
use warnings;

use feature qw(switch);

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Utils::Cigars;

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
  
  my $mycopy = $self->SUPER::copy(@_);

  # The following does not Work if the initial object is only a Member
  if (UNIVERSAL::isa($self, 'Bio::EnsEMBL::Compara::AlignedMember')) {
    $mycopy->cigar_line($self->cigar_line);
    $mycopy->cigar_start($self->cigar_start);
    $mycopy->cigar_end($self->cigar_end);
    $mycopy->perc_cov($self->perc_cov);
    $mycopy->perc_id($self->perc_id);
    $mycopy->perc_pos($self->perc_pos);
    $mycopy->num_matches($self->num_matches);
    $mycopy->num_pos_matches($self->num_pos_matches);
    $mycopy->num_mismatches($self->num_mismatches);
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
  if (@_) {
    my $cigar = shift;
    if ($cigar and $self->{'_cigar_line'} and $self->{'_cigar_line'} ne $cigar) {
      foreach my $k (keys %$self) {
        delete $self->{$k} if $k =~ /alignment_string/;
      }
    }
    $self->{'_cigar_line'} = $cigar;
  }
  return $self->{'_cigar_line'};
}



=head2 get_cigar_breakout

  Arg [1]     : $cigar_line
  Example     : %cigar_breakout = $object->get_cigar_breakout($cigar_line);
  Description : Getter for the cigar_line breackout. It returns the quantities
                of matches or mismatches (M), deletions (D) and insertions (I).

  Returntype  : hash
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_cigar_breakout{
  my $self = shift;
  return Bio::EnsEMBL::Compara::Utils::Cigars::get_cigar_breakout($self->{'_cigar_line'});
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
  Description : Getter/setter for the perc_cov attribute. This represents the number
                of positions in the sequence that are aligned to a non-gap in the
                other sequence.
                perc_cov is by default only populated for homologies, but can be
                computed on gene-tree leaves and family members by calling
                update_alignment_stats() on the GeneTree / Family object.
  Returntype  : float
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
  Description : Getter/setter for the perc_id attribute. This represents the number
                of identical positions between the sequences
                perc_id is by default only populated for homologies, but can be
                computed on gene-tree leaves and family members by calling
                update_alignment_stats() on the GeneTree / Family object.
  Returntype  : float
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
  Description : Getter/setter for the perc_pos attribute. This represents the number
                of positions that are positive in the alignment in both sequences.
                Currently, this is calculated for protein sequences using the BLOSUM62
                scoring matrix.
                perc_pos is by default only populated for homologies, but can be
                computed on gene-tree leaves and family members by calling
                update_alignment_stats() on the GeneTree / Family object.
  Returntype  : float
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub perc_pos {
  my $self = shift;
  $self->{'perc_pos'} = shift if(@_);
  return $self->{'perc_pos'};
}


=head2 num_matches

  Example     : my $num_matches = $aligned_member->num_matches();
  Example     : $aligned_member->num_matches($num_matches);
  Description : Getter/Setter for the number of matches in the alignment
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub num_matches {
    my $self = shift;
    $self->{'_num_matches'} = shift if @_;
    return $self->{'_num_matches'};
}


=head2 num_pos_matches

  Example     : my $num_pos_matches = $aligned_member->num_pos_matches();
  Example     : $aligned_member->num_pos_matches($num_pos_matches);
  Description : Getter/Setter for the number of positive matches in the
                alignment (only for protein sequences, using the BLOSUM62
                scoring matrix)
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub num_pos_matches {
    my $self = shift;
    $self->{'_num_pos_matches'} = shift if @_;
    return $self->{'_num_pos_matches'};
}


=head2 num_mismatches

  Example     : my $num_mismatches = $aligned_member->num_mismatches();
  Example     : $aligned_member->num_mismatches($num_mismatches);
  Description : Getter/Setter for the number of mismatches in the alignment
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub num_mismatches {
    my $self = shift;
    $self->{'_num_mismatches'} = shift if @_;
    return $self->{'_num_mismatches'};
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

  Arg [1]     : (optional) string $seq_type
                  Identifier of the sequence that should be used instead of
                  the default protein / ncRNA sequence
  Example     : my $alignment_string = $object->alignment_string();
  Example     : my $alignment_string_cased = $object->alignment_string('exon_cased');
  Description : Returns the aligned sequence for this object. For sequences
                split in exons, the 'exon_cased' seq_type permits to request
                that each exon is represented in alternative upper and lower
                case, whilst the 'exon_bounded' seq_type adds whitespaces
                between the exons.
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
    my $seq_type = shift;

    my $key = 'alignment_string';
    if ($seq_type) {
        $key .= "_$seq_type";

    } else {
        if ((not defined $self->{$key}) and (defined $self->{$key.'_exon_cased'})) {
            # non exon-cased sequence can be easily obtained from the exon-cased one.
            $self->{$key} = uc($self->{$key.'_exon_cased'});
        }
    }

    if (not defined $self->{$key}) {
        my $sequence = $self->other_sequence($seq_type);
        $sequence =~ s/b|o|j/\ /g if $seq_type and ($seq_type eq 'exon_bounded');
        my $expansion_factor = $self->{_expansion_factor};
        $expansion_factor ||= ($seq_type and ($seq_type eq 'cds')) ? 3 : 1;
        $self->{$key} = $self->_compose_sequence_with_cigar($sequence, $expansion_factor);
    }

    return $self->{$key};
}


=head2 _compose_sequence_with_cigar

  Arg [1]    : String $sequence
  Arg [2]    : Integer $expansion_factor (default: 1)
  Example    : my $alignment_string = $aligned_member->_compose_sequence_with_cigar($aligned_member->other_sequence('cds'), 3)
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
        throw("To get an alignment_string, the cigar_line needs to be define. Please check '".$self->stable_id."'\n");
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

    return Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar($sequence, $self->cigar_line, $expansion_factor);
}


1;
