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
  $genomic_align_block->starting_genomic_align_id(35123);
  $genomic_align_block->genomic_align_array([$genomic_align1, $genomic_align2]);
  $genomic_align_block->requesting_slice($requesting_slice);
  $genomic_align_block->requesting_slice_start(1035);
  $genomic_align_block->requesting_slice_end(1283);
  $genomic_align_block->score(56.2);
  $genomic_align_block->length(562);

GET VALUES
  my $genomic_align_block_adaptor = $genomic_align_block->adaptor();
  my $dbID = $genomic_align_block->dbID();
  my $method_link_species_set = $genomic_align_block->method_link_species_set;
  my $genomic_aligns = $genomic_align_block->genomic_align_array();
  my $starting_genomic_align = $genomic_align_block->starting_genomic_align();
  my $resulting_genomic_aligns = $genomic_align_block->resulting_genomic_aligns();
  my $requesting_slice = $genomic_align_block->requesting_slice();
  my $requesting_slice_start = $genomic_align_block->requesting_slice_start();
  my $requesting_slice_end = $genomic_align_block->requesting_slice_end();
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

Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet object corresponding to method_link_species_set_id

=item score

corresponds to genomic_align_block.score

=item perc_id

corresponds to genomic_align_block.perc_id

=item length

corresponds to genomic_align_block.length

=item starting_genomic_align_id

When looking for genomic alignments in a given slice or dnafrag, the
starting_genomic_align corresponds to the Bio::EnsEMBL::Compara::GenomicAlign
included in the starting slice or dnafrag. The starting_genomic_align_id is
the dbID corresponding to the starting_genomic_align. All remaining
Bio::EnsEMBL::Compara::GenomicAlign objects included in the
Bio::EnsEMBL::Compara::GenomicAlignBlock are the resulting_genomic_aligns.

=item genomic_align_array

listref of Bio::EnsEMBL::Compara::DBSQL::GenomicAlign objects corresponding to this
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlock object

=item requesting_slice

This is the Bio::EnsEMBL::Slice object used as argument to the
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->fetch_all_by_Slice method.

=item requesting_slice_start

starting position in the coordinates system defined by the requesting_slice

=item requesting_slice_end

ending position in the coordinates system defined by the requesting_slice

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
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);


=head2 new (CONSTRUCTOR)

  Arg[1]     : a reference to a hash where keys can be:
                 -adaptor
                 -dbID
                 -method_link_species_set
                 -method_link_species_set_id
                 -score
                 -perc_id
                 -length
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
          $score, $perc_id, $length, $starting_genomic_align_id, $genomic_align_array) = 
    rearrange([qw(
        ADAPTOR DBID METHOD_LINK_SPECIES_SET METHOD_LINK_SPECIES_SET_ID
        SCORE PERC_ID LENGTH STARTING_GENOMIC_ALIGN_ID GENOMIC_ALIGN_ARRAY)], @args);

  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->dbID($dbID) if (defined ($dbID));
  $self->method_link_species_set($method_link_species_set) if (defined ($method_link_species_set));
  $self->method_link_species_set_id($method_link_species_set_id) if (defined ($method_link_species_set_id));
  $self->score($score) if (defined ($score));
  $self->perc_id($perc_id) if (defined ($perc_id));
  $self->length($length) if (defined ($length));
  $self->starting_genomic_align_id($starting_genomic_align_id) if (defined($starting_genomic_align_id));
  $self->genomic_align_array($genomic_align_array) if (defined($genomic_align_array));

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


=head2 starting_genomic_align_id
 
  Arg [1]    : integer $starting_genomic_align_id
  Example    : $genomic_align_block->starting_genomic_align_id(4321);
  Description: set for attribute starting_genomic_align_id. A value of 0 will set the
               starting_genomic_align_id attribute to undef. When looking for genomic
               alignments in a given slice or dnafrag, the starting_genomic_align
               corresponds to the Bio::EnsEMBL::Compara::GenomicAlign included in the
               starting slice or dnafrag. The starting_genomic_align_id is the dbID
               corresponding to the starting_genomic_align. All remaining
               Bio::EnsEMBL::Compara::GenomicAlign objects included in the
               Bio::EnsEMBL::Compara::GenomicAlignBlock are the resulting_genomic_aligns.
  Returntype : none
  Exceptions : throw if $starting_genomic_align_id id not a postive number
  Caller     : $genomic_align_block->starting_genomic_align_id(int)
 
=cut

sub starting_genomic_align_id {
  my ($self, $starting_genomic_align_id) = @_;
 
  if ($starting_genomic_align_id !~ /^\d+$/) {
    throw "[$starting_genomic_align_id] should be a positive number.";
  }
  $self->{'starting_genomic_align_id'} = ($starting_genomic_align_id or undef);
}


=head2 starting_genomic_align
 
  Arg [1]    : (none)
  Example    : $genomic_align = $genomic_align_block->starting_genomic_align();
  Description: get the starting_genomic_align. When looking for genomic alignments in
               a given slice or dnafrag, the starting_genomic_align corresponds to the
               Bio::EnsEMBL::Compara::GenomicAlign included in the starting slice or
               dnafrag. The starting_genomic_align_id is the dbID corresponding to the
               starting_genomic_align. All remaining Bio::EnsEMBL::Compara::GenomicAlign
               objects included in the Bio::EnsEMBL::Compara::GenomicAlignBlock are the
               resulting_genomic_aligns.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : warns if no starting_genomic_align_id has been set and returns a ref.
               to an empty array
  Exceptions : warns if no genomic_align_array has been set and returns a ref.
               to an empty array
  Exceptions : throw if starting_genomic_align_id does not match any of the
               Bio::EnsEMBL::Compara::GenomicAlign objects in the genomic_align_array
  Caller     : $genomic_align_block->starting_genomic_align()
 
=cut

sub starting_genomic_align {
  my ($self) = @_;
 
  my $starting_genomic_align_id = $self->{'starting_genomic_align_id'};
  if (!defined($starting_genomic_align_id)) {
    warning("Trying to get Bio::EnsEMBL::Compara::GenomicAlign::starting_genomic_align when no".
        " starting_genomic_align_id has been set before");
    return undef;
  }
  my $genomic_align_array = $self->genomic_align_array; ## Lazy loading compliant
  if (!defined($genomic_align_array)) {
    warning("Trying to get Bio::EnsEMBL::Compara::GenomicAlign::starting_genomic_align when no".
        " genomic_align_array can be retrieved");
    return undef;
  }

  foreach my $this_genomic_align (@$genomic_align_array) {
    if ($this_genomic_align->dbID == $starting_genomic_align_id) {
      return $this_genomic_align;
    }
  }
  throw("[$self] Cannot found Bio::EnsEMBL::Compara::GenomicAlign::starting_genomic_align_id".
      " ($starting_genomic_align_id) in the genomic_align_array");
}


=head2 resulting_genomic_aligns
 
  Arg [1]    : (none)
  Example    : $genomic_aligns = $genomic_align_block->resulting_genomic_aligns();
  Description: get the resulting_genomic_aligns. When looking for genomic alignments in
               a given slice or dnafrag, the starting_genomic_align corresponds to the
               Bio::EnsEMBL::Compara::GenomicAlign included in the starting slice or
               dnafrag. The starting_genomic_align_id is the dbID corresponding to the
               starting_genomic_align. All remaining Bio::EnsEMBL::Compara::GenomicAlign
               objects included in the Bio::EnsEMBL::Compara::GenomicAlignBlock are the
               resulting_genomic_aligns.
  Returntype : a ref. to an array of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : warns if no starting_genomic_align_id has been set and returns a ref.
               to an empty array
  Exceptions : warns if no genomic_align_array has been set and returns a ref.
               to an empty array
  Caller     : $genomic_align_block->resulting_genomic_aligns()
 
=cut

sub resulting_genomic_aligns {
  my ($self) = @_;
  my $resulting_genomic_aligns = [];
 
  my $starting_genomic_align_id = $self->{'starting_genomic_align_id'};
  if (!defined($starting_genomic_align_id)) {
    warning("Trying to get Bio::EnsEMBL::Compara::GenomicAlign::starting_genomic_align when no".
        " starting_genomic_align_id has been set before");
    return $resulting_genomic_aligns
  }
  my $genomic_align_array = $self->genomic_align_array; ## Lazy loading compliant
  if (!defined($genomic_align_array)) {
    warning("Trying to get Bio::EnsEMBL::Compara::GenomicAlign::starting_genomic_align when no".
        " genomic_align_array can be retrieved");
    return $resulting_genomic_aligns
  }

  foreach my $this_genomic_align (@$genomic_align_array) {
    if ($this_genomic_align->dbID != $starting_genomic_align_id) {
      push(@$resulting_genomic_aligns, $this_genomic_align);
    }
  }

  return $resulting_genomic_aligns;
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
        $genomic_align_adaptor->fetch_all_by_genomic_align_block($self->{'dbID'});
  }
  
  return $self->{'genomic_align_array'};
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
    }
  }
  
  return $self->{'length'};
}


=head2 requesting_slice
 
  Arg [1]    : Bio::EnsEMBL::Slice $requesting_slice
  Example    : my $requesting_slice = $genomic_align_block->requesting_slice;
  Example    : $genomic_align_block->requesting_slice_start($requesting_slice);
  Description: get/set for attribute requesting_slice.
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : throw if $requesting_slice is not a Bio::EnsEMBL::Slice
  Caller     : general

=cut

sub requesting_slice {
  my ($self, $requesting_slice) = @_;
 
  if (defined($requesting_slice)) {
    throw "[$requesting_slice] is not a Bio::EnsEMBL::Slice"
        unless $requesting_slice->isa("Bio::EnsEMBL::Slice");
    $self->{'requesting_slice'} = $requesting_slice;
  }

  return $self->{'requesting_slice'};
}


=head2 requesting_slice_start
 
  Arg [1]    : integer $requesting_slice_start
  Example    : my $requesting_slice_start = $genomic_align_block->requesting_slice_start;
  Example    : $genomic_align_block->requesting_slice_start(1035);
  Description: get/set for attribute requesting_slice_start. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub requesting_slice_start {
  my ($self, $requesting_slice_start) = @_;
 
  if (defined($requesting_slice_start)) {
    $self->{'requesting_slice_start'} = ($requesting_slice_start or undef);
  }
  
  return $self->{'requesting_slice_start'};
}


=head2 requesting_slice_end
 
  Arg [1]    : integer $requesting_slice_end
  Example    : my $requesting_slice_end = $genomic_align_block->requesting_slice_end;
  Example    : $genomic_align_block->requesting_slice_end(1283);
  Description: get/set for attribute requesting_slice_end. A value of 0 will set
               the attribute to undefined.
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub requesting_slice_end {
  my ($self, $requesting_slice_end) = @_;
 
  if (defined($requesting_slice_end)) {
    $self->{'requesting_slice_end'} = ($requesting_slice_end or undef);
  }
  
  return $self->{'requesting_slice_end'};
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

  return $alignment_strings if (!$self->genomic_align_array);
  foreach my $genomic_align (@{$self->genomic_align_array}) {
    push(@$alignment_strings, $genomic_align->aligned_sequence);
  }

  return $alignment_strings;
}


=head2 get_SimpleAlign

  Arg [1]    : list of string $flags
               translated = by default, the sequence alignment will be on nucleotide. With translated flag
                            the aligned sequences are translated.
               uc = by default aligned sequences are given in lower cases. With uc flag, the aligned
                    sequences are given in upper cases.
  Example    : $daf->get_SimpleAlign or
               $daf->get_SimpleAlign("translated") or
               $daf->get_SimpleAlign("translated","uc")
  Description: Allows to rebuild the alignment string of all the genomic_align objects within
               this genomic_align_block using the cigar_string information
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

  for my $flag ( @flags ) {
    $uc = 1 if ($flag =~ /^uc$/i);
    $translated = 1 if ($flag =~ /^translated$/i);
  }

  my $sa = Bio::SimpleAlign->new();

  #Hack to try to work with both bioperl 0.7 and 1.2:
  #Check to see if the method is called 'addSeq' or 'add_seq'
  my $bio07 = 0;
  if(!$sa->can('add_seq')) {
    $bio07 = 1;
  }

  foreach my $genomic_align (@{$self->genomic_align_array}) {
    my $alignSeq = $genomic_align->aligned_sequence;
    
    my $loc_seq = Bio::LocatableSeq->new(-SEQ    => $uc ? uc $alignSeq : lc $alignSeq,
                                         -START  => $genomic_align->dnafrag_start,
                                         -END    => $genomic_align->dnafrag_end,
                                         -ID     => $genomic_align->display_id,
                                         -STRAND => $genomic_align->dnafrag_strand);

    $loc_seq->seq($uc ? uc $loc_seq->translate->seq
                      : lc $loc_seq->translate->seq) if ($translated);

    if($bio07) { $sa->addSeq($loc_seq); }
    else       { $sa->add_seq($loc_seq); }
                     
  }
  return $sa;
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

  $FILEH ||= \*STDOUT;
  print $FILEH
"Bio::EnsEMBL::Compara::GenomicAlignBlock object ($self)
  dbID = ".($self->dbID or "-undef-")."
  adaptor = ".($self->adaptor or "-undef-")."
  method_link_species_set = ".($self->method_link_species_set or "-undef-")."
  method_link_species_set_id = ".($self->method_link_species_set_id or "-undef-")."
  genomic_aligns = ".($self->genomic_align_array or "-undef-")."
  starting_genomic_align = ".($self->starting_genomic_align or "-undef-")."
  resulting_genomic_aligns = ".($self->resulting_genomic_aligns or "-undef-")."
  requesting_slice = ".($self->requesting_slice or "-undef-")."
  requesting_slice_start = ".($self->requesting_slice_start or "-undef-")."
  requesting_slice_end = ".($self->requesting_slice_end or "-undef-")."
  score = ".($self->score or "-undef-")."
  length = ".($self->length or "-undef-")."
  alignment_strings = ".($self->alignment_strings or "-undef-")."
  
";

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

  my $genomic_aligns = $self->genomic_align_array;
  if (!$genomic_aligns) {
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

  my $genomic_aligns = $self->genomic_align_array;
  if (!$genomic_aligns) {
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
