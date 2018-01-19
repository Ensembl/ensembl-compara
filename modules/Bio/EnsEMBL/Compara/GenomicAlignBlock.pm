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
  my $non_reference_genomic_aligns = $genomic_align_block->get_all_non_reference_genomic_aligns();
  my $reference_slice = $genomic_align_block->reference_slice();
  my $reference_slice_start = $genomic_align_block->reference_slice_start();
  my $reference_slice_end = $genomic_align_block->reference_slice_end();
  my $score = $genomic_align_block->score();
  my $length = $genomic_align_block->length;
  my alignment_strings = $genomic_align_block->alignment_strings;
  my $genomic_align_block_is_on_the_original_strand =
      $genomic_align_block->original_strand;

=head1 DESCRIPTION

The GenomicAlignBlock object stores information about an alignment comprising of two or more pieces of genomic DNA.


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

=item group_id

corresponds to the genomic_align_block.group_id

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

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomicAlignBlock;
use strict;
use warnings;

# Object preamble
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info verbose deprecate);
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::SimpleAlign;
use Bio::EnsEMBL::Compara::BaseGenomicAlignSet;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseGenomicAlignSet Bio::EnsEMBL::Storable);

=head2 new (CONSTRUCTOR)

  Arg [-DBID] : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]
              : (opt.) Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor $adaptor
                (the adaptor for connecting to the database)
  Arg [-METHOD_LINK_SPECIES_SET]
              : (opt.) Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
                (this defines the type of alignment and the set of species used
                to get this GenomicAlignBlock)
  Arg [-METHOD_LINK_SPECIES_SET_ID]
              : (opt.) int $mlss_id (the database internal ID for the $mlss)
  Arg [-SCORE]: (opt.) float $score (the score of this alignment)
  Arg [-PERC_ID]
              : (opt.) int $perc_id (the percentage of identity, only used for pairwise)
  Arg [-LENGTH]
              : (opt.) int $length (the length of this alignment, taking into account
                gaps and all)
  Arg [-GROUP_ID]
              : (opt.) int $group)id (the group ID for this alignment)
  Arg [-REFERENCE_GENOMIC_ALIGN]
              : (opt.) Bio::EnsEMBL::Compara::GenomicAlign $reference_genomic_align (the
                Bio::EnsEMBL::Compara::GenomicAlign corresponding to the requesting
                Bio::EnsEMBL::Compara::DnaFrag or Bio::EnsEMBL::Slice when this
                Bio::EnsEMBL::Compara::GenomicAlignBlock has been fetched from a
                Bio::EnsEMBL::Compara::DnaFrag or a Bio::EnsEMBL::Slice)
  Arg [-REFERENCE_GENOMIC_ALIGN_ID]
              : (opt.) int $reference_genomic_align (the database internal ID of the
                $reference_genomic_align)
  Arg [-GENOMIC_ALIGN_ARRAY]
              : (opt.) array_ref $genomic_aligns (a reference to the array of
                Bio::EnsEMBL::Compara::GenomicAlign objects corresponding to this
                Bio::EnsEMBL::Compara::GenomicAlignBlock object)
  Example    : my $genomic_align_block =
                   new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                       -adaptor => $gaba,
                       -method_link_species_set => $method_link_species_set,
                       -score => 56.2,
                       -length => 1203,
                       -group_id => 1234,
                       -genomic_align_array => [$genomic_align1, $genomic_align2...]
                   );
  Description: Creates a new GenomicAlignBlock object
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlock
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my($class, @args) = @_;
  
  my $self = {};
  bless $self,$class;
    
  my ($adaptor, $dbID, $method_link_species_set, $method_link_species_set_id,
          $score, $perc_id, $length, $group_id, $level_id, $reference_genomic_align, $reference_genomic_align_id,
          $genomic_align_array, $starting_genomic_align_id, $ungapped_genomic_align_blocks) = 
    rearrange([qw(
        ADAPTOR DBID METHOD_LINK_SPECIES_SET METHOD_LINK_SPECIES_SET_ID
        SCORE PERC_ID LENGTH GROUP_ID LEVEL_ID REFERENCE_GENOMIC_ALIGN REFERENCE_GENOMIC_ALIGN_ID
        GENOMIC_ALIGN_ARRAY STARTING_GENOMIC_ALIGN_ID UNGAPPED_GENOMIC_ALIGN_BLOCKS)],
            @args);

  $self->original_strand(1);

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
  $self->group_id($group_id) if (defined ($group_id));
  $self->level_id($level_id) if (defined ($level_id));
  $self->reference_genomic_align($reference_genomic_align)
      if (defined($reference_genomic_align));
  $self->reference_genomic_align_id($reference_genomic_align_id)
      if (defined($reference_genomic_align_id));
  $self->genomic_align_array($genomic_align_array) if (defined($genomic_align_array));

  $self->reference_genomic_align_id($starting_genomic_align_id) if (defined($starting_genomic_align_id));

  return $self;
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
  Status     : Stable

=cut

sub method_link_species_set {
  my ($self, $method_link_species_set) = @_;

  if (defined($method_link_species_set)) {
    throw("$method_link_species_set is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
        unless ($method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $self->{'method_link_species_set'} = $method_link_species_set;
    if ($self->{'method_link_species_set_id'}) {
      $self->{'method_link_species_set_id'} = $self->{'method_link_species_set'}->dbID;
    }
    ## Update the MethodLinkSpeciesSet for the GenomicAligns included in this GenomicAlignBlock
    if (defined($self->{genomic_align_array})) {
      foreach my $this_genomic_align (@{$self->{genomic_align_array}}) {
        $this_genomic_align->method_link_species_set($method_link_species_set);
      }
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
  Status     : Stable

=cut

sub method_link_species_set_id {
  my ($self, $method_link_species_set_id) = @_;

  if (defined($method_link_species_set_id)) {
    $self->{'method_link_species_set_id'} = $method_link_species_set_id;
    if (defined($self->{'method_link_species_set'}) and $self->{'method_link_species_set_id'}) {
      $self->{'method_link_species_set'} = undef;
    }
    ## Update the MethodLinkSpeciesSet for the GenomicAligns included in this GenomicAlignBlock
    if (defined($self->{genomic_align_array})) {
      foreach my $this_genomic_align (@{$self->{genomic_align_array}}) {
        $this_genomic_align->method_link_species_set_id($method_link_species_set_id);
      }
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
  Status     : Stable

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
  Status     : Stable

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
        ($self->{'reference_genomic_align'}->dbID ne ($self->{'reference_genomic_align_id'} or 0))) {
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
  Status     : Stable

=cut

sub get_all_non_reference_genomic_aligns {
  my ($self) = @_;
  my $all_non_reference_genomic_aligns = [];
 
  my $reference_genomic_align_id = $self->reference_genomic_align_id;
  my $reference_genomic_align = $self->reference_genomic_align;
  if (!defined($reference_genomic_align_id) and !defined($reference_genomic_align)) {
    warning("Trying to get Bio::EnsEMBL::Compara::GenomicAlign::all_non_reference_genomic_aligns".
        " when no reference_genomic_align has been set before");
    return $all_non_reference_genomic_aligns;
  }
  my $genomic_aligns = $self->get_all_GenomicAligns; ## Lazy loading compliant
  if (!@$genomic_aligns) {
    warning("Trying to get Bio::EnsEMBL::Compara::GenomicAlign::all_non_reference_genomic_aligns".
        " when no genomic_align_array can be retrieved");
    return $all_non_reference_genomic_aligns;
  }

  foreach my $this_genomic_align (@$genomic_aligns) {
    if (($this_genomic_align->dbID or -1) ne ($reference_genomic_align_id or -2) and
        $this_genomic_align != $reference_genomic_align) {
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
               You can unset all cached GenomicAlign using 0 as argument. They will be
               loaded again from the database if needed.
  Returntype : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub genomic_align_array {
  my ($self, $genomic_align_array) = @_;
 
  if (defined($genomic_align_array)) {
    if (!$genomic_align_array) {
      ## Clean cache.
      $self->{'genomic_align_array'} = undef;
      $self->{'reference_genomic_align'} = undef;
      return undef;
    }
    foreach my $genomic_align (@$genomic_align_array) {
      throw("[$genomic_align] is not a Bio::EnsEMBL::Compara::GenomicAlign object")
          unless (ref $genomic_align and $genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));
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
  Status     : Stable

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

  Arg [1]    : (optional) arrayref of genome db ids 
  Example    : $genomic_aligns = $genomic_align_block->get_all_GenomicAligns();
  Description: returns the set of Bio::EnsEMBL::Compara::GenomicAlign objects in
               the attribute genomic_align_array.
  Returntype : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub get_all_GenomicAligns {
  my ($self, $genome_db_id) = @_;

  if (defined($genome_db_id)) {
    my %gdb_id = ();
    foreach my $id (@{$genome_db_id}) {
      $gdb_id{$id}= 1;
    }
    my $ggaln=[];
    foreach my $galn (@{$self->genomic_align_array or []}){
      if ( exists $gdb_id{$galn->genome_db->dbID()}) {
        push (@$ggaln, $galn);
      }
    }
    return ($ggaln); 
  }
 
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
  Status     : Stable

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
  Status     : Stable

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
  Status     : Stable

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
    } elsif (@{$self->get_all_GenomicAligns} and $self->get_all_GenomicAligns->[0]->aligned_sequence("+FAKE_SEQ")) {
      $self->{'length'} = CORE::length($self->get_all_GenomicAligns->[0]->aligned_sequence("+FAKE_SEQ"));
    }
  }
  
  return $self->{'length'};
}

=head2 group_id

  Arg [1]    : integer $group_id
  Example    : my $group_id = $genomic_align_block->group_id;
  Example    : $genomic_align_block->group_id(1234);
  Description: get/set for attribute group_id. 
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub group_id {
    my ($self, $group_id) = @_;

    if (defined($group_id)) {
	$self->{'group_id'} = ($group_id);
    } elsif (!defined($self->{'group_id'})) {
	# Try to get the ID from other sources...
	if (defined($self->{'adaptor'}) and defined($self->dbID)) {
	    # ...from the database, using the dbID of the Bio::Ensembl::Compara::GenomicAlignBlock object
	    $self->adaptor->retrieve_all_direct_attributes($self);
	}
    }
    return $self->{'group_id'};
}

=head2 level_id

  Arg [1]    : int $level_id
  Example    : $level_id = $genomic_align->level_id;
  Example    : $genomic_align->level_id(1);
  Description: get/set for attribute level_id. If no argument is given, the level_id
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : int
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname
  Status     : Stable

=cut

sub level_id {
  my ($self, $level_id) = @_;

  if (defined($level_id)) {
    $self->{'level_id'} = $level_id;

  } elsif (!defined($self->{'level_id'})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlignBlock object
      $self->adaptor->retrieve_all_direct_attributes($self);
    } else {
#      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlignBlock->level_id".
#          " You either have to specify more information (see perldoc for".
#          " Bio::EnsEMBL::Compara::GenomicAlignBlock) or to set it up directly");
    }
  }

  return $self->{'level_id'};
}


=head2 alignment_strings

  Arg [1]    : none
  Example    : $genomic_align_block->alignment_strings
  Description: Returns the alignment string of all the sequences in the
               alignment
  Returntype : array reference containing several strings
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub alignment_strings {
  my ($self) = @_;
  my $alignment_strings = [];

  foreach my $genomic_align (@{$self->get_all_GenomicAligns}) {
    push(@$alignment_strings, $genomic_align->aligned_sequence);
  }

  return $alignment_strings;
}

=head2 summary_as_hash

  Arg [1]    : (optional) arrayref of species to be displayed. Must be a subset of the species in the GenomicAlignBlock. Display all species if not set.
  Arg [2]    : (optional) string. Can be "soft" or "hard"
  Example    : $genomic_align_block->summary_as_hash(undef, "soft")
  Description: Retrieves a textual sumamry of this GenomicAlignBlock object
  Returntype : Array of hashref of descriptive strings
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub summary_as_hash {
  my ( $self, $display_species_set, $mask) = @_;

  my $all_genomic_aligns;
 
  #not currently used here but need to set
  my $description = "";
  if ($self->reference_genomic_align) {
    $all_genomic_aligns = [$self->reference_genomic_align,@{$self->get_all_non_reference_genomic_aligns}];
  } else {
    $all_genomic_aligns = $self->get_all_GenomicAligns();
  }

  my $alignment_summary;
  foreach my $genomic_align (@$all_genomic_aligns) {
    my $summary;
  
    #check if genomic_align is in $species list
    if ($display_species_set) {
       next unless (grep {$genomic_align->genome_db->name eq $_}  @$display_species_set);
    }

    my $seq_region =  $genomic_align->dnafrag->name;

    #No repeat masking for ancestral sequences
    if ($mask) {
        if ($mask =~ /^soft/ && $seq_region !~ /Ancestor/) {
            $genomic_align->original_sequence($genomic_align->get_Slice->get_repeatmasked_seq(undef,1)->seq);
        } elsif ($mask =~ /^hard/ && $seq_region !~ /Ancestor/) {
            $genomic_align->original_sequence($genomic_align->get_Slice->get_repeatmasked_seq()->seq);
        }
    }

    my $alignSeq = $genomic_align->aligned_sequence;
    next if($alignSeq=~/^[\.\-]+$/);

    %$summary = ('start' => $genomic_align->dnafrag_start,
		 'end'   => $genomic_align->dnafrag_end,
		 'strand' => $genomic_align->dnafrag_strand,
		 'species' => $genomic_align->dnafrag->genome_db->name,
		 'seq_region' => $genomic_align->dnafrag->name,
		 'seq' => $alignSeq,
		 'description' => $description);
    push @$alignment_summary, $summary;

  }
  return $alignment_summary;
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
  Caller     : general
  Status     : Stable

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
  $sa->missing_char('.'); # only useful for Nexus files

  my $all_genomic_aligns;
  if ($self->reference_genomic_align) {
    $all_genomic_aligns = [$self->reference_genomic_align,@{$self->get_all_non_reference_genomic_aligns}];
  } else {
    $all_genomic_aligns = $self->get_all_GenomicAligns();
  }

  foreach my $genomic_align (@$all_genomic_aligns) {

    my $alignSeq = $genomic_align->aligned_sequence;
    next if($alignSeq=~/^[\.\-]+$/);

    my $loc_seq = Bio::LocatableSeq->new(-SEQ    => $uc ? uc $alignSeq : lc $alignSeq,
                                         -START  => $genomic_align->dnafrag_start,
                                         #-END    => $genomic_align->dnafrag_end,
                                         -ID     => $display_id ? $genomic_align->display_id : ($genomic_align->dnafrag->genome_db->name . "/" . $genomic_align->dnafrag->name),
                                         -STRAND => $genomic_align->dnafrag_strand);
    # Avoid warning in BioPerl about len(seq) != end-start+1
    $loc_seq->{end} = $genomic_align->dnafrag_end;

    $loc_seq->seq($uc ? uc $loc_seq->translate->seq
                      : lc $loc_seq->translate->seq) if ($translated);

    $sa->add_seq($loc_seq);

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
  Status     : At risk

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

    next if ($block_length == 0); # Skip 0-length blocks (shouldn't happen)
    $block_length = "" if ($block_length == 1); # avoid a "1" in cigar_line

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
            $gap = "" if ($gap == 1);
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


=head2 get_all_ungapped_GenomicAlignBlocks

  Args       : (optional) listref $genome_dbs
  Example    : my $ungapped_genomic_align_blocks =
                   $self->get_all_ungapped_GenomicAlignBlocks();
  Example    : my $ungapped_genomic_align_blocks =
                   $self->get_all_ungapped_GenomicAlignBlocks([$human_genome_db, $mouse_genome_db]);
  Description: split the GenomicAlignBlock object into a set of ungapped
               alignments. If a list of genome_dbs is provided, only those
               sequences will be taken into account. This can be used to extract
               ungapped pairwise alignments from multiple alignments.
  Returntype : listref of Bio::EnsEMBL::Compara::GenomicAlignBlocks objects
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub get_all_ungapped_GenomicAlignBlocks {
  my ($self, $genome_dbs) = @_;
  my $ungapped_genomic_align_blocks = [];

  my $genomic_aligns = $self->get_all_GenomicAligns;
  if ($genome_dbs and @$genome_dbs) {
    my $these_genomic_aligns = [];
    foreach my $this_genomic_align (@$genomic_aligns) {
      if (grep {$this_genomic_align->genome_db->name eq $_->name} @$genome_dbs) {
        push(@$these_genomic_aligns, $this_genomic_align);
      }
    }
    if (@$these_genomic_aligns > 1) {
      $genomic_aligns = $these_genomic_aligns;
    } else {
      return [];
    }
  }
  my $aln_length = CORE::length($genomic_aligns->[0]->aligned_sequence("+FAKE_SEQ"));
#   foreach my $this_genomic_align (@$genomic_aligns) {
#     print STDERR join(" - ", $this_genomic_align->dnafrag_start, $this_genomic_align->dnafrag_end,
#         $this_genomic_align->dnafrag_strand, $this_genomic_align->aligned_sequence("+FAKE_SEQ")), "\n";
#   }

  my $aln_pos = 0;
  my $gap;
  my $end_block_pos;
  do {
    $end_block_pos = undef;
    my $these_genomic_aligns_with_no_gaps;

    ## Get the (next) first gap from all the aligned sequences (sets: $gap_pos, $gap and $genomic_align_block_id)
    foreach my $this_genomic_align (@$genomic_aligns) {
      my $this_end_block_pos = index($this_genomic_align->aligned_sequence("+FAKE_SEQ"), "-", $aln_pos);
      if ($this_end_block_pos == $aln_pos) {
        ## try to find the end of the gaps
        my $gap_string = substr($this_genomic_align->aligned_sequence("+FAKE_SEQ"), $aln_pos);
        ($gap) = $gap_string =~ /^(\-+)/;
        my $gap_length = CORE::length($gap);
        $this_end_block_pos = $aln_pos+$gap_length;
      } else {
        $these_genomic_aligns_with_no_gaps->{$this_genomic_align} = $this_genomic_align;
      }
      $this_end_block_pos = CORE::length($this_genomic_align->aligned_sequence("+FAKE_SEQ")) if ($this_end_block_pos < 0); # no more gaps have been found in this sequence

      
      if (!defined($end_block_pos) or $this_end_block_pos < $end_block_pos) {
        $end_block_pos = $this_end_block_pos;
      }
    }

    if (scalar(keys(%$these_genomic_aligns_with_no_gaps)) > 1) {
      my $new_genomic_aligns;
      my $reference_genomic_align;
      foreach my $this_genomic_align (values %$these_genomic_aligns_with_no_gaps) {
        my $previous_seq = substr($this_genomic_align->aligned_sequence("+FAKE_SEQ"), 0, $aln_pos );
        $previous_seq =~ s/\-//g;
        my $dnafrag_start;
        my $dnafrag_end;
        my $cigar_line;
        my $cigar_length = ($end_block_pos - $aln_pos);
        $cigar_length = "" if ($cigar_length == 1);
        if ($this_genomic_align->dnafrag_strand == 1) {
          $dnafrag_start = $this_genomic_align->dnafrag_start + CORE::length($previous_seq);
          $dnafrag_end = $dnafrag_start + $end_block_pos - $aln_pos - 1;
          $cigar_line = $cigar_length."M";
        } else {
          $dnafrag_end = $this_genomic_align->dnafrag_end - CORE::length($previous_seq);
          $dnafrag_start = $dnafrag_end - $end_block_pos + $aln_pos + 1;
          $cigar_line = $cigar_length."M";
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
  Status     : Stable

=cut

sub reverse_complement {
  my ($self) = @_;

  if (defined($self->original_strand)) {
    $self->original_strand(1 - $self->original_strand);
  } else {
    $self->original_strand(0);
  }

  my $gas = $self->get_all_GenomicAligns;
  foreach my $ga (@{$gas}) {
    $ga->reverse_complement;
  }
}

=head2 restrict_between_alignment_positions

  Arg[1]     : [optional] int $start, refers to the start of the alignment
  Arg[2]     : [optional] int $end, refers to the start of the alignment
  Arg[3]     : [optional] boolean $skip_empty_GenomicAligns
  Example    : none
  Description: restrict this GenomicAlignBlock. It returns a new object unless no
               restriction is needed. In that case, it returns the original unchanged
               object.
               This method uses coordinates relative to the alignment itself.
               For instance if you have an alignment like:
                            1    1    2    2    3
                   1   5    0    5    0    5    0
                   AAC--CTTGTGGTA-CTACTT-----ACTTT
                   AACCCCTT-TGGTATCTACTTACCTAACTTT
               and you restrict it between 5 and 25, you will get back a
               object containing the following alignment:
                            1    1
                   1   5    0    5
                   CTTGTGGTA-CTACTT----
                   CTT-TGGTATCTACTTACCT

               See restrict_between_reference_positions() elsewhere in this document
               for an alternative method using absolute genomic coordinates.

               NB: This method works only for GenomicAlignBlock which have been
               fetched from the DB as it is adjusting the dnafrag coordinates
               and the cigar_line only and not the actual sequences stored in the
               object if any. If you want to restrict an object with no coordinates
               a simple substr() will do!

  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub restrict_between_alignment_positions {
  my ($self, $start, $end, $skip_empty_GenomicAligns) = @_;
  my $genomic_align_block;
  my $new_reference_genomic_align;
  my $new_genomic_aligns;

  $start = 1 if (!defined($start) or $start < 1);
  $end = $self->length if (!defined($end) or $end > $self->length);

  my $number_of_columns_to_trim_from_the_start = $start - 1;
  my $number_of_columns_to_trim_from_the_end = $self->length - $end;

  ## Skip if no restriction is needed. Return original object! We are still going on with the
  ## restriction when either excess_at_the_start or excess_at_the_end are 0 as a (multiple)
  ## alignment may start or end with gaps in the reference species. In that case, we want to
  ## trim these gaps from the alignment as they fall just outside of the region of interest
  return $self if ($number_of_columns_to_trim_from_the_start <= 0
      and $number_of_columns_to_trim_from_the_end <= 0);

  my $final_alignment_length = $end - $start + 1;

  ## Create a new Bio::EnsEMBL::Compara::GenomicAlignBlock object with restricted GenomicAligns
  my $length = $self->{length};
  foreach my $this_genomic_align (@{$self->get_all_GenomicAligns}) {
    my $new_genomic_align = $this_genomic_align->restrict($start, $end, $length);
    if ($self->reference_genomic_align and $this_genomic_align == $self->reference_genomic_align) {
      $new_reference_genomic_align = $new_genomic_align;
    }
    push(@$new_genomic_aligns, $new_genomic_align);
  }
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -method_link_species_set => $self->method_link_species_set,
          -genomic_align_array => $new_genomic_aligns,
          -group_id => $self->group_id,
	        -level_id => $self->level_id,
      );
  $genomic_align_block->original_dbID($self->dbID or $self->original_dbID);
  $genomic_align_block->original_strand($self->original_strand);
  if ($new_reference_genomic_align) {
    $genomic_align_block->reference_genomic_align($new_reference_genomic_align);
  }
  $genomic_align_block->reference_slice($self->reference_slice);

  # The restriction might result in empty GenomicAligns. If the
  # skip_empty_GenomicAligns flag is set, remove them from the block.
  if ($skip_empty_GenomicAligns) {
    my $reference_genomic_align = $genomic_align_block->reference_genomic_align();
    my $genomic_align_array = $genomic_align_block->genomic_align_array;
    for (my $i=0; $i<@$genomic_align_array; $i++) {
      if ($genomic_align_array->[$i]->dnafrag_start > $genomic_align_array->[$i]->dnafrag_end) {
        splice(@$genomic_align_array, $i, 1);
        $i--;
      }
    }
    $genomic_align_block->reference_genomic_align($reference_genomic_align) if ($reference_genomic_align);
  }
  $genomic_align_block->length($final_alignment_length);

  return $genomic_align_block;
}

=head2 get_GenomicAlignTree

  Arg [1]    : none
  Example    : $genomic_align_block->get_GenomicAlignTree
  Description: Return a Bio::EnsEMBL::Compara::GenomicAlignTree object either from a GenomicAlignTreeAdaptor, a SpeciesTreeAdaptor or from the species set.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignTree
  Exceptions : throw if duplicate species found but no GenomicAlignTree object in the database
  Caller     : object::methodname
  Status     : At risk

=cut

sub get_GenomicAlignTree {
    my ($self) = @_;

    #Check if a GenomicAlignTree object already exists and return
    my $genomic_align_tree;
    unless ( $self->method_link_species_set->method->type =~ /CACTUS_HAL/  ) {
      eval {
          my $genomic_align_tree_adaptor = $self->adaptor->db->get_GenomicAlignTreeAdaptor;
          $genomic_align_tree = $genomic_align_tree_adaptor->fetch_by_GenomicAlignBlock($self);
      };
      return ($genomic_align_tree) if ($genomic_align_tree);
    }

    #Create lookup of names to GenomicAlign objects
    my $leaf_names;
    my $genomic_aligns = $self->get_all_GenomicAligns();

    foreach my $genomic_align (@$genomic_aligns) {
        #Throw if duplicates are found (and no GenomicAlignTree has been found)
        if (defined  $leaf_names->{$genomic_align->genome_db->dbID}) {
            throw ("Duplicate found for species " . $genomic_align->genome_db->dbID);
        }
        $leaf_names->{$genomic_align->genome_db->dbID} = $genomic_align;
    }

    #Create a tree as a newick format string
    my $species_tree_string;
    #For a pairwise GenomicAlignBlock, create a tree from scratch.
    if ($self->method_link_species_set->method->class eq "GenomicAlignBlock.pairwise_alignment") {
        my $species_set = $self->method_link_species_set->species_set;
        
        #Create species_tree in newick format. Do not get the branch lengths.
        $species_tree_string = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(-compara_dba => $self->adaptor->db,
                                                                                              -species_set => $species_set)->newick_format('ryo', '%{g}');
    } else {
        #Multiple alignment
        $species_tree_string = $self->method_link_species_set->species_tree->root->newick_format('ryo', '%{g}');
    }

    #Convert the newick format tree into a GenomicAlignTree object
    $genomic_align_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string, "Bio::EnsEMBL::Compara::GenomicAlignTree");

    my $ref_genomic_align = $self->reference_genomic_align;
    my $ref_genomic_align_node;

    #Prune the tree to just contain the species in this GenomicAlignBlock and add GenomicAlignGroup objects on the leaves
    my $all_leaves = $genomic_align_tree->get_all_leaves;
    foreach my $this_leaf (@$all_leaves) {        
        my $this_leaf_name = $this_leaf->name;

        if ($leaf_names->{$this_leaf_name}) {
            #add GenomicAlignGroup populated with GenomicAlign to leaf
	    my $this_genomic_align = $leaf_names->{$this_leaf_name};
            $this_leaf->name($this_genomic_align->genome_db->name);
            my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
            $genomic_align_group->add_GenomicAlign($leaf_names->{$this_leaf_name});
            $this_leaf->genomic_align_group($genomic_align_group);
	    if ($this_genomic_align->genome_db->name eq $ref_genomic_align->genome_db->name and
		$this_genomic_align->dnafrag->name eq $ref_genomic_align->dnafrag->name and
		$this_genomic_align->dnafrag_start eq $ref_genomic_align->dnafrag_start and
		$this_genomic_align->dnafrag_end eq $ref_genomic_align->dnafrag_end) {
	      $genomic_align_tree->reference_genomic_align_node($this_leaf);
	      $genomic_align_tree->reference_genomic_align($this_genomic_align);
	      $ref_genomic_align_node = $this_leaf;
	    }
        } else {
            #remove this leaf
            $this_leaf->disavow_parent;
            $genomic_align_tree = $genomic_align_tree->minimize_tree;
        }
    }
    $genomic_align_tree->root->reference_genomic_align($ref_genomic_align);
    $genomic_align_tree->root->reference_genomic_align_node($ref_genomic_align_node);

    return $genomic_align_tree;
}


sub _print {    ## DEPRECATED
  my ($self, $FILEH) = @_;

  deprecate('$genomic_align_block->_print() is deprecated and will be removed in e88. Use $genomic_align_block->toString() instead.');

  $FILEH ||= \*STDOUT;
  print $FILEH
"Bio::EnsEMBL::Compara::GenomicAlignBlock object ($self)
  dbID = ", ($self->dbID or "-undef-"), "
  adaptor = ", ($self->adaptor or "-undef-"), "
  method_link_species_set = ", ($self->method_link_species_set or "-undef-"), "
  method_link_species_set_id = ", ($self->method_link_species_set_id or "-undef-"), "
  genomic_aligns = ", (scalar(@{$self->genomic_align_array}) or "-undef-"), "
  score = ", ($self->score or "-undef-"), "
  length = ", ($self->length or "-undef-"), "
  alignments: \n";
  foreach my $this_genomic_align (@{$self->genomic_align_array()}) {
    my $species_name = $this_genomic_align->genome_db->name;
    my $slice = $this_genomic_align->dnafrag->slice;

    $slice = $slice->sub_Slice(
              $this_genomic_align->dnafrag_start,
              $this_genomic_align->dnafrag_end,
              $this_genomic_align->dnafrag_strand
          );

    if ($self->reference_genomic_align and $self->reference_genomic_align == $this_genomic_align) {
      print $FILEH "    * ", $this_genomic_align->genome_db->name, " ",
          ($slice?$slice->name:"--error--"), "\n";
    } else {
      print $FILEH "    - ", $this_genomic_align->genome_db->name, " ",
          ($slice?$slice->name:"--error--"), "\n";
    }
  }

}


=head2 toString

  Example    : print $genomic_align_block->toString();
  Description: used for debugging, returns a string with the key descriptive
               elements of this alignment block
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub toString {
    my $self = shift;

    my $str = "Bio::EnsEMBL::Compara::GenomicAlignBlock object ($self)
      dbID = " . ($self->dbID or "-undef-") . "
      adaptor = " . ($self->adaptor or "-undef-") . "
      method_link_species_set = " . ($self->method_link_species_set or "-undef-") . "
      method_link_species_set_id = " . ($self->method_link_species_set_id or "-undef-") . "
      genomic_aligns = " . (scalar(@{$self->genomic_align_array}) or "-undef-") . "
      score = " . ($self->score or "-undef-") . "
      length = " . ($self->length or "-undef-") . "
      alignments: \n";

    foreach my $this_genomic_align (@{$self->genomic_align_array()}) {
        my $species_name = $this_genomic_align->genome_db->name;
        my $slice = $this_genomic_align->dnafrag->slice;

        $slice = $slice->sub_Slice(
                  $this_genomic_align->dnafrag_start,
                  $this_genomic_align->dnafrag_end,
                  $this_genomic_align->dnafrag_strand
              );

        if ($self->reference_genomic_align and $self->reference_genomic_align == $this_genomic_align) {
          $str .= "    * " . $this_genomic_align->genome_db->name . " " . ($slice?$slice->name:"--error--") . "\n";
        } else {
          $str .= "    - " . $this_genomic_align->genome_db->name . " " . ($slice?$slice->name:"--error--") . "\n";
        }
    }

    return $str;
    # my $self = shift;
    # my $str = 'GenomicAlignBlock';
    # if ($self->original_dbID) {
    #     $str .= sprintf(' restricted from dbID=%s', $self->original_dbID);
    # } else {
    #     $str .= sprintf(' dbID=%s', $self->dbID);
    # }
    # $str .= sprintf(' (%s)', $self->method_link_species_set->name) if $self->method_link_species_set;
    # $str .= ' score='.$self->score if defined $self->score;
    # $str .= ' length='.$self->length if defined $self->length;
    # $str .= ' with ' . scalar(@{$self->genomic_align_array}) . ' GenomicAligns';
    # return $str;
}


1;
