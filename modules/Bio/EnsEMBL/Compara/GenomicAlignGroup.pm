#
# Ensembl module for Bio::EnsEMBL::Compara::GenomicAlignGroup
#
# Copyright Javier Herrero
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

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

corresponds to genomic_align_group.group_id

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor object to access DB

=item type

corresponds to genomic_align_group.type

=item genomic_align_array

listref of Bio::EnsEMBL::Compara::DBSQL::GenomicAlign objects corresponding to this
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroup object

=back

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomicAlignGroup;
use strict;

# Object preamble
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Scalar::Util qw(weaken);


=head2 new (CONSTRUCTOR)

  Arg [-DBID] : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]
              : (opt.) Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor $adaptor
                (the adaptor for connecting to the database)
  Arg [-TYPE] : (opt.) string $type (a string identifying the type of grouping)
  Arg [-GENOMIC_ALIGN_ARRAY]
              : (opt.) array_ref $genomic_aligns (a reference to the array of
                Bio::EnsEMBL::Compara::GenomicAlign objects corresponding to this
                Bio::EnsEMBL::Compara::GenomicAlignGroup object)
  Example    : my $genomic_align_group =
                   new Bio::EnsEMBL::Compara::GenomicAlignGroup(
                       -adaptor => $genomic_align_group_adaptor,
                       -type => "pairwise",
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
  
  my $self = {};
  bless $self,$class;
    
  my ($adaptor, $dbID, $type, $genomic_align_array) = 
    rearrange([qw(
        ADAPTOR DBID TYPE GENOMIC_ALIGN_ARRAY)], @args);

  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->dbID($dbID) if (defined ($dbID));
  $self->type($type) if (defined ($type));
  $self->genomic_align_array($genomic_align_array) if (defined($genomic_align_array));

  return $self;
}

=head2 new_fast

  Arg [1]    : hash reference $hashref
  Example    : none
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype :
  Exceptions : none
  Caller     :
  Status     : Stable

=cut

sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
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
  $copy->{original_dbID} = $self->{dbID};
  $copy->{type} = $self->type;
  $copy->{genomic_align_array} = $self->{genomic_align_array};

  return bless $copy, ref($self);
}


=head2 adaptor

  Arg [1]    : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor $adaptor
  Example    : my $gen_ali_grp_adaptor = $genomic_align_block->adaptor();
  Example    : $genomic_align_block->adaptor($gen_ali_grp_adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor object
  Exceptions : thrown if $adaptor is not a
               Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor object
  Caller     : general
  Status     : Stable

=cut

sub adaptor {
  my ($self, $adaptor) = @_;

  if (defined($adaptor)) {
    throw("$adaptor is not a Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor object")
        unless ($adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor"));
    $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}


=head2 dbID

  Arg [1]    : integer $dbID
  Example    : my $dbID = $genomic_align_group->dbID();
  Example    : $genomic_align_group->dbID(12);
  Description: Getter/Setter for the attribute dbID
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub dbID {
  my ($self, $dbID) = @_;

  if (defined($dbID)) {
    $self->{'dbID'} = $dbID;
  }

  return $self->{'dbID'};
}


=head2 type

  Arg [1]    : string $type
  Example    : my $type = $genomic_align_group->type();
  Example    : $genomic_align_group->type("pairwise");
  Description: Getter/Setter for the attribute type
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub type {
  my ($self, $type) = @_;

  if (defined($type)) {
    $self->{'type'} = $type;

  } elsif (!defined($self->{'type'})) {
    # Tries to get the data from other sources
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlignGroup object
      $self->adaptor->retrieve_all_direct_attributes($self);
    }
  }

  return $self->{'type'};
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
 
  if (defined($genomic_align_array)) {
    $self->{'genomic_align_array'} = undef;
    foreach my $genomic_align (@$genomic_align_array) {
      throw("$genomic_align is not a Bio::EnsEMBL::Compara::GenomicAlign object")
          unless ($genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));
      if (!defined($genomic_align_adaptor)) {
        if (defined($genomic_align->adaptor)) {
          $genomic_align_adaptor = $genomic_align->adaptor;
        } elsif (defined($self->adaptor)) {
          $genomic_align_adaptor = $self->adaptor->db->get_GenomicAlignAdaptor;
        }
      }
      if (defined($genomic_align_adaptor) and $genomic_align->dbID) {
        # stores data in a hash where keys are genomic_align_ids and values are weak references
        # to the corresponding Bio::EnsEMBL::Compara::GenomicAlign obects. Storing data in such
        # a way will allow us to restore easily weak references if they are destroyed.
        weaken($self->{'genomic_align_array'}->{$genomic_align->dbID} = $genomic_align);
        $self->{'genomic_align_adaptor'} = $genomic_align_adaptor;
      } else {
        # If the adaptor cannot be retrieved, use strong references.
        # Also use $genomic_align instead of the dbID since the dbID will
        # not be used and it can be undefined at this moment
        $self->{'genomic_align_array'}->{$genomic_align} = $genomic_align;
      }
    }

  } elsif (!defined($self->{'genomic_align_array'})) {
    # Try to get genomic_align_array from other sources
    if (defined($self->{'adaptor'}) and defined($self->{'dbID'})) {
      $self = $self->{'adaptor'}->fetch_by_dbID($self->{'dbID'});
    }
  }

  $genomic_align_array = [];
  if ($self->{'genomic_align_adaptor'}) {
    $genomic_align_adaptor = $self->{'genomic_align_adaptor'};
  }

  if (defined($genomic_align_adaptor)) {
    # We are using weak references
    while (my ($dbID, $genomic_align) = each %{$self->{'genomic_align_array'}}) {
      if (!defined($genomic_align)) {
        $genomic_align = $genomic_align_adaptor->fetch_by_dbID($dbID);
        # Weak reference has been destroyed, restore it using the genomic_align_id
        weaken($self->{'genomic_align_array'}->{$dbID} = $genomic_align);
      }
      push(@$genomic_align_array, $genomic_align);
    }
  
  } else {
    # We are using strong references
    $genomic_align_array = [values %{$self->{'genomic_align_array'}}];
  }
  return $genomic_align_array;
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
    if (!$aligned_sequence) {
      $aligned_sequence = $this_genomic_align->aligned_sequence;
    } else {
      my $pos = 0;
      foreach my $substr (grep {$_} split(/(\.+)/, $this_genomic_align->aligned_sequence)) {
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



1;
