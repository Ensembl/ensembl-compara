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

Bio::EnsEMBL::Compara::GenomicAlignGroup - Defines groups of genomic aligned sequences

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::GenomicAlignGroup;
  
  my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup (
          -adaptor => $genomic_align_group_adaptor,
          -genomic_align_array => [$genomic_align1, $genomic_align2...]
      );

SET VALUES
  $genomic_align_group->adaptor($gen_ali_group_adaptor);
  $genomic_align_group->dbID(12);
  $genomic_align_group->genomic_align_array([$genomic_align1, $genomic_align2]);

GET VALUES
  my $genomic_align_group_adaptor = $genomic_align_group->adaptor();
  my $dbID = $genomic_align_group->dbID();
  my $genomic_aligns = $genomic_align_group->genomic_align_array();

=head1 DESCRIPTION

The GenomicAlignGroup object defines groups of alignments.

=head1 OBJECT ATTRIBUTES

=over

=item dbID

corresponds to genomic_align_group.node_id

=item genomic_align_array

listref of Bio::EnsEMBL::Compara::DBSQL::GenomicAlign objects corresponding to this
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroup object

=back

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomicAlignGroup;

use strict;
use warnings;

# Object preamble
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Scalar::Util qw(weaken);

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


=head2 new (CONSTRUCTOR)

  Arg [-DBID] : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]
              : (opt.) Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor $adaptor
                (the adaptor for connecting to the database)
  Arg [-GENOMIC_ALIGN_ARRAY]
              : (opt.) array_ref $genomic_aligns (a reference to the array of
                Bio::EnsEMBL::Compara::GenomicAlign objects corresponding to this
                Bio::EnsEMBL::Compara::GenomicAlignGroup object)
  Example    : my $genomic_align_group =
                   new Bio::EnsEMBL::Compara::GenomicAlignGroup(
                       -adaptor => $genomic_align_group_adaptor,
                       -genomic_align_array => [$genomic_align1, $genomic_align2...]
                   );
  Description: Creates a new GenomicAligngroup object
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroup
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my($class, @args) = @_;
  
  my $self = $class->SUPER::new(@args);       # deal with Storable stuff
    
  my ($genomic_align_array) =
    rearrange([qw(
        GENOMIC_ALIGN_ARRAY)], @args);

  $self->genomic_align_array($genomic_align_array) if (defined($genomic_align_array));

  return $self;
}


=head2 copy

  Arg         : none
  Example     : my $new_gag = $gag->copy()
  Description : Create a copy of this Bio::EnsEMBL::Compara::GenomicAlignGroup
                object
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignGroup
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub copy {
  my $self = shift;
  my $copy;
  $copy->{_original_dbID} = $self->{dbID};

  #This is not a deep copy
  #$copy->{genomic_align_array} = $self->{genomic_align_array};

  my $new_genomic_align_array;
  foreach my $genomic_align (@{$self->{genomic_align_array}}) {
      my $new_ga = $genomic_align->copy;
      push @$new_genomic_align_array, $new_ga;
  }
  $copy->{genomic_align_array} = $new_genomic_align_array;

  return bless $copy, ref($self);
}


=head2 genomic_align_array

  Arg [1]    : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Example    : $genomic_aligns = $genomic_align_group->genomic_align_array();
               $genomic_align_group->genomic_align_array([$genomic_align1, $genomic_align2]);
  Description: get/set for attribute genomic_align_array
  Returntype : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub genomic_align_array {
    my ($self, $genomic_align_array) = @_;
    my $genomic_align_adaptor;

    if (defined $genomic_align_array) {
        foreach my $genomic_align (@$genomic_align_array) {
            throw("$genomic_align is not a Bio::EnsEMBL::Compara::GenomicAlign object") unless ($genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));
        }
        $self->{'genomic_align_array'} = $genomic_align_array;
    } elsif (!defined $self->{'genomic_align_array'}) {
	    warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlignGroup->genomic_align_array."
            ." You have to set it up directly");
    }

    return $self->{'genomic_align_array'};
}

=head2 add_GenomicAlign

  Arg [1]    : Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
  Example    : $genomic_align_block->add_GenomicAlign($genomic_align);
  Description: adds another Bio::EnsEMBL::Compara::GenomicAlign object to the set of
               Bio::EnsEMBL::Compara::GenomicAlign objects in the attribute
               genomic_align_array.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : thrown if wrong argument
  Caller     : general
  Status     : Stable

=cut

sub add_GenomicAlign {
  my ($self, $genomic_align) = @_;

  throw("[$genomic_align] is not a Bio::EnsEMBL::Compara::GenomicAlign object")
      unless ($genomic_align and ref($genomic_align) and
          $genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));
  push(@{$self->{'genomic_align_array'}}, $genomic_align);

  return $genomic_align;
}


=head2 get_all_GenomicAligns

  Arg [1]    : none
  Example    : $genomic_aligns = $genomic_align_block->get_all_GenomicAligns();
  Description: returns the set of Bio::EnsEMBL::Compara::GenomicAlign objects in
               the attribute genomic_align_array.
  Returntype : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub get_all_GenomicAligns {
  my ($self) = @_;

  return ($self->{'genomic_align_array'} or []);
}


=head2 genome_db

  Arg [1]     : -none-
  Example     : $genome_db = $object->genome_db();
  Description : Get the genome_db object from the underlying GenomicAlign objects
  Returntype  : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub genome_db {
  my $self = shift;

  foreach my $genomic_align (@{$self->get_all_GenomicAligns}) {
    return $genomic_align->genome_db if ($genomic_align->genome_db);
  }
  return undef;
}


=head2 dnafrag

  Arg [1]     : -none-
  Example     : $dnafrag = $object->dnafrag();
  Description : Get the dnafrag object from the underlying GenomicAlign objects
  Returntype  : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub dnafrag {
  my $self = shift;
  my $dnafrag;
  foreach my $genomic_align (@{$self->get_all_GenomicAligns}) {
    if (!$dnafrag) {
      $dnafrag = $genomic_align->dnafrag;
    } elsif ($dnafrag != $genomic_align->dnafrag) {
      return bless({name => "Composite"}, "Bio::EnsEMBL::Compara::DnaFrag");
    }
  }
  return $dnafrag;
}


=head2 dnafrag_start

  Arg [1]     : -none-
  Example     : $dnafrag_start = $object->dnafrag_start();
  Description : Get the dnafrag_start value from the underlying GenomicAlign objects
  Returntype  : int
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub dnafrag_start {
  my $self = shift;
  my $dnafrag;
  my $dnafrag_start;
  foreach my $genomic_align (@{$self->get_all_GenomicAligns}) {
    if (!$dnafrag) {
      $dnafrag = $genomic_align->dnafrag;
      $dnafrag_start = $genomic_align->dnafrag_start;
    } elsif ($dnafrag != $genomic_align->dnafrag) {
      return 1;
    } elsif ($genomic_align->dnafrag_start < $dnafrag_start) {
      $dnafrag_start = $genomic_align->dnafrag_start;
    }
  }
  return $dnafrag_start;
}


=head2 dnafrag_end

  Arg [1]     : -none-
  Example     : $dnafrag_end = $object->dnafrag_end();
  Description : Get the dnafrag_end value from the underlying GenomicAlign objects
  Returntype  : int
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub dnafrag_end {
  my $self = shift;
  my $dnafrag;
  my $dnafrag_end;
  foreach my $genomic_align (@{$self->get_all_GenomicAligns}) {
    if (!$dnafrag) {
      $dnafrag = $genomic_align->dnafrag;
      $dnafrag_end = $genomic_align->dnafrag_end;
    } elsif ($dnafrag != $genomic_align->dnafrag) {
      return $genomic_align->length;
    } elsif ($genomic_align->dnafrag_end > $dnafrag_end) {
      $dnafrag_end = $genomic_align->dnafrag_end;
    }
  }
  return $dnafrag_end;
}


=head2 dnafrag_strand

  Arg [1]     : -none-
  Example     : $dnafrag_strand = $object->dnafrag_strand();
  Description : Get the dnafrag_strand value from the underlying GenomicAlign objects
  Returntype  : int
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub dnafrag_strand {
  my $self = shift;
  my $dnafrag_strand;
  foreach my $genomic_align (@{$self->get_all_GenomicAligns}) {
    if (!$dnafrag_strand) {
      $dnafrag_strand = $genomic_align->dnafrag_strand;
    } elsif ($dnafrag_strand != $genomic_align->dnafrag_strand) {
      return 0;
    }
  }
  return $dnafrag_strand;
}


=head2 aligned_sequence

  Arg [1]     : -none-
  Example     : $aligned_sequence = $object->aligned_sequence();
  Description : Get the aligned sequence for this group. When the group
                contains one single sequence, returns its aligned sequence.
                For composite segments, returns the combined aligned seq.
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub aligned_sequence {
  my $self = shift;

  my $aligned_sequence;
  foreach my $this_genomic_align (@{$self->get_all_GenomicAligns}) {
      #print "GAG " . $this_genomic_align->dnafrag->genome_db->name . " " . $this_genomic_align->dnafrag->name . " " . $this_genomic_align->dbID . " " . $this_genomic_align->cigar_line . "\n";

    if (!$aligned_sequence) {
      $aligned_sequence = $this_genomic_align->aligned_sequence;
    } else {
      my $pos = 0;
      foreach my $substr (grep {$_} split(/(\.+)/, $this_genomic_align->aligned_sequence)) {
          #print "   substr $substr\n";
        if ($substr =~ /^\.+$/) {
          $pos += length($substr);
        } else {
          substr($aligned_sequence, $pos, length($substr), $substr);
        }
      }
    }
  }

  return $aligned_sequence;
}

=head2 original_sequence

  Arg [1]     : -none-
  Example     : $original_sequence = $object->original_sequence();
  Description : Get the original sequence for this group. When the group
                contains one single sequence, returns its original sequence.
                For composite segments, returns the combined original seq.
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub original_sequence {
  my $self = shift;

  my $original_sequence;
  foreach my $this_genomic_align (@{$self->get_all_sorted_GenomicAligns}) {
    $original_sequence .= $this_genomic_align->original_sequence;
  }
  return $original_sequence;
}

=head2 get_all_sorted_GenomicAligns

  Arg [1]     : -none-
  Example     : $sorted_genomic_aligns = $object->get_all_sorted_GenomicAligns
  Description: returns the set of sorted Bio::EnsEMBL::Compara::GenomicAlign objects
  Returntype : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub get_all_sorted_GenomicAligns {
  my ($self) = @_;

  my $sorted_genomic_aligns;
  my @list_of_genomic_aligns;

  foreach my $this_genomic_align (@{$self->get_all_GenomicAligns}) {
    #Get the first element of the cigar line
    my ($first_elem) = $this_genomic_align->cigar_line =~ /(\d*[GMDXI])/;
    
    #The first element may not have X if it has been restricted
    if ($first_elem =~ /X/) {
      push @list_of_genomic_aligns, $this_genomic_align;
    } else {
      push @$sorted_genomic_aligns, $this_genomic_align;
    }
  }
  #Sort remaining GenomicAligns base on the X offset of the first element in the cigar line
  foreach my $this_genomic_align (sort _sort_by_cigar @list_of_genomic_aligns) {
     push @$sorted_genomic_aligns, $this_genomic_align;
  }
  return $sorted_genomic_aligns;
}

#Sort by the length of the first X element.
sub _sort_by_cigar {
  my ($a_first_elem) = $a->cigar_line =~ /(\d*)X/;
  my ($b_first_elem) = $b->cigar_line =~ /(\d*)X/;

  return $a_first_elem <=> $b_first_elem;
}

=head2 cigar_line

  Arg [1]     : -none-
  Example     : $cigar_line = $object->cigar_line();
  Description: Get the cigar_line for this group. When the group
                contains one single sequence, returns its cigar_line.
                For composite segments, returns the combined cigar_line.
  Returntype : String
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub cigar_line {
  my ($self) = @_;

  my $prev_seq_length = 0;
  my $final_cigar_line;
  my $last_cigar_elem;
  my @all_cig;

  foreach my $this_genomic_align (@{$self->get_all_sorted_GenomicAligns}) {
    my $cigar_line = $this_genomic_align->cigar_line;
    my @cig = ( $cigar_line =~ /(\d*[GMDXI])/g );

    my ($firstCigCount) = $cig[0] =~/(\d*)X/;

    #May need extra padding between genomic_aligns
    if ($firstCigCount && $prev_seq_length < $firstCigCount) {
      push @all_cig, ($firstCigCount-$prev_seq_length) . "X";
    } 

    #initialise seq_length 
    $prev_seq_length = $firstCigCount;

    for my $cigElem ( @cig ) {
      my $cigType = substr( $cigElem, -1, 1 );
      my $cigCount = substr( $cigElem, 0 ,-1 );
      $cigCount = 1 unless ($cigCount =~ /^\d+$/);

      #Keep count of the sequence length to see if we need padding to the next genomic_align 
      if ($cigType =~ /[MD]/) {
        $prev_seq_length += $cigCount;
      } 
      #Append all elements apart from X
      unless ($cigType eq "X") {
        push @all_cig, $cigElem;
      }
    }
  }

  #Merge neighbouring elements of the same type
  my ($lastCigType, $lastCigCount, $lastCigElem);
  while (@all_cig) {
    my $cigElem = shift @all_cig;
    my $cigType = substr( $cigElem, -1, 1 );
    my $cigCount = substr( $cigElem, 0 ,-1 );
    $cigCount = 1 unless ($cigCount =~ /^\d+$/);
    if ($lastCigType) {
      if ($lastCigType eq $cigType) {
        $cigElem = ($cigCount+$lastCigCount) . $cigType;
        $lastCigCount = ($cigCount+$lastCigCount);
      } else {
        $final_cigar_line .= $lastCigElem;
        $lastCigCount = $cigCount;
      }
    } else {
        $lastCigCount = $cigCount;
    }
    $lastCigElem = $cigElem;
    $lastCigType = $cigType;
  }
  $final_cigar_line .= $lastCigElem;

  return $final_cigar_line;
}

1;
