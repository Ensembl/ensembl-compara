#
# Ensembl module for Bio::EnsEMBL::Compara::GenomicAlignBlock
#
# Cared for by Javier Herrero <jherrero@ebi.ac.uk>
#
# Copyright Javier Herrero
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::GenomicAlignBlock - Alignment of two or more pieces of genomic DNA

=head1 SYNOPSIS
  
  use Bio::EnsEMBL::Compara::GenomicAlignBlock;
  
  my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -method_link_species_set => $method_link_species_set,
          -score => 56.2,
          -length => 1203,
          -genomic_align_array => [$genomic_align1, $genomic_align2...]
      );

SET VALUES
  $genomic_align_block->adaptor($gen_ali_blk_adaptor);
  $genomic_align_block->dbID(12);
  $genomic_align_block->method_link_species_set($method_link_species_set);
  $genomic_align_block->reference_genomic_align_id(35123);
  $genomic_align_block->genomic_align_array([$genomic_align1, $genomic_align2]);
  $genomic_align_block->reference_slice($reference_slice);
  $genomic_align_block->reference_slice_start(1035);
  $genomic_align_block->reference_slice_end(1283);
  $genomic_align_block->score(56.2);
  $genomic_align_block->length(562);

GET VALUES
  my $genomic_align_block_adaptor = $genomic_align_block->adaptor();
  my $dbID = $genomic_align_block->dbID();
  my $method_link_species_set = $genomic_align_block->method_link_species_set;
  my $genomic_aligns = $genomic_align_block->genomic_align_array();
  my $reference_genomic_align = $genomic_align_block->reference_genomic_align();
  my $non_reference_genomic_aligns = $genomic_align_block->non_reference_genomic_aligns();
  my $reference_slice = $genomic_align_block->reference_slice();
  my $reference_slice_start = $genomic_align_block->reference_slice_start();
  my $reference_slice_end = $genomic_align_block->reference_slice_end();
  my $score = $genomic_align_block->score();
  my $length = $genomic_align_block->length;
  my alignment_strings = $genomic_align_block->alignment_strings;

=head1 OBJECT ATTRIBUTES

=over

=item dbID

corresponds to genomic_align_block.genomic_align_block_id

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor object to access DB

=item method_link_species_set_id

corresponds to method_link_species_set.method_link_species_set_id (external ref.)

=item method_link_species_set

Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object corresponding to method_link_species_set_id

=item score

corresponds to genomic_align_block.score

=item perc_id

corresponds to genomic_align_block.perc_id

=item length

corresponds to genomic_align_block.length

=item reference_genomic_align_id

When looking for genomic alignments in a given slice or dnafrag, the
reference_genomic_align corresponds to the Bio::EnsEMBL::Compara::GenomicAlign
included in the starting slice or dnafrag. The reference_genomic_align_id is
the dbID corresponding to the reference_genomic_align. All remaining
Bio::EnsEMBL::Compara::GenomicAlign objects included in the
Bio::EnsEMBL::Compara::GenomicAlignBlock are the non_reference_genomic_aligns.

=item reference_genomic_align

Bio::EnsEMBL::Compara::GenomicAling object corresponding to reference_genomic_align_id

=item genomic_align_array

listref of Bio::EnsEMBL::Compara::GenomicAlign objects corresponding to this
Bio::EnsEMBL::Compara::GenomicAlignBlock object

=item reference_slice

This is the Bio::EnsEMBL::Slice object used as argument to the
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->fetch_all_by_Slice method.

=item reference_slice_start

starting position in the coordinates system defined by the reference_slice

=item reference_slice_end

ending position in the coordinates system defined by the reference_slice

=back

=head1 AUTHOR

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


package Bio::EnsEMBL::Compara::GenomicAlignBlock;
use strict;

# Object preamble
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info deprecate verbose);
use Bio::EnsEMBL::Compara::GenomicAlign;


=head2 new (CONSTRUCTOR)

  Arg[1]     : a reference to a hash where keys can be:
                 -adaptor
                 -dbID
                 -method_link_species_set
                 -method_link_species_set_id
                 -score
                 -perc_id
                 -length
                 -reference_genomic_align
                 -reference_genomic_align_id
                 -genomic_align_array
  Example    : my $genomic_align_block =
                   new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                       -adaptor => $gaba,
                       -method_link_species_set => $method_link_species_set,
                       -score => 56.2,
                       -length => 1203,
                       -genomic_align_array => [$genomic_align1, $genomic_align2...]
                   );
  Description: Creates a new GenomicAlignBlock object
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlock
  Exceptions : none
  Caller     : general

=cut

sub new {
  my($class, @args) = @_;
  
  my $self = {};
  bless $self,$class;
    
  my ($adaptor, $dbID, $method_link_species_set, $method_link_species_set_id,
          $score, $perc_id, $length, $reference_genomic_align, $reference_genomic_align_id,
          $genomic_align_array, $starting_genomic_align_id, $ungapped_genomic_align_blocks) = 
    rearrange([qw(
        ADAPTOR DBID METHOD_LINK_SPECIES_SET METHOD_LINK_SPECIES_SET_ID
        SCORE PERC_ID LENGTH REFERENCE_GENOMIC_ALIGN REFERENCE_GENOMIC_ALIGN_ID
        GENOMIC_ALIGN_ARRAY STARTING_GENOMIC_ALIGN_ID UNGAPPED_GENOMIC_ALIGN_BLOCKS)],
            @args);

  if (defined($ungapped_genomic_align_blocks)) {
    return $self->_create_from_a_list_of_ungapped_genomic_align_blocks($ungapped_genomic_align_blocks);
  }
  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->dbID($dbID) if (defined ($dbID));
  $self->method_link_species_set($method_link_species_set) if (defined ($method_link_species_set));
  $self->method_link_species_set_id($method_link_species_set_id)
      if (defined ($method_link_species_set_id));
  $self->score($score) if (defined ($score));
  $self->perc_id($perc_id) if (defined ($perc_id));
  $self->length($length) if (defined ($length));
  $self->reference_genomic_align($reference_genomic_align)
      if (defined($reference_genomic_align));
  $self->reference_genomic_align_id($reference_genomic_align_id)
      if (defined($reference_genomic_align_id));
  $self->genomic_align_array($genomic_align_array) if (defined($genomic_align_array));

  $self->starting_genomic_align_id($starting_genomic_align_id) if (defined($starting_genomic_align_id));

  return $self;
}


sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}


=head2 adaptor

  Arg [1]    : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor $adaptor
  Example    : my $gen_ali_blk_adaptor = $genomic_align_block->adaptor();
  Example    : $genomic_align_block->adaptor($gen_ali_blk_adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor object
  Exceptions : thrown if $adaptor is not a
               Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor object
  Caller     : general

=cut

sub adaptor {
  my ($self, $adaptor) = @_;

  if (defined($adaptor)) {
    throw("$adaptor is not a Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor object")
        unless ($adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor"));
    $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}


=head2 dbID

  Arg [1]    : integer $dbID
  Example    : my $dbID = $genomic_align_block->dbID();
  Example    : $genomic_align_block->dbID(12);
  Description: Getter/Setter for the attribute dbID
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub dbID {
  my ($self, $dbID) = @_;

  if (defined($dbID)) {
    $self->{'dbID'} = $dbID;
  }

  return $self->{'dbID'};
}


=head2 method_link_species_set

  Arg [1]    : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Example    : $method_link_species_set = $genomic_align_block->method_link_species_set;
  Example    : $genomic_align_block->method_link_species_set($method_link_species_set);
  Description: get/set for attribute method_link_species_set. If no
               argument is given, the method_link_species_set is not defined but
               both the method_link_species_set_id and the adaptor are, it tries
               to fetch the data using the method_link_species_set_id
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : thrown if $method_link_species_set is not a
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Caller     : general

=cut

sub method_link_species_set {
  my ($self, $method_link_species_set) = @_;

  if (defined($method_link_species_set)) {
    throw("$method_link_species_set is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
        unless ($method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $self->{'method_link_species_set'} = $method_link_species_set;
    if ($self->{'method_link_species_set_id'}) {
#       warning("Defining both method_link_species_set_id and method_link_species_set");
      throw("method_link_species_set object does not match previously defined method_link_species_set_id")
          if ($self->{'method_link_species_set'}->dbID != $self->{'method_link_species_set_id'});
    }

  } elsif (!defined($self->{'method_link_species_set'}) and defined($self->{'adaptor'})
          and defined($self->method_link_species_set_id)) {
    # Try to get object from ID. Use method_link_species_set_id function and not the attribute in the <if>
    # clause because the attribute can be retrieved from other sources if it has not been already defined.
    my $mlssa = $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor;
    $self->{'method_link_species_set'} = $mlssa->fetch_by_dbID($self->{'method_link_species_set_id'})
  }

  return $self->{'method_link_species_set'};
}


=head2 method_link_species_set_id

  Arg [1]    : integer $method_link_species_set_id
  Example    : $method_link_species_set_id = $genomic_align_block->method_link_species_set_id;
  Example    : $genomic_align_block->method_link_species_set_id(3);
  Description: Getter/Setter for the attribute method_link_species_set_id. If no
               argument is given, the method_link_species_set_id is not defined but
               the method_link_species_set is, it tries to get the data from the
               method_link_species_set object. If this fails, it tries to get and set
               all the direct attributes from the database using the dbID of the
               Bio::Ensembl::Compara::GenomicAlignBlock object.
  Returntype : integer
  Exceptions : thrown if $method_link_species_set_id does not match a previously defined
               method_link_species_set
  Caller     : object::methodname

=cut

sub method_link_species_set_id {
  my ($self, $method_link_species_set_id) = @_;

  if (defined($method_link_species_set_id)) {
    $self->{'method_link_species_set_id'} = $method_link_species_set_id;
    if (defined($self->{'method_link_species_set'}) and $self->{'method_link_species_set_id'}) {
#       warning("Defining both method_link_species_set_id and method_link_species_set");
      throw("method_link_species_set_id does not match previously defined method_link_species_set object")
          if ($self->{'method_link_species_set'} and
              $self->{'method_link_species_set'}->dbID != $self->{'method_link_species_set_id'});
    }

  } elsif (!($self->{'method_link_species_set_id'})) {
    # Try to get the ID from other sources...
    if (defined($self->{'method_link_species_set'})) {
      # ...from the object
      $self->{'method_link_species_set_id'} = $self->{'method_link_species_set'}->dbID;
    } elsif (defined($self->{'adaptor'}) and defined($self->dbID)) {
      # ...from the database, using the dbID of the Bio::Ensembl::Compara::GenomicAlignBlock object
      $self->adaptor->retrieve_all_direct_attributes($self);
    }
  }

  return $self->{'method_link_species_set_id'};
}


=head2 reference_genomic_align_id
 
  Arg [1]    : integer $reference_genomic_align_id
  Example    : $genomic_align_block->reference_genomic_align_id(4321);
  Description: get/set for attribute reference_genomic_align_id. A value of 0 will set the
               reference_genomic_align_id attribute to undef. When looking for genomic
               alignments in a given slice or dnafrag, the reference_genomic_align
               corresponds to the Bio::EnsEMBL::Compara::GenomicAlign included in the
               starting slice or dnafrag. The reference_genomic_align_id is the dbID
               corresponding to the reference_genomic_align. All remaining
               Bio::EnsEMBL::Compara::GenomicAlign objects included in the
               Bio::EnsEMBL::Compara::GenomicAlignBlock are the
               non_reference_genomic_aligns.
               Synchronises reference_genomic_align and reference_genomic_align_id
               attributes.
  Returntype : integer
  Exceptions : throw if $reference_genomic_align_id id not a postive number
  Caller     : $genomic_align_block->reference_genomic_align_id(int)
 
=cut

sub reference_genomic_align_id {
  my ($self, $reference_genomic_align_id) = @_;
 
  if (defined($reference_genomic_align_id)) {
    if ($reference_genomic_align_id !~ /^\d+$/) {
      throw "[$reference_genomic_align_id] should be a positive number.";
    }
    $self->{'reference_genomic_align_id'} = ($reference_genomic_align_id or undef);

    ## Synchronises reference_genomic_align and reference_genomic_align_id
    if (defined($self->{'reference_genomic_align'}) and
        defined($self->{'reference_genomic_align'}->dbID) and
        ($self->{'reference_genomic_align'}->dbID != $self->{'reference_genomic_align_id'})) {
        $self->{'reference_genomic_align'} = undef; ## Attribute will be set on request
    }

  ## Try to get data from other sources...
  } elsif (!defined($self->{'reference_genomic_align_id'})) {

    ## ...from the reference_genomic_align attribute
    if (defined($self->{'reference_genomic_align'}) and
        defined($self->{'reference_genomic_align'}->dbID)) {
      $self->{'reference_genomic_align_id'} = $self->{'reference_genomic_align'}->dbID;
    }
  }
  
  return $self->{'reference_genomic_align_id'};
}


=head2 starting_genomic_align_id (DEPRECATED)

  DEPRECATED! Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_genomic_align_id() method instead
 
  Arg [1]    : integer $reference_genomic_align_id
  Example    : $genomic_align_block->starting_genomic_align_id(4321);
  Description: set for attribute reference_genomic_align_id. A value of 0 will set the
               reference_genomic_align_id attribute to undef. When looking for genomic
               alignments in a given slice or dnafrag, the reference_genomic_align
               corresponds to the Bio::EnsEMBL::Compara::GenomicAlign included in the
               starting slice or dnafrag. The reference_genomic_align_id is the dbID
               corresponding to the reference_genomic_align. All remaining
               Bio::EnsEMBL::Compara::GenomicAlign objects included in the
               Bio::EnsEMBL::Compara::GenomicAlignBlock are the non_reference_genomic_aligns.
  Returntype : none
  Exceptions : throw if $reference_genomic_align_id id not a postive number
  Caller     : $genomic_align_block->starting_genomic_align_id(int)
 
=cut

sub starting_genomic_align_id {
  my $self = shift;
  deprecate("Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_genomic_align_id() method instead");
  return $self->reference_genomic_align_id(@_);
}


=head2 reference_genomic_align
 
  Arg [1]    : (optional) Bio::EnsEMBL::Compara::GenomicAlign $reference_genomic_align
  Example    : $genomic_align_block->reference_genomic_align($reference_genomic_align);
  Example    : $genomic_align = $genomic_align_block->reference_genomic_align();
  Description: get/set the reference_genomic_align. When looking for genomic alignments in
               a given slice or dnafrag, the reference_genomic_align corresponds to the
               Bio::EnsEMBL::Compara::GenomicAlign included in the starting slice or
               dnafrag. The reference_genomic_align_id is the dbID corresponding to the
               reference_genomic_align. All remaining Bio::EnsEMBL::Compara::GenomicAlign
               objects included in the Bio::EnsEMBL::Compara::GenomicAlignBlock are the
               non_reference_genomic_aligns.
               Synchronises reference_genomic_align and reference_genomic_align_id
               attributes.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : throw if reference_genomic_align is not a Bio::EnsEMBL::Compara::GenomicAlign
               object
  Exceptions : throw if reference_genomic_align_id does not match any of the
               Bio::EnsEMBL::Compara::GenomicAlign objects in the genomic_align_array
  Caller     : $genomic_align_block->reference_genomic_align()
 
=cut

sub reference_genomic_align {
  my ($self, $reference_genomic_align) = @_;

  if (defined($reference_genomic_align)) {
    throw("[$reference_genomic_align] must be a Bio::EnsEMBL::Compara::GenomicAlign object")
        unless($reference_genomic_align and  ref($reference_genomic_align) and
            $reference_genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));
    $self->{'reference_genomic_align'} = $reference_genomic_align;

    ## Synchronises reference_genomic_align and reference_genomic_align_id attributes
    if (defined($self->{'reference_genomic_align'}->dbID)) {
      $self->{'reference_genomic_align_id'} = $self->{'reference_genomic_align'}->dbID;
    }

  ## Try to get data from other sources...
  } elsif (!defined($self->{'reference_genomic_align'})) {
    
    ## ...from the reference_genomic_align_id attribute
    if (defined($self->{'reference_genomic_align_id'}) and @{$self->get_all_GenomicAligns}) {
      my $reference_genomic_align_id = $self->{'reference_genomic_align_id'};
      foreach my $this_genomic_align (@{$self->get_all_GenomicAligns}) {
        if ($this_genomic_align->dbID == $reference_genomic_align_id) {
          $self->{'reference_genomic_align'} = $this_genomic_align;
          return $this_genomic_align;
        }
      }
      throw("[$self] Cannot found Bio::EnsEMBL::Compara::GenomicAlign::reference_genomic_align_id".
          " ($reference_genomic_align_id) in the genomic_align_array");
    }
  }

  return $self->{'reference_genomic_align'};
}


=head2 starting_genomic_align (DEPRECATED)

  DEPRECATED! Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_genomic_align() method instead
 
  Arg [1]    : (none)
  Example    : $genomic_align = $genomic_align_block->starting_genomic_align();
  Description: get the reference_genomic_align. When looking for genomic alignments in
               a given slice or dnafrag, the reference_genomic_align corresponds to the
               Bio::EnsEMBL::Compara::GenomicAlign included in the starting slice or
               dnafrag. The reference_genomic_align_id is the dbID corresponding to the
               reference_genomic_align. All remaining Bio::EnsEMBL::Compara::GenomicAlign
               objects included in the Bio::EnsEMBL::Compara::GenomicAlignBlock are the
               non_reference_genomic_aligns.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : warns if no reference_genomic_align_id has been set and returns a ref.
               to an empty array
  Exceptions : warns if no genomic_align_array has been set and returns a ref.
               to an empty array
  Exceptions : throw if reference_genomic_align_id does not match any of the
               Bio::EnsEMBL::Compara::GenomicAlign objects in the genomic_align_array
  Caller     : $genomic_align_block->starting_genomic_align()
 
=cut

sub starting_genomic_align {
  my $self = shift;
  deprecate("Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_genomic_align() method instead");
  return $self->reference_genomic_align(@_);
}


=head2 resulting_genomic_aligns
 
  DEPRECATED! Use Bio::EnsEMBL::Compara::GenomicAlignBlock->get_all_non_reference_genomic_align()
  method instead
 
  Arg [1]    : (none)
  Example    : $genomic_aligns = $genomic_align_block->resulting_genomic_aligns();
  Description: get the all the non_reference_genomic_aligns. When looking for genomic
               alignments in a given slice or dnafrag, the reference_genomic_align
               corresponds to the Bio::EnsEMBL::Compara::GenomicAlign included in the
               reference slice or dnafrag. The reference_genomic_align_id is the dbID
               corresponding to the reference_genomic_align. All remaining
               Bio::EnsEMBL::Compara::GenomicAlign objects included in the
               Bio::EnsEMBL::Compara::GenomicAlignBlock are the
               non_reference_genomic_aligns.
  Returntype : a ref. to an array of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : warns if no reference_genomic_align_id has been set and returns a ref.
               to an empty array
  Exceptions : warns if no genomic_align_array has been set and returns a ref.
               to an empty array
  Caller     : $genomic_align_block->resulting_genomic_aligns()
 
=cut

sub resulting_genomic_aligns {
  my ($self) = @_;
  deprecate("Use Bio::EnsEMBL::Compara::GenomicAlignBlock->get_all_non_reference_genomic_aligns() method instead");
  return $self->get_all_non_reference_genomic_aligns(@_);
}


=head2 get_all_non_reference_genomic_aligns
 
  Arg [1]    : (none)
  Example    : $genomic_aligns = $genomic_align_block->get_all_non_reference_genomic_aligns();
  Description: get the non_reference_genomic_aligns. When looking for genomic alignments in
               a given slice or dnafrag, the reference_genomic_align corresponds to the
               Bio::EnsEMBL::Compara::GenomicAlign included in the starting slice or
               dnafrag. The reference_genomic_align_id is the dbID corresponding to the
               reference_genomic_align. All remaining Bio::EnsEMBL::Compara::GenomicAlign
               objects included in the Bio::EnsEMBL::Compara::GenomicAlignBlock are the
               non_reference_genomic_aligns.
  Returntype : a ref. to an array of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : warns if no reference_genomic_align_id has been set and returns a ref.
               to an empty array
  Exceptions : warns if no genomic_align_array has been set and returns a ref.
               to an empty array
  Caller     : $genomic_align_block->non_reference_genomic_aligns()
 
=cut

sub get_all_non_reference_genomic_aligns {
  my ($self) = @_;
  my $all_non_reference_genomic_aligns = [];
 
  my $reference_genomic_align_id = $self->reference_genomic_align_id;
  if (!defined($reference_genomic_align_id)) {
    warning("Trying to get Bio::EnsEMBL::Compara::GenomicAlign::all_non_reference_genomic_aligns".
        " when no reference_genomic_align_id has been set before");
    return $all_non_reference_genomic_aligns;
  }
  my $genomic_aligns = $self->get_all_GenomicAligns; ## Lazy loading compliant
  if (!@$genomic_aligns) {
    warning("Trying to get Bio::EnsEMBL::Compara::GenomicAlign::all_non_reference_genomic_aligns".
        " when no genomic_align_array can be retrieved");
    return $all_non_reference_genomic_aligns;
  }

  foreach my $this_genomic_align (@$genomic_aligns) {
    if ($this_genomic_align->dbID != $reference_genomic_align_id) {
      push(@$all_non_reference_genomic_aligns, $this_genomic_align);
    }
  }

  return $all_non_reference_genomic_aligns;
}


=head2 genomic_align_array
 
  Arg [1]    : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Example    : $genomic_aligns = $genomic_align_block->genomic_align_array();
               $genomic_align_block->genomic_align_array([$genomic_align1, $genomic_align2]);
  Description: get/set for attribute genomic_align_array. If no argument is given, the
               genomic_align_array is not defined but both the dbID and the adaptor are,
               it tries to fetch the data from the database using the dbID of the
               Bio::EnsEMBL::Compara::GenomicAlignBlock object.
  Returntype : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : none
  Caller     : general
 
=cut

sub genomic_align_array {
  my ($self, $genomic_align_array) = @_;
 
  if (defined($genomic_align_array)) {
    foreach my $genomic_align (@$genomic_align_array) {
      throw("[$genomic_align] is not a Bio::EnsEMBL::Compara::GenomicAlign object")
          unless ($genomic_align and $genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));
      # Create weak circular reference to genomic_align_block from each genomic_align
      $genomic_align->genomic_align_block($self); 
    }
    $self->{'genomic_align_array'} = $genomic_align_array;

  } elsif (!defined($self->{'genomic_align_array'}) and defined($self->{'adaptor'})
        and defined($self->{'dbID'})) {
    # Fetch data from DB (allow lazy fetching of genomic_align_block objects)
    my $genomic_align_adaptor = $self->adaptor->db->get_GenomicAlignAdaptor();
    $self->{'genomic_align_array'} = 
        $genomic_align_adaptor->fetch_all_by_genomic_align_block_id($self->{'dbID'});
    foreach my $this_genomic_align (@{$self->{'genomic_align_array'}}) {
      $this_genomic_align->genomic_align_block($self);
    }
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
 
=cut

sub add_GenomicAlign {
  my ($self, $genomic_align) = @_;
 
  throw("[$genomic_align] is not a Bio::EnsEMBL::Compara::GenomicAlign object")
      unless ($genomic_align and ref($genomic_align) and 
          $genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));
  # Create weak circular reference to genomic_align_block from each genomic_align
  $genomic_align->genomic_align_block($self);
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
 
=cut

sub get_all_GenomicAligns {
  my ($self) = @_;
 
  return ($self->genomic_align_array or []);
}


=head2 score
 
  Arg [1]    : double $score
  Example    : my $score = $genomic_align_block->score();
               $genomic_align_block->score(56.2);
  Description: get/set for attribute score. If no argument is given, the score
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlignBlock object.
  Returntype : double
  Exceptions : none
  Caller     : general
 
=cut

sub score {
  my ($self, $score) = @_;

  if (defined($score)) {
    $self->{'score'} = $score;
  } elsif (!defined($self->{'score'})) {
    # Try to get the ID from other sources...
    if (defined($self->{'adaptor'}) and defined($self->dbID)) {
      # ...from the database, using the dbID of the Bio::Ensembl::Compara::GenomicAlignBlock object
      $self->adaptor->retrieve_all_direct_attributes($self);
    }
  }

  return $self->{'score'};
}


=head2 perc_id
 
  Arg [1]    : double $perc_id
  Example    : my $perc_id = $genomic_align_block->perc_id;
  Example    : $genomic_align_block->perc_id(95.4);
  Description: get/set for attribute perc_id. If no argument is given, the perc_id
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlignBlock object.
  Returntype : double
  Exceptions : none
  Caller     : general

=cut

sub perc_id {
  my ($self, $perc_id) = @_;
 
  if (defined($perc_id)) {
    $self->{'perc_id'} = $perc_id;
  } elsif (!defined($self->{'perc_id'})) {
    # Try to get the ID from other sources...
    if (defined($self->{'adaptor'}) and defined($self->dbID)) {
      # ...from the database, using the dbID of the Bio::Ensembl::Compara::GenomicAlignBlock object
      $self->adaptor->retrieve_all_direct_attributes($self);
    }
  }
  
  return $self->{'perc_id'};
}


=head2 length
 
  Arg [1]    : integer $length
  Example    : my $length = $genomic_align_block->length;
  Example    : $genomic_align_block->length(562);
  Description: get/set for attribute length. If no argument is given, the length
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlignBlock object.
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub length {
  my ($self, $length) = @_;
 
  if (defined($length)) {
    $self->{'length'} = $length;
  } elsif (!defined($self->{'length'})) {
    # Try to get the ID from other sources...
    if (defined($self->{'adaptor'}) and defined($self->dbID)) {
      # ...from the database, using the dbID of the Bio::Ensembl::Compara::GenomicAlignBlock object
      $self->adaptor->retrieve_all_direct_attributes($self);
    } elsif (@{$self->get_all_GenomicAligns} and $self->get_all_GenomicAligns->[0]->aligned_sequence) {
      $self->{'length'} = CORE::length($self->get_all_GenomicAligns->[0]->aligned_sequence);
    }
  }
  
  return $self->{'length'};
}


=head2 requesting_slice (DEPRECATED)

  DEPRECATED! Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice() method instead
 
  Arg [1]    : Bio::EnsEMBL::Slice $reference_slice
  Example    : my $reference_slice = $genomic_align_block->requesting_slice;
  Example    : $genomic_align_block->requesting_slice($reference_slice);
  Description: get/set for attribute reference_slice.
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : throw if $reference_slice is not a Bio::EnsEMBL::Slice
  Caller     : general

=cut

sub requesting_slice {
  my ($self) = shift;
  deprecate("Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice() method instead");
  return $self->reference_slice(@_);
}


=head2 reference_slice
 
  Arg [1]    : Bio::EnsEMBL::Slice $reference_slice
  Example    : my $reference_slice = $genomic_align_block->reference_slice;
  Example    : $genomic_align_block->reference_slice($reference_slice);
  Description: get/set for attribute reference_slice.
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : throw if $reference_slice is not a Bio::EnsEMBL::Slice
  Caller     : general

=cut

sub reference_slice {
  my ($self, $reference_slice) = @_;
 
  if (defined($reference_slice)) {
    throw "[$reference_slice] is not a Bio::EnsEMBL::Slice"
        unless $reference_slice->isa("Bio::EnsEMBL::Slice");
    $self->{'reference_slice'} = $reference_slice;
  }

  return $self->{'reference_slice'};
}


=head2 requesting_slice_start (DEPRECATED)

  DEPRECATED! Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_start() method instead
 
  Arg [1]    : integer $reference_slice_start
  Example    : my $reference_slice_start = $genomic_align_block->requesting_slice_start;
  Example    : $genomic_align_block->requesting_slice_start(1035);
  Description: get/set for attribute reference_slice_start. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub requesting_slice_start {
  my $self = shift;
  deprecate("Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_start() method instead");
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

=cut

sub reference_slice_start {
  my ($self, $reference_slice_start) = @_;
 
  if (defined($reference_slice_start)) {
    $self->{'reference_slice_start'} = ($reference_slice_start or undef);
  }
  
  return $self->{'reference_slice_start'};
}


=head2 requesting_slice_end (DEPRECATED)

  DEPRECATED! Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_end() method instead
 
  Arg [1]    : integer $reference_slice_end
  Example    : my $reference_slice_end = $genomic_align_block->requesting_slice_end;
  Example    : $genomic_align_block->requesting_slice_end(1283);
  Description: get/set for attribute reference_slice_end. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub requesting_slice_end {
  my $self = shift;
  deprecate("Use Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_end() method instead");
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

=cut

sub reference_slice_end {
  my ($self, $reference_slice_end) = @_;
 
  if (defined($reference_slice_end)) {
    $self->{'reference_slice_end'} = ($reference_slice_end or undef);
  }
  
  return $self->{'reference_slice_end'};
}


=head2 alignment_strings

  Arg [1]    : none
  Example    : $genomic_align_block->alignment_strings
  Description: Returns the alignment string of all the sequences in the
               alignment
  Returntype : array reference containing several strings
  Exceptions : none
  Caller     : 

=cut

sub alignment_strings {
  my ($self) = @_;
  my $alignment_strings = [];

  foreach my $genomic_align (@{$self->get_all_GenomicAligns}) {
    push(@$alignment_strings, $genomic_align->aligned_sequence);
  }

  return $alignment_strings;
}


=head2 get_SimpleAlign

  Arg [1]    : list of string $flags
               "translated" = by default, the sequence alignment will be on nucleotide. With "translated" flag
                              the aligned sequences are translated.
               "uc" = by default aligned sequences are given in lower cases. With "uc" flag, the aligned
                      sequences are given in upper cases.
               "display_id" = by default the name of each sequence in the alignment is $dnafrag->name. With 
                              "dispaly_id" flag the name of each sequence is defined by the 
                              Bio::EnsEMBL::Compara::GenomicAlign display_id method.
  Example    : $daf->get_SimpleAlign or
               $daf->get_SimpleAlign("translated") or
               $daf->get_SimpleAlign("translated","uc")
  Description: Allows to rebuild the alignment string of all the genomic_align objects within
               this genomic_align_block using the cigar_line information
               and access to the core database slice objects
  Returntype : a Bio::SimpleAlign object
  Exceptions :
  Caller     :

=cut

sub get_SimpleAlign {
  my ( $self, @flags ) = @_;

  # setting the flags
  my $uc = 0;
  my $translated = 0;
  my $display_id = 0;

  for my $flag ( @flags ) {
    $uc = 1 if ($flag =~ /^uc$/i);
    $translated = 1 if ($flag =~ /^translated$/i);
    $display_id = 1 if ($flag =~ /^display_id$/i);
  }

  my $sa = Bio::SimpleAlign->new();

  #Hack to try to work with both bioperl 0.7 and 1.2:
  #Check to see if the method is called 'addSeq' or 'add_seq'
  my $bio07 = 0;
  if(!$sa->can('add_seq')) {
    $bio07 = 1;
  }

  foreach my $genomic_align (@{$self->get_all_GenomicAligns}) {
    my $alignSeq = $genomic_align->aligned_sequence;
    
    my $loc_seq = Bio::LocatableSeq->new(-SEQ    => $uc ? uc $alignSeq : lc $alignSeq,
                                         -START  => $genomic_align->dnafrag_start,
                                         -END    => $genomic_align->dnafrag_end,
                                         -ID     => $display_id ? $genomic_align->display_id : $genomic_align->dnafrag->name,
                                         -STRAND => $genomic_align->dnafrag_strand);

    $loc_seq->seq($uc ? uc $loc_seq->translate->seq
                      : lc $loc_seq->translate->seq) if ($translated);

    if($bio07) { $sa->addSeq($loc_seq); }
    else       { $sa->add_seq($loc_seq); }

  }
  return $sa;
}


=head2 _create_from_a_list_of_ungapped_genomic_align_blocks (testing)

  Args       : listref of ungapped Bio::EnsEMBL::Compara::GenomicAlignBlocks
  Example    : $new_genomic_align_block =
                  $self->_create_from_a_list_of_ungapped_genomic_align_blocks(
                      $ungapped_genomic_align_blocks
                  );
  Description: Takes a list of ungapped Bio::EnsEMBL::Compara::GenomicAlignBlock
               objects and creates a new Bio::EnsEMBL::Compara::GenomicAlignBlock
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : lots...
  Caller     : new()

=cut

sub _create_from_a_list_of_ungapped_genomic_align_blocks {
  my ($self, $ungapped_genomic_align_blocks) = @_;

  ## Set adaptor
  my $adaptor = undef;
  foreach my $genomic_align_block (@$ungapped_genomic_align_blocks) {
    if ($genomic_align_block->adaptor) {
      $self->adaptor($adaptor);
      last;
    }
  }
  
  ## Set method_link_species_set
  my $method_link_species_set = undef;
  foreach my $genomic_align_block (@$ungapped_genomic_align_blocks) {
    if ($genomic_align_block->method_link_species_set) {
      if ($method_link_species_set) {
        if ($method_link_species_set->dbID != $genomic_align_block->method_link_species_set->dbID) {
          warning("Creating a GenomicAlignBlock from a list of ungapped GenomicAlignBlock with".
              " different method_link_species_set is not supported");
          return undef;
        }
      } else {
        $method_link_species_set = $genomic_align_block->method_link_species_set;
      }
    }
  }
  $self->method_link_species_set($method_link_species_set);
  
  ## Set method_link_species_set_id
  my $method_link_species_set_id = undef;
  foreach my $genomic_align_block (@$ungapped_genomic_align_blocks) {
    if ($genomic_align_block->method_link_species_set_id) {
      if ($method_link_species_set_id) {
        if ($method_link_species_set_id != $genomic_align_block->method_link_species_set_id) {
          warning("Creating a GenomicAlignBlock from a list of ungapped GenomicAlignBlock with".
              " different method_link_species_set_id is not supported");
          return undef;
        }
      } else {
        $method_link_species_set_id = $genomic_align_block->method_link_species_set_id;
      }
    }
  }
  $self->method_link_species_set_id($method_link_species_set_id);

  my $genomic_aligns;
  ## Check blocks and create new genomic_aligns
  foreach my $genomic_align_block (@$ungapped_genomic_align_blocks) {
    foreach my $this_genomic_align (@{$genomic_align_block->get_all_GenomicAligns}) {
      my $dnafrag_id = $this_genomic_align->dnafrag_id;
      if (!defined($genomic_aligns->{$dnafrag_id})) {
        $genomic_aligns->{$dnafrag_id} = new Bio::EnsEMBL::Compara::GenomicAlign(
                -adaptor => $this_genomic_align->adaptor,
                -method_link_species_set => $method_link_species_set,
                -method_link_species_set_id => $method_link_species_set_id,
                -dnafrag => $this_genomic_align->dnafrag,
                -dnafrag_start => $this_genomic_align->dnafrag_start,
                -dnafrag_end => $this_genomic_align->dnafrag_end,
                -dnafrag_strand => $this_genomic_align->dnafrag_strand,
            );
      } else {
        ## Check strand
        if ($this_genomic_align->dnafrag_strand < $genomic_aligns->{$dnafrag_id}->dnafrag_strand) {
          warning("The list of ungapped GenomicAlignBlock is inconsistent in strand");
          return undef;
        }

        ## Check order and lengthen genomic_align
        if ($this_genomic_align->dnafrag_strand == -1) {
          if ($this_genomic_align->dnafrag_end >= $genomic_aligns->{$dnafrag_id}->dnafrag_start) {
            warning("The list of ungapped GenomicAlignBlock must be previously sorted");
            return undef;
          }
          $genomic_aligns->{$dnafrag_id}->dnafrag_start($this_genomic_align->dnafrag_start);
        } else {
          if ($this_genomic_align->dnafrag_start <= $genomic_aligns->{$dnafrag_id}->dnafrag_end) {
            warning("The list of ungapped GenomicAlignBlock must be previously sorted");
            return undef;
          }
          $genomic_aligns->{$dnafrag_id}->dnafrag_end($this_genomic_align->dnafrag_end);
        }
      }
    }
  }
  
  ## Create cigar lines
  my $cigar_lines;
  for (my $i=0; $i<@$ungapped_genomic_align_blocks; $i++) {
    my $genomic_align_block = $ungapped_genomic_align_blocks->[$i];
    my $block_length = 0;
    ## Calculate block length
    foreach my $this_genomic_align (@{$genomic_align_block->get_all_GenomicAligns}) {
      if ($block_length) {
        if ($block_length != CORE::length($this_genomic_align->aligned_sequence)) {
          warning("The list of ungapped GenomicAlignBlock is inconsistent in gaps");
          return undef;
        }
      } else {
        $block_length = CORE::length($this_genomic_align->aligned_sequence);
      }
    }
    ## Fix cigar line according to block length
    while (my ($id, $genomic_align) = each %{$genomic_aligns}) {
      my $is_included_in_this_block = 0;
      foreach my $this_genomic_align (@{$genomic_align_block->get_all_GenomicAligns}) {
        if ($this_genomic_align->dnafrag_id == $id) {
          $is_included_in_this_block = 1;
          $cigar_lines->{$id} .= $this_genomic_align->cigar_line;
          last;
        }
      }
      if (!$is_included_in_this_block) {
        $cigar_lines->{$id} .= $block_length."D";
      }
    }

    ## Add extra gaps between genomic_align_blocks
    if (defined($ungapped_genomic_align_blocks->[$i+1])) {
      foreach my $genomic_align1 (@{$genomic_align_block->get_all_GenomicAligns}) {
        foreach my $genomic_align2 (@{$ungapped_genomic_align_blocks->[$i+1]->get_all_GenomicAligns}) {
          next if ($genomic_align1->dnafrag_id != $genomic_align2->dnafrag_id);
          ## $gap is the piece of sequence of this dnafrag between this block and the next one
          my $gap;
          if ($genomic_align1->dnafrag_strand == 1) {
            $gap = $genomic_align2->dnafrag_start - $genomic_align1->dnafrag_end - 1;
          } else {
            $gap = $genomic_align1->dnafrag_start - $genomic_align2->dnafrag_end - 1;
          }
          if ($gap) {
            foreach my $genomic_align3 (@{$genomic_align_block->get_all_GenomicAligns}) {
              if ($genomic_align1->dnafrag_id == $genomic_align3->dnafrag_id) {
                ## Add (mis)matches for this sequence
                $cigar_lines->{$genomic_align3->dnafrag_id} .= $gap."M";
              } else {
                ## Add gaps for others
                $cigar_lines->{$genomic_align3->dnafrag_id} .= $gap."D";
              }
            }
          }
        }
      }
    }

  }

  while (my ($id, $genomic_align) = each %{$genomic_aligns}) {
    $genomic_align->cigar_line($cigar_lines->{$id});
    $self->add_GenomicAlign($genomic_align);
  }

  return $self;
}


=head2 get_all_ungapped_GenomicAlignBlocks (testing)

  Args       : none
  Example    : my $ungapped_genomic_align_blocks =
                   $self->get_all_ungapped_GenomicAlignBlocks();
  Description: split the GenomicAlignBlock object into a set of ungapped
               alignments
  Returntype : listref of Bio::EnsEMBL::Compara::GenomicAlignBlocks objects
  Exceptions : none
  Caller     : general

=cut

sub get_all_ungapped_GenomicAlignBlocks {
  my ($self) = @_;
  my $ungapped_genomic_align_blocks = [];

  my $genomic_aligns = $self->get_all_GenomicAligns;
  my $aln_length = CORE::length($genomic_aligns->[0]->aligned_sequence);
#   foreach my $this_genomic_align (@$genomic_aligns) {
#     print STDERR join(" - ", $this_genomic_align->dnafrag_start, $this_genomic_align->dnafrag_end,
#         $this_genomic_align->dnafrag_strand, $this_genomic_align->aligned_sequence), "\n";
#   }

  my $aln_pos = 0;
  my $gap;
  my $end_block_pos;
  do {
    $end_block_pos = undef;
    my $these_genomic_aligns_with_no_gaps;

    ## Get the (next) first gap from all the aligned sequences (sets: $gap_pos, $gap and $genomic_align_block_id)
    foreach my $this_genomic_align (@$genomic_aligns) {
      my $this_end_block_pos = index($this_genomic_align->aligned_sequence, "-", $aln_pos);
      if ($this_end_block_pos == $aln_pos) {
        ## try to find the end of the gaps
        my $gap_string = substr($this_genomic_align->aligned_sequence, $aln_pos);
        ($gap) = $gap_string =~ /^(\-+)/;
        my $gap_length = CORE::length($gap);
        $this_end_block_pos = $aln_pos+$gap_length;
      } else {
        $these_genomic_aligns_with_no_gaps->{$this_genomic_align} = $this_genomic_align;
      }
      $this_end_block_pos = CORE::length($this_genomic_align->aligned_sequence) if ($this_end_block_pos < 0); # no more gaps have been found in this sequence

      
      if (!defined($end_block_pos) or $this_end_block_pos < $end_block_pos) {
        $end_block_pos = $this_end_block_pos;
      }
    }

    if (scalar(keys(%$these_genomic_aligns_with_no_gaps)) > 1) {
      my $new_genomic_aligns;
      my $reference_genomic_align;
      foreach my $this_genomic_align (values %$these_genomic_aligns_with_no_gaps) {
        my $previous_seq = substr($this_genomic_align->aligned_sequence, 0, $aln_pos );
        $previous_seq =~ s/\-//g;
        my $dnafrag_start;
        my $dnafrag_end;
        my $cigar_line;
        if ($this_genomic_align->dnafrag_strand == 1) {
          $dnafrag_start = $this_genomic_align->dnafrag_start + CORE::length($previous_seq);
          $dnafrag_end = $dnafrag_start + $end_block_pos - $aln_pos - 1;
          $cigar_line = ($end_block_pos - $aln_pos)."M";
        } else {
          $dnafrag_end = $this_genomic_align->dnafrag_end - CORE::length($previous_seq);
          $dnafrag_start = $dnafrag_end - $end_block_pos + $aln_pos + 1;
          $cigar_line = ($end_block_pos - $aln_pos)."M";
        }
        my $new_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                -adaptor => $this_genomic_align->adaptor,
                -method_link_species_set => $this_genomic_align->method_link_species_set,
                -dnafrag => $this_genomic_align->dnafrag,
                -dnafrag_start => $dnafrag_start,
                -dnafrag_end => $dnafrag_end,
                -dnafrag_strand => $this_genomic_align->dnafrag_strand,
                -cigar_line => $cigar_line,
            );
        $reference_genomic_align = $new_genomic_align
            if (defined($self->reference_genomic_align) and
                $self->reference_genomic_align == $this_genomic_align);
        push(@$new_genomic_aligns, $new_genomic_align);
      }
      ## Create a new GenomicAlignBlock
      my $new_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
              -method_link_species_set => $self->method_link_species_set,
              -length => $end_block_pos - $aln_pos,
              -genomic_align_array => $new_genomic_aligns,
          );
      $new_genomic_align_block->reference_genomic_align($reference_genomic_align) if (defined($reference_genomic_align));
      push(@$ungapped_genomic_align_blocks, $new_genomic_align_block);
    }
    $aln_pos = $end_block_pos;

  } while ($aln_pos < $aln_length); # exit loop if no gap has been found

  return $ungapped_genomic_align_blocks;
}


=head2 reverse_complement

  Args       : none
  Example    : none
  Description: reverse complement the ,
               modifying dnafrag_strand and cigar_line of each GenomicAlign in consequence
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub reverse_complement {
  my ($self) = @_;

  my $gas = $self->get_all_GenomicAligns;
  foreach my $ga (@{$gas}) {
    $ga->reverse_complement;
  }
}

=head2 _print

  Arg [1]    : none
  Example    : $genomic_align->_print
  Description: print attributes of the object to the STDOUT. Used for debuging purposes.
  Returntype : none
  Exceptions : 
  Caller     : object::methodname

=cut

sub _print {
  my ($self, $FILEH) = @_;

  my $verbose = verbose;
  verbose(0);
  $FILEH ||= \*STDOUT;
  print $FILEH
"Bio::EnsEMBL::Compara::GenomicAlignBlock object ($self)
  dbID = ".($self->dbID or "-undef-")."
  adaptor = ".($self->adaptor or "-undef-")."
  method_link_species_set = ".($self->method_link_species_set or "-undef-")."
  method_link_species_set_id = ".($self->method_link_species_set_id or "-undef-")."
  genomic_aligns = ".($self->genomic_align_array or "-undef-")."
  reference_genomic_align = ".($self->reference_genomic_align or "-undef-")."
  all_non_reference_genomic_aligns = ".($self->get_all_non_reference_genomic_aligns or "-undef-")."
  reference_slice = ".($self->reference_slice or "-undef-")."
  reference_slice_start = ".($self->reference_slice_start or "-undef-")."
  reference_slice_end = ".($self->reference_slice_end or "-undef-")."
  score = ".($self->score or "-undef-")."
  length = ".($self->length or "-undef-")."
  alignment_strings = \n  ".(join("\n  ", @{$self->alignment_strings}))."
  
";
  verbose($verbose);

}


#####################################################################
#####################################################################

=head1 METHODS FOR BACKWARDS COMPATIBILITY

Consensus and Query DnaFrag are no longer used. DO NOT USE THOSE METHODS IN NEW SCRIPTS, THEY WILL DISSAPEAR!!

For backwards compatibility, consensus_genomic_align correponds to the lower genome_db_id by convention.
This convention works for pairwise alignment only! Trying to use the old API methods for multiple
alignments will throw an exception.

=cut

#####################################################################
#####################################################################


=head2 get_old_consensus_genomic_align [FOR BACKWARDS COMPATIBILITY ONLY]
 
  Arg [1]    : none
  Example    : $old_consensus_genomic_aligns = $genomic_align_group->get_old_consensus_genomic_align();
  Description: get the Bio::EnsEMBL::Compara::GenomicAlign object following the convention for backwards
               compatibility
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : 
  Caller     : general
 
=cut

sub get_old_consensus_genomic_align {
  my ($self) = @_;

  my $genomic_aligns = $self->get_all_GenomicAligns;
  if (!@$genomic_aligns) {
    throw "Bio::EnsEMBL::Compara::GenomicAlignBlock ($self) does not have any associated".
        " Bio::EnsEMBL::Compara::GenomicAlign";
  }

  if (scalar(@{$genomic_aligns}) != 2) {
    throw "Trying to get old_consensus_genomic_align from Bio::EnsEMBL::Compara::GenomicAlignBlock".
        " ($self) holding a multiple alignment";
  }

  if ($genomic_aligns->[0]->dnafrag->genome_db->dbID > $genomic_aligns->[1]->dnafrag->genome_db->dbID) {
    return $genomic_aligns->[1];

  } elsif ($genomic_aligns->[0]->dnafrag->genome_db->dbID < $genomic_aligns->[1]->dnafrag->genome_db->dbID) {
    return $genomic_aligns->[0];

  ## If they belongs to the same genome_db, use the dnafrag_id instead
  } elsif ($genomic_aligns->[0]->dnafrag->dbID > $genomic_aligns->[1]->dnafrag->dbID) {
    return $genomic_aligns->[1];

  } elsif ($genomic_aligns->[0]->dnafrag->dbID < $genomic_aligns->[1]->dnafrag->dbID) {
    return $genomic_aligns->[0];

  ## If they belongs to the same genome_db and dnafrag, use the dnafrag_start instead
  } elsif ($genomic_aligns->[0]->dnafrag_start > $genomic_aligns->[1]->dnafrag_start) {
    return $genomic_aligns->[1];

  } elsif ($genomic_aligns->[0]->dnafrag_start < $genomic_aligns->[1]->dnafrag_start) {
    return $genomic_aligns->[0];

  ## If they belongs to the same genome_db and dnafrag and have the same danfrag_start, use the dnafrag_end instead
  } elsif ($genomic_aligns->[0]->dnafrag_end > $genomic_aligns->[1]->dnafrag_end) {
    return $genomic_aligns->[1];

  } elsif ($genomic_aligns->[0]->dnafrag_end < $genomic_aligns->[1]->dnafrag_end) {
    return $genomic_aligns->[0];

  ## If everithing else fails, use the dnafrag_strand
  } elsif ($genomic_aligns->[0]->dnafrag_strand > $genomic_aligns->[1]->dnafrag_strand) {
    return $genomic_aligns->[1];

  } elsif ($genomic_aligns->[0]->dnafrag_strand < $genomic_aligns->[1]->dnafrag_strand) {
    return $genomic_aligns->[0];

  # Whatever, they are the same. Use 0 for consensus and 1 for query
  } else {
    return $genomic_aligns->[0];
  }
}


=head2 get_old_query_genomic_align [FOR BACKWARDS COMPATIBILITY ONLY]
 
  Arg [1]    : none
  Example    : $old_query_genomic_aligns = $genomic_align_group->get_old_query_genomic_align();
  Description: get the Bio::EnsEMBL::Compara::GenomicAlign object following the convention for backwards
               compatibility
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : 
  Caller     : general
 
=cut

sub get_old_query_genomic_align {
  my ($self) = @_;

  my $genomic_aligns = $self->get_all_GenomicAligns;
  if (!@$genomic_aligns) {
    throw "Bio::EnsEMBL::Compara::GenomicAlignBlock ($self) does not have any associated".
        " Bio::EnsEMBL::Compara::GenomicAlign";
  }
  
  if (scalar(@{$genomic_aligns}) != 2) {
    throw "Trying to get old_consensus_genomic_align from Bio::EnsEMBL::Compara::GenomicAlignBlock".
        " ($self) holding a multiple alignment";
  }

  if ($genomic_aligns->[0]->dnafrag->genome_db->dbID > $genomic_aligns->[1]->dnafrag->genome_db->dbID) {
    return $genomic_aligns->[0];

  } elsif ($genomic_aligns->[0]->dnafrag->genome_db->dbID < $genomic_aligns->[1]->dnafrag->genome_db->dbID) {
    return $genomic_aligns->[1];

  ## If they belongs to the same genome_db, use the dnafrag_id instead
  } elsif ($genomic_aligns->[0]->dnafrag->dbID > $genomic_aligns->[1]->dnafrag->dbID) {
    return $genomic_aligns->[0];

  } elsif ($genomic_aligns->[0]->dnafrag->dbID < $genomic_aligns->[1]->dnafrag->dbID) {
    return $genomic_aligns->[1];

  ## If they belongs to the same genome_db and dnafrag, use the dnafrag_start instead
  } elsif ($genomic_aligns->[0]->dnafrag_start > $genomic_aligns->[1]->dnafrag_start) {
    return $genomic_aligns->[0];

  } elsif ($genomic_aligns->[0]->dnafrag_start < $genomic_aligns->[1]->dnafrag_start) {
    return $genomic_aligns->[1];

  ## If they belongs to the same genome_db and dnafrag and have the same danfrag_start, use the dnafrag_end instead
  } elsif ($genomic_aligns->[0]->dnafrag_end > $genomic_aligns->[1]->dnafrag_end) {
    return $genomic_aligns->[0];

  } elsif ($genomic_aligns->[0]->dnafrag_end < $genomic_aligns->[1]->dnafrag_end) {
    return $genomic_aligns->[1];

  ## If everithing else fails, use the dnafrag_strand
  } elsif ($genomic_aligns->[0]->dnafrag_strand > $genomic_aligns->[1]->dnafrag_strand) {
    return $genomic_aligns->[0];

  } elsif ($genomic_aligns->[0]->dnafrag_strand < $genomic_aligns->[1]->dnafrag_strand) {
    return $genomic_aligns->[1];

  # Whatever, they are the same. Use 0 for consensus and 1 for query
  } else {
    return $genomic_aligns->[1];
  }
}

1;
