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

Bio::EnsEMBL::Compara::GenomicAlignTree

=head1 DESCRIPTION

Specific subclass of NestedSet to add functionality when the nodes of this tree
are GenomicAlign objects and the tree is a representation of a Protein derived
Phylogenetic tree

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::GenomicAlignTree;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::SimpleAlign;
use IO::File;

use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::BaseGenomicAlignSet;

our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet Bio::EnsEMBL::Compara::BaseGenomicAlignSet);


=head2 left_node_id

  Arg [1]     : (optional) $left_node_id
  Example     : $object->left_node_id($left_node_id);
  Example     : $left_node_id = $object->left_node_id();
  Description : Getter/setter for the left_node_id attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub left_node_id {
  my $self = shift;
  if (@_) {
    $self->{_left_node_id} = shift;
  }
  return $self->{_left_node_id};
}


=head2 right_node_id

  Arg [1]     : (optional) $right_node_id
  Example     : $object->right_node_id($right_node_id);
  Example     : $right_node_id = $object->right_node_id();
  Description : Getter/setter for the right_node_id attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub right_node_id {
  my $self = shift;
  if (@_) {
    $self->{_right_node_id} = shift;
  }
  return $self->{_right_node_id};
}


=head2 left_node

  Arg [1]     : -none-
  Example     : $left_node = $object->left_node();
  Description : Get the left_node object from the database.
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignTree object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub left_node {
  my $self = shift;
  if ($self->{_left_node_id} and $self->adaptor) {
    return $self->adaptor->fetch_node_by_node_id($self->{_left_node_id});
  }
  return undef;
}


=head2 right_node

  Arg [1]     : -none-
  Example     : $left_node = $object->right_node();
  Description : Get the right_node object from the database.
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignTree object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub right_node {
  my $self = shift;
  if ($self->{_right_node_id} and $self->adaptor) {
    return $self->adaptor->fetch_node_by_node_id($self->{_right_node_id});
  }
  return undef;
}

=head2 ancestral_genomic_align_block_id

  Arg [1]     : (optional) $ancestral_genomic_align_block_id
  Example     : $object->ancestral_genomic_align_block_id($ancestral_genomic_align_block_id);
  Example     : $ancestral_genomic_align_block_id = $object->ancestral_genomic_align_block_id();
  Description : Getter/setter for the ancestral_genomic_align_block_id attribute
                This attribute is intended for the root of the tree only!
  Returntype  : int
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub ancestral_genomic_align_block_id {
  my $self = shift;
  if (@_) {
    $self->{_ancestral_genomic_align_block_id} = shift;
  }
  return $self->{_ancestral_genomic_align_block_id};
}


=head2 modern_genomic_align_block_id

  Arg [1]     : (optional) $modern_genomic_align_block_id
  Example     : $object->modern_genomic_align_block_id($modern_genomic_align_block_id);
  Example     : $modern_genomic_align_block_id = $object->modern_genomic_align_block_id();
  Description : Getter/setter for the modern_genomic_align_block_id attribute
  Returntype  : 
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub modern_genomic_align_block_id {
  my $self = shift;
  if (@_) {
    $self->{_modern_genomic_align_block_id} = shift;
  }
  return $self->{_modern_genomic_align_block_id};
}

=head2 get_modern_GenomicAlignBlock

  Example     : $modern_genomic_align_block = $object->modern_genomic_align_block();
  Description : Getter of the modern GenomicAlignBlock object 
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub get_modern_GenomicAlignBlock {
  my $self = shift;
  
  # Try to get data from other sources...
  if (!defined($self->{'modern_genomic_align_block'})) {

      #Try to retrieve from the first GenomicAlign object
      $self->{'modern_genomic_align_block'} = $self->get_all_leaves->[0]->genomic_align_group->get_all_GenomicAligns->[0]->genomic_align_block;

      #Try to retrieve from the modern_genomic_align_block_id 
      if ((!defined $self->{'modern_genomic_align_block'}) && (defined($self->modern_genomic_align_block_id) and defined($self->adaptor))) {
          my $genomic_align_block_adaptor = $self->adaptor->db->get_GenomicAlignBlockAdaptor;
          $self->{'modern_genomic_align_block'} = $genomic_align_block_adaptor->fetch_by_dbID($self->modern_genomic_align_block_id);
      }
      if ($self->{'modern_genomic_align_block'}) {
          #Set the original_strand to be the same as the current original_strand
          $self->{'modern_genomic_align_block'}->original_strand($self->original_strand);
      } else {
          warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlignTree->get_modern_GenomicAlignBlock".
                      " You either have to specify more information (see perldoc for".
                  " Bio::EnsEMBL::Compara::GenomicAlignTree)");
          return undef;
      }
  }
  return $self->{'modern_genomic_align_block'};

}


=head2 genomic_align_group

  Arg [1]     : (optional) $genomic_align_group
  Example     : $object->genomic_align_group($genomic_align_group);
  Example     : $genomic_align_group = $object->genomic_align_group();
  Description : Getter/setter for the genomic_align_group attribute
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignGroup object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub genomic_align_group {
  my $self = shift;
  if (@_) {
    $self->{_genomic_align_group} = shift;
  }
  return $self->{_genomic_align_group};
}


=head2 get_all_genomic_aligns_for_node

  Arg [1]     : -none-
  Example     : $genomic_aligns = $object->get_all_genomic_aligns_for_node
  Description : Getter for all the GenomicAligns contained in the
                genomic_align_group object on a node. This method is a short
                cut for $object->genomic_align_group->get_all_GenomicAligns()
  Returntype  : listref of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_genomic_aligns_for_node {
  my $self = shift(@_);
  return [] if (!$self->genomic_align_group);
  return $self->genomic_align_group->get_all_GenomicAligns;
}

=head2 genomic_align_array (DEPRECATED)

  Arg [1]     : -none-
  Example     : $genomic_aligns = $object->genomic_align_array
  Description : Alias for get_all_genomic_aligns_for_node. TO BE DEPRECATED
  Returntype  : listref of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub genomic_align_array {
    my $self = shift(@_);

    deprecate("Use Bio::EnsEMBL::Compara::GenomicAlignTree->get_all_genomic_aligns_for_node() method instead");
    return($self->get_all_genomic_aligns_for_node);

}

=head2 get_all_GenomicAligns (DEPRECATED)

  Arg [1]     : -none-
  Example     : $genomic_aligns = $object->get_all_GenomicAligns
  Description : Alias for get_all_genomic_aligns_for_node. TO BE DEPRECATED
  Returntype  : listref of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_GenomicAligns {
    my $self = shift(@_);

    deprecate("Use Bio::EnsEMBL::Compara::GenomicAlignTree->get_all_genomic_aligns_for_node() method instead");
    return($self->get_all_genomic_aligns_for_node);

}

=head2 reference_genomic_align

  Arg [1]     : (optional) $reference_genomic_align
  Example     : $object->reference_genomic_align($reference_genomic_align);
  Example     : $reference_genomic_align = $object->reference_genomic_align();
  Description : Getter/setter for the reference_genomic_align attribute
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub reference_genomic_align {
  my $self = shift;

  if (@_) {
    $self->{reference_genomic_align} = shift;
  }

  return $self->{reference_genomic_align};
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
        ($self->{'reference_genomic_align'}->dbID != ($self->{'reference_genomic_align_id'} or 0))) {
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


=head2 reference_genomic_align_node

  Arg [1]     : (optional) $reference_genomic_align_node
  Example     : $object->reference_genomic_align_node($reference_genomic_align_node);
  Example     : $reference_genomic_align_node = $object->reference_genomic_align_node();
  Description : Getter/setter for the reference_genomic_align_node attribute
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignTree object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub reference_genomic_align_node {
  my $self = shift;

  if (@_) {
    $self->{reference_genomic_align_node} = shift;
  }

  return $self->{reference_genomic_align_node};
}


=head2 aligned_sequence

  Arg [1]     : -none-
  Example     : $aligned_sequence = $object->aligned_sequence();
  Description : Get the aligned sequence for this node. When the node
                contains one single sequence, it returns its aligned sequence.
                For composite segments, it returns the combined aligned seq.
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub aligned_sequence {
  my $self = shift;
  return $self->genomic_align_group->aligned_sequence(@_);
}


=head2 group_id

  Arg [1]    : integer $group_id
  Example    : my $group_id = $genomic_align_tree->group_id;
  Example    : $genomic_align_tree->group_id(1234);
  Description: get/set for attribute group_id of the underlying
               GenomicAlignBlock objects
  Returntype : integer
  Exceptions : A GenomicAlignTree is made of two GenomicAlignBlock
               object. The method fail when gettign the value if the
               two group_ids do not match
  Caller     : general

=cut

sub group_id {
    my ($self, $group_id) = @_;
    
    if (defined($group_id)) {
        $self->{'group_id'} = $group_id;
        # Set the group_id on the genomic_align_blocks...
        my %genomic_align_blocks;
        #foreach my $this_genomic_align_node (@{$self->get_all_sorted_genomic_align_nodes()}) {
        foreach my $this_genomic_align_node (@{$self->get_all_nodes()}) {
	    next if (!defined $this_genomic_align_node->genomic_align_group);
	    foreach my $genomic_align (@{$this_genomic_align_node->genomic_align_group->get_all_GenomicAligns}) {
		my $this_genomic_align_block = $genomic_align->genomic_align_block;
		if ($this_genomic_align_block and !defined($genomic_align_blocks{$this_genomic_align_block})) {
		    $this_genomic_align_block->group_id($group_id);
		    $genomic_align_blocks{$this_genomic_align_block} = 1;
		}
	    }
	}
    } elsif (!defined($self->{'group_id'}) and defined($self->{adaptor})) {
        # Try to get the ID from other sources...
        my %group_ids;
        my $genomic_align_block_adaptor = $self->adaptor->db->get_GenomicAlignBlockAdaptor;
        foreach my $this_genomic_align_node (@{$self->get_all_nodes()}) {
	    next if (!defined $this_genomic_align_node->genomic_align_group);
	    foreach my $genomic_align (@{$this_genomic_align_node->genomic_align_group->get_all_GenomicAligns}) {
		my $this_genomic_align_block_id = $genomic_align->genomic_align_block_id;
		my $this_genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($this_genomic_align_block_id);
		if ($this_genomic_align_block and $this_genomic_align_block->group_id) {
		    $group_ids{$this_genomic_align_block->group_id} = 1;
		} else {
		    $group_ids{"undef"} = 1;
		}
	    }
        }
        if (keys %group_ids == 1) {
	    if (!defined($group_ids{"undef"})) {
		$self->{'group_id'} = (keys %group_ids)[0];
	    }
        } else {
	    warning("Different group_ids found for this GenomicAlignTree\n");
        }
    }
    return $self->{'group_id'};
}


=head2 name

  Arg [1]     : (optional) string $name
  Example     : $object->name($name);
  Example     : $name = $object->name();
  Description : Getter/setter for the name attribute.
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub name {
  my $self = shift;

  if (@_) {
    $self->{_name} = shift;
  } elsif (!$self->{_name}) {
    my $genomic_align_group = $self->genomic_align_group;
    if (defined($self->SUPER::name()) and $self->SUPER::name() ne "") {
      ## Uses the name defined before blessing this object as a
      ## Bio::EnsEMBL::Compara::GenomicAlignTree in the Ortheus pipeline
      $self->{_name} = $self->SUPER::name();
    } elsif ($self->is_leaf) {
      unless ($genomic_align_group) {
        $self->{_name} = 'NONAME';
        return $self->{_name};
      }
      my $gdb_name = $genomic_align_group->genome_db->name();
      $self->{_name} = $gdb_name.'_'.$genomic_align_group->dnafrag->name."_".
          $genomic_align_group->dnafrag_start."_".$genomic_align_group->dnafrag_end."[".
          (($genomic_align_group->dnafrag_strand eq "-1")?"-":"+")."]";
    } else {
      $self->{_name} = join("-", map {
      	my $name = $_->genomic_align_group->genome_db->name;
      	if($name =~ /(.)[^ ]+_(.{3})/) {
      		$name = "$1$2";
      	}
      	else {
      		$name =~ tr/_//; 	
      	} 
	$name = ucfirst($name);
      	$name;
      } @{$self->get_all_leaves})."[".scalar(@{$self->get_all_leaves})."]";
    }
  }

  return $self->{_name};
}


=head2 get_all_sorted_genomic_align_nodes

  Arg [1]     : (optional) Bio::EnsEMBL::Compara::GenomicAlignTree $reference_genomic_align_node
  Example     : $object->get_all_sorted_genomic_align_nodes($ref_genomic_align_node);
  Example     : $nodes = $object->get_all_sorted_genomic_align_nodes();
  Description : If ref_genomic_align_node is set, sorts the tree based on the
                reference_genomic_align_node
                If ref_genomic_align_node is not set, sorts the tree based on
                the species name
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignTree
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub get_all_sorted_genomic_align_nodes {
  my ($self, $reference_genomic_align_node) = @_;
  my $sorted_genomic_align_nodes = [];

  if (!$reference_genomic_align_node and $self->reference_genomic_align_node) {
    $reference_genomic_align_node = $self->reference_genomic_align_node;
  }

  my $children = $self->children;
  if (@$children >= 1) {
    $children = [sort _sort_children @$children];
    push(@$sorted_genomic_align_nodes, @{$children->[0]->get_all_sorted_genomic_align_nodes(
            $reference_genomic_align_node)});
    push(@$sorted_genomic_align_nodes, $self);
    for (my $i = 1; $i < @$children; $i++) {
      push(@$sorted_genomic_align_nodes, @{$children->[$i]->get_all_sorted_genomic_align_nodes(
              $reference_genomic_align_node)});
    }
  } elsif (@$children == 0) {
    push(@$sorted_genomic_align_nodes, $self);
  }

  return $sorted_genomic_align_nodes;
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
  my ($self, $start, $end, $skip_empty_GenomicAligns, $reference_genomic_align) = @_;
  my $genomic_align_tree;
  $genomic_align_tree = $self->copy();
  $genomic_align_tree->adaptor($self->adaptor);
  foreach my $this_node (@{$genomic_align_tree->get_all_nodes}) {
    $this_node->adaptor($self->adaptor);
  }
  my $final_alignment_length = $end - $start + 1;

  #Only need to do this once per tree since the length is the same for all the nodes.
  my $length = $genomic_align_tree->get_all_leaves->[0]->length;

  #Get all the nodes and restrict but only remove leaves if necessary. Call minimize_tree at the end to 
  #remove the internal nodes
  foreach my $this_node (@{$genomic_align_tree->get_all_nodes}) {
    my $genomic_align_group = $this_node->genomic_align_group;
    next if (!$genomic_align_group);
    my $new_genomic_aligns = [];

   # my $length = $this_node->length;

    foreach my $this_genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
      my $restricted_genomic_align = $this_genomic_align->restrict($start, $end, $length);

      if ($genomic_align_tree->reference_genomic_align eq $this_genomic_align) {
        ## Update the reference_genomic_align

        $genomic_align_tree->reference_genomic_align($restricted_genomic_align);
        $genomic_align_tree->reference_genomic_align_node($this_node);
      }
      if (!$skip_empty_GenomicAligns or
          $restricted_genomic_align->dnafrag_start <= $restricted_genomic_align->dnafrag_end
          ) {
        ## Always skip composite segments outside of the range of restriction
        ## The cigar_line will contain only X's
        next if ($restricted_genomic_align->cigar_line =~ /^\d*X$/);
	
        #Set the genomic_align_block_id of the restricted genomic_align
        $restricted_genomic_align->genomic_align_block_id($this_genomic_align->genomic_align_block_id);
        #$restricted_genomic_align->genomic_align_block($genomic_align_tree);

        push(@$new_genomic_aligns, $restricted_genomic_align);
      }
    }
    if (@$new_genomic_aligns) {
      $genomic_align_group->{genomic_align_array} = undef;
      foreach my $this_genomic_align (@$new_genomic_aligns) {
        $genomic_align_group->add_GenomicAlign($this_genomic_align);
      }
    } else {
	#Only remove leaves. Use minimise_tree to tidy up the internal nodes
	if ($this_node->is_leaf) {
	    $this_node->disavow_parent();
	    my $reference_genomic_align = $genomic_align_tree->reference_genomic_align;
	    if ($reference_genomic_align) {
		my $reference_genomic_align_node = $genomic_align_tree->reference_genomic_align_node;
		$genomic_align_tree = $genomic_align_tree->minimize_tree();
		## Make sure links are not broken after tree minimization
		$genomic_align_tree->reference_genomic_align($reference_genomic_align);
                
                #Set the genomic_align_block_id of the restricted genomic_align
                $genomic_align_tree->reference_genomic_align->genomic_align_block_id($reference_genomic_align->genomic_align_block_id);

		#$genomic_align_tree->reference_genomic_align->genomic_align_block($genomic_align_tree);
		$genomic_align_tree->reference_genomic_align_node($reference_genomic_align_node);
	    }
	}
    }
  }
  $genomic_align_tree = $genomic_align_tree->minimize_tree();
  $genomic_align_tree->length($final_alignment_length);

  return $genomic_align_tree;
}


=head2 copy

  Arg         : none
  Example     : my $new_tree = $this_tree->copy()
  Description : Create a copy of this Bio::EnsEMBL::Compara::GenomicAlignTree
                object
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignTree
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub copy {
  my $self = shift(@_);
  my $new_copy;

  $new_copy = $self->SUPER::copy();

  $new_copy->genomic_align_group($self->genomic_align_group->copy) if ($self->genomic_align_group);
  
  if ($self->reference_genomic_align_node) {
      my $ref_ga = $self->reference_genomic_align;
      #Need to find the reference_genomic_align in the genomic_align_group
      foreach my $leaf (@{$new_copy->get_all_leaves}) {
	  foreach my $gag ($leaf->genomic_align_group) {
	      foreach my $ga (@{$gag->genomic_align_array}) {
		  if ($ref_ga->dnafrag_id == $ga->dnafrag_id &&
		      $ref_ga->dnafrag_start == $ga->dnafrag_start &&
		      $ref_ga->dnafrag_end == $ga->dnafrag_end &&
		      $ref_ga->dnafrag_strand == $ga->dnafrag_strand) {
		      $new_copy->reference_genomic_align($ga);
		      last;
		  }
	      }
	  }
      }
  }
  

  $new_copy->reference_genomic_align_node($self->reference_genomic_align_node->copy) if ($self->reference_genomic_align_node);

  #These are not deep copies
  #$new_copy->reference_genomic_align($self->reference_genomic_align) if ($self->reference_genomic_align);
  #$new_copy->reference_genomic_align_node($self->reference_genomic_align_node) if ($self->reference_genomic_align_node);

  #There are lots of bits missing from this copy
  #Still to add?
  #parent_link
  #obj_id_to_link

  $new_copy->{_original_strand} = $self->{_original_strand} if (defined $self->{_original_strand});
  $new_copy->{_parent_id} = $self->{_parent_id} if (defined $self->{_parent_id});
  $new_copy->{_root_id} = $self->{_root_id} if (defined $self->{_root_id});
  $new_copy->{_left_node_id} = $self->{_left_node_id} if (defined $self->{_left_node_id});
  $new_copy->{_right_node_id} = $self->{_right_node_id} if (defined $self->{_right_node_id});
  $new_copy->{_node_id} = $self->{_node_id} if (defined $self->{_node_id});
  $new_copy->{_reference_slice} = $self->{_reference_slice} if (defined $self->{_reference_slice});
  $new_copy->{_reference_slice_start} = $self->{_reference_slice_start} if (defined $self->{_reference_slice_start});
  $new_copy->{_reference_slice_end} = $self->{_reference_slice_end} if (defined $self->{_reference_slice_end});
  $new_copy->{_reference_slice_strand} = $self->{_reference_slice_strand} if (defined $self->{_reference_slice_strand});

  return $new_copy;
}

=head2 print

  Arg         : none
  Example     : print()
  Description : Print the fields in a Bio::EnsEMBL::Compara::GenomicAlignTree 
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub print {
  my $self = shift(@_);
  my $level = shift;
  my $reference_genomic_align = shift;
  if (!$level) {
    print STDERR $self->newick_format(), "\n";
    $reference_genomic_align = ($self->reference_genomic_align or "");
  }
  $level++;
  my $mark = "- ";
  if (grep {$_ eq $reference_genomic_align} @{$self->get_all_genomic_aligns_for_node}) {
    $mark = "* ";
  }
  print STDERR "  " x $level, $mark,
      "[", $self->node_id, "/", ($self->original_strand?"+":"-"), "] ",
      $self->genomic_align_group ? (
      $self->genomic_align_group->genome_db->name,":",
      $self->genomic_align_group->dnafrag->name,":",
      $self->genomic_align_group->dnafrag_start,":",
      $self->genomic_align_group->dnafrag_end,":",
      $self->genomic_align_group->dnafrag_strand,":",
      ) : (),
      " (", ($self->left_node_id?$self->left_node->node_id."/".$self->left_node->root->node_id:"...."),
      " - ",  ($self->right_node_id?$self->right_node->node_id."/".$self->right_node->root->node_id:"...."),")\n";
  foreach my $this_genomic_align (@{$self->get_all_genomic_aligns_for_node}) {
    if ($this_genomic_align eq $reference_genomic_align) {
      print " " x 8, "* ", $this_genomic_align->aligned_sequence("+FAKE_SEQ"), "\n";
    } else {
      print " " x 10, $this_genomic_align->aligned_sequence("+FAKE_SEQ"), "\n";
    }
  }
  foreach my $node (sort _sort_children @{$self->children}) {
    $node->print($level, $reference_genomic_align);
  }
  $level--;
}


=head2 get_all_nodes_from_leaves_to_this

  Arg[1]      : Bio::EnsEMBL::Compara::GenomicAlignTree $all_nodes
  Example     : my $all_nodes = get_all_nodes_from_leaves_to_this()
  Description : 
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignTree object
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub get_all_nodes_from_leaves_to_this {
  my $self = shift(@_);
  my $all_nodes = (shift or []);
  foreach my $node (sort _sort_children @{$self->children}) {
    $all_nodes = $node->get_all_nodes_from_leaves_to_this($all_nodes);
  }
  push(@$all_nodes, $self);
  return $all_nodes;
}


=head2 get_all_leaves

 Title   : get_all_leaves
 Usage   : my @leaves = @{$tree->get_all_leaves};
 Function: searching from the given starting node, searches and creates list
           of all leaves in this subtree and returns by reference.
           This method overwrites the parent method because it sorts
           the leaves according to their node_id. Here, we use this method
           to get all leaves in another sorting function. Not only it doesn't
           make much sense to sort something that will be sorted again, but
           it can also produce some Perl errors as sort methods uses $a and
           $b which are package global variables.
 Example :
 Returns : reference to list of NestedSet objects (all leaves)
 Args    : none
 Status  : At risk

=cut

sub get_all_leaves {
  my $self = shift;

  my $leaves = [];
  $self->_recursive_get_all_leaves($leaves);

  return $leaves;
}


=head2 sort_children

  Arg         : none
  Example     : sort_children @$children
  Description : sort the nodes of a Bio::EnsEMBL::Compara::GenomicAlignTree object
  Returntype  : int (-1,0,1)
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub sort_children {
  my ($self) = @_;

  my @sortedkids = sort _sort_children @{$self->children};
  return \@sortedkids;
}

=head2 _sort_children

  Arg         : none
  Example     : sort _sort_children @$children
  Description : sort function for sorting the nodes of a Bio::EnsEMBL::Compara::GenomicAlignTree object
  Returntype  : int (-1,0,1)
  Exceptions  : none
  Caller      : general
  Status      : At risk

=cut

sub _sort_children {
  my $reference_genomic_align_node;

  if (defined ($a->root) && defined($b->root) && $a->root eq $b->root and $a->root->reference_genomic_align_node) {
    $reference_genomic_align_node = $a->root->reference_genomic_align_node;
  }

  ## Reference GenomicAlign based sorting
  if ($reference_genomic_align_node) {
    if (grep {$_ eq $reference_genomic_align_node} @{$a->get_all_leaves}) {
      return -1;
    } elsif (grep {$_ eq $reference_genomic_align_node} @{$b->get_all_leaves}) {
      return 1;
    }
  }

  ## Species name based sorting
  my $species_a = $a->_name_for_sorting;
  my $species_b = $b->_name_for_sorting;

  return $species_a cmp $species_b;
}

=head2 _name_for_sorting

  Arg         : none
  Example     : my $species_a = $a->_name_for_sorting;
  Description : if the node is a leaf, create a name based on the species
                name, dnafrag name, group_id and the start position. If the 
                node is an internal node, create a name based on the species 
                name, dnafrag name and the start position
  Returntype  : string 
  Exceptions  : none
  Caller      : _sort_children
  Status      : At risk

=cut

sub _name_for_sorting {
  my ($self) = @_;
  my $name;

  if ($self->is_leaf) {
    $name = sprintf("%s.%s.%s.%020d",
        $self->genomic_align_group->genome_db->name,
        $self->genomic_align_group->dnafrag->name,
        ($self->genomic_align_group->dbID or
          $self->genomic_align_group->{_original_dbID} or 0),
        $self->genomic_align_group->dnafrag_start);
  } else {
    $name = join(" - ", sort map {sprintf("%s.%s.%020d",
        $_->genomic_align_group->genome_db->name,
        $_->genomic_align_group->dnafrag->name,
        $_->genomic_align_group->dnafrag_start)} @{$self->get_all_leaves});
  }

  return $name;
}

=head2 reverse_complement

  Args       : none
  Example    : none
  Description: reverse complement the tree,
               modifying dnafrag_strand and cigar_line of each GenomicAlign in consequence
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub reverse_complement {
    my ($self) = @_;
    
    if (defined($self->original_strand)) {
	$self->original_strand(1 - $self->original_strand);
    } else {
	$self->original_strand(0);
    }

    foreach my $this_node (@{$self->get_all_nodes}) {
	my $genomic_align_group = $this_node->genomic_align_group;
	next if (!$genomic_align_group);
	my $gas = $genomic_align_group->get_all_GenomicAligns;
	foreach my $ga (@{$gas}) {
	    $ga->reverse_complement;
	}
    }
}

sub length {
  my ($self, $length) = @_;

  if (defined($length)) {
    $self->{'length'} = $length;
  } elsif (!defined($self->{'length'})) {
    # Try to get the ID from other sources...
    my $dbID;
    eval {
      $dbID = $self->dbID;
    };
      if (defined($self->{'adaptor'}) and (defined $dbID) and ($self->can('retrieve_all_direct_attributes'))) {

	  # ...from the database, using the dbID of the Bio::Ensembl::Compara::GenomicAlignBlock object
	  $self->adaptor->retrieve_all_direct_attributes($self);
      } elsif (@{$self->get_all_genomic_aligns_for_node} and $self->get_all_genomic_aligns_for_node->[0]->aligned_sequence("+FAKE_SEQ")) {
	  $self->{'length'} = CORE::length($self->get_all_genomic_aligns_for_node->[0]->aligned_sequence("+FAKE_SEQ"));
      } else {
	  foreach my $this_node (@{$self->get_all_nodes}) {
	      my $genomic_align_group = $this_node->genomic_align_group;
	      next if (!$genomic_align_group);
	      $self->{'length'} = CORE::length($genomic_align_group->get_all_GenomicAligns->[0]->aligned_sequence("+FAKE_SEQ"));
	      last;
	  }
      }
  }
  return $self->{'length'};
}

=head2 alignment_strings

  Arg [1]    : none
  Example    : $genomic_align_tree->alignment_strings
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

  foreach my $this_node (@{$self->get_all_nodes}) {
    my $genomic_align_group = $this_node->genomic_align_group;
    next if (!$genomic_align_group);
    foreach my $genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
	push(@$alignment_strings, $genomic_align->aligned_sequence);
    }
  }

  return $alignment_strings;
}

=head2 method_link_species_set

  Arg [1]    : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Example    : $method_link_species_set = $genomic_align_tree->method_link_species_set;
  Description: Getter for attribute method_link_species_set. Takes this from the first Bio::EnsEMBL::Compara::GenomicAlign
               object
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : thrown if $method_link_species_set is not a
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Caller     : general
  Status     : Stable

=cut

sub method_link_species_set {
  my ($self) = @_;

  my $method_link_species_set = $self->get_all_leaves->[0]->genomic_align_group->genomic_align_array->[0]->method_link_species_set;

  throw("$method_link_species_set is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
        unless ($method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));

  return $method_link_species_set;
}

=head2 method_link_species_set_id

  Arg [1]    : integer $method_link_species_set_id
  Example    : $method_link_species_set_id = $genomic_align_tree->method_link_species_set_id;
  Description: Getter for the attribute method_link_species_set_id. Takes this from the first 
               Bio::EnsEMBL::Compara::GenomicAlign object
  Returntype : integer
  Caller     : object::methodname
  Status     : Stable

=cut

sub method_link_species_set_id {
  my ($self) = @_;

  my $method_link_species_set_id = $self->get_all_leaves->[0]->genomic_align_group->genomic_align_array->[0]->method_link_species_set->dbID;

  return $method_link_species_set_id;
}

sub release_tree {
  my ($self) = @_;

  # Remove additional (Perl) references to the reference genomic_align_node and genomic_align:
  delete($self->{"reference_genomic_align_node"}) if ($self->{"reference_genomic_align_node"});
  delete($self->{"reference_genomic_align"}) if ($self->{"reference_genomic_align"});

  # Call SUPER method, which will now work as expected
  $self->SUPER::release_tree();
}

=head2 repeatmask

  Arg [1]    : string. Can be "soft" or "hard"
  Example    : $genomic_align_tree->repeatmask("soft")
  Description: Adds masking to sequences in the GenomicAlignTree object
  Returntype : Masked sequences in original GenomicAlignTree object
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub repeatmask {
  my ($self, $mask) = @_;

  #apply masking
  foreach my $this_node (@{$self->get_all_sorted_genomic_align_nodes()}) {
    my $genomic_align_group = $this_node->genomic_align_group;
    next if (!$genomic_align_group);
      
    foreach my $this_genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
      if ($mask && $this_genomic_align->dnafrag->name !~ /Ancestor/) {
	if ($mask =~ /^soft/) {
	    $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq(undef,1)->seq);
	  } elsif ($mask =~ /^hard/) {
	    $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq()->seq);
	  }
      }
    }
  }
  return $self;
}

=head2 prune

  Arg [1]    : arrayref of species to be displayed. Must be a sub-set of the species in the GenomicAlignTree.
  Example    : my $new_tree = $genomic_align_tree->prune(["human", "chimp"])
  Description: Prunes a GenomicAlignTree object to return a sub-set of species
  Returntype : Pruned GenomicAlignTree object
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub prune {
    my ($self, $display_species_set) = @_;
    
    #prune tree to keep only those species in the display_species_set (plus their ancestral nodes)
    return $self unless (defined $display_species_set && @$display_species_set > 0);
        
    #use registry names and convert to scientific names
    my @display_species_set_scientific_names;
    foreach my $species (@$display_species_set) {
        my $genome_db = $self->adaptor->db->get_GenomeDBAdaptor->fetch_by_registry_name($species);
        push @display_species_set_scientific_names, $genome_db->name;
    }
    
    foreach my $this_leaf (@{$self->get_all_leaves}) {
        my $genomic_aligns = $this_leaf->genomic_align_group->get_all_GenomicAligns;
        my $species_name = $genomic_aligns->[0]->genome_db->name;
        unless (grep {$species_name eq $_}  @display_species_set_scientific_names) {
            $this_leaf->disavow_parent;
        }
    }
    #returns a new tree because the root may have changed
    return $self->minimize_tree;    
}

=head2 summary_as_hash

  Arg [1]    : (optional) boolean. Used for fragmented (low coverage) genomes. If true, create a single sequence of concatenated fragments for each leaf. If false, create an array of sequences for each leaf.
  Arg [2]    : (optional) boolean. Use the aligned (true) or original (no insertions) sequence (false)
  Example    : $genomic_align_tree->summary_as_hash(1, 1)
  Description: Retrieves a textual summary of this GenomicAlignTree object
  Returntype : Array of hashref of descriptive strings
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub summary_as_hash {
    my ( $self, $compact_alignments, $aligned ) = @_;

    my $reverse = 1 - $self->original_strand;
  
    my $all_genomic_aligns;
    foreach my $this_node (@{$self->get_all_sorted_genomic_align_nodes()}) {
      my $genomic_align_group = $this_node->genomic_align_group;
      next if (!$genomic_align_group);
      if  ($compact_alignments) {
	push(@{$all_genomic_aligns}, [$this_node, $genomic_align_group]);
      } else {
	foreach my $this_genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
	  push @$all_genomic_aligns, [$this_node, $this_genomic_align];
	}
      }
    }
    
    my $genome_db_name_counter;
    my $alignment_summary;
    foreach my $this_node_and_genomic_align (@$all_genomic_aligns) {
      my ($this_node, $genomic_align) = @$this_node_and_genomic_align;
      my ($dnafrag_name, $dnafrag_start, $dnafrag_end, $dnafrag_length, $dnafrag_strand);
      my $seq;
      if ($aligned) {
	#aligned sequence
	$seq = $genomic_align->aligned_sequence;
      } else {
	#get original sequence
	$seq = $genomic_align->original_sequence;
      }
      #next if($alignSeq=~/^[\.\-]+$/);
      
      my $species_name = $genomic_align->genome_db->name;
      #Use node name for ancestral sequences
      if ($species_name =~ /ancestral/) {
        $species_name = $this_node->name;
      }

      my $description = "";
      #Need to sort out composite genomic_aligns too (get_coordinates)
      if ($genomic_align->can("get_all_GenomicAligns") and @{$genomic_align->get_all_GenomicAligns} > 1) {
	## This is a composite segment.
	## We need to fix the name
	my @names;
	foreach my $this_composite_genomic_align (@{$genomic_align->get_all_GenomicAligns}) {
	  push(@names, $this_composite_genomic_align->get_Slice->name);
	}
	
	$dnafrag_name = "Composite";
	$description = "$dnafrag_name is: " . join(" + ", @names);
	$dnafrag_start = 1; 
	$dnafrag_end = $self->length;  
	$dnafrag_strand = ($reverse?-1:1);
      } else {
	$dnafrag_name = $genomic_align->dnafrag->name;
	$dnafrag_start = $genomic_align->dnafrag_start;
	$dnafrag_end = $genomic_align->dnafrag_end;
	$dnafrag_length = $genomic_align->dnafrag->length;
	$dnafrag_strand = $genomic_align->dnafrag_strand;
      }
      
      my $summary;
      %$summary = ('start' => $dnafrag_start,
		   'end' => $dnafrag_end,
		   'strand' => $dnafrag_strand,
		   'species' => $species_name,
		   'seq_region' => $dnafrag_name,
		   'seq' => $seq,
		   'description' => $description);
      push @$alignment_summary, $summary;
    }
    return $alignment_summary;
}

=head2 node_type

  Arg [1]    : Getter/setter of the node_type attribute. Currently only "duplication"
  Example    : $genomic_align_tree->node_type()
  Description: It shows the event that took place at that node. 
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub node_type {
  my $self = shift;

  if (@_) {
    $self->{node_type} = shift;
  }

  return $self->{node_type};
}

=head2 annotate_node_type

  Example    : $genomic_align_tree->annotate_node_type()
  Description: Find and annotate the duplication nodes in a tree
  Returntype : 
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub annotate_node_type {
    my ($self) = @_;

    my $duplications;
    my $leaf_names;

    #find the 2 children of a node
    my $children = $self->sorted_children;
    my $child1 = $children->[0];
    my $child2 = $children->[1];

    #Find all the leaves of child1
    my $all_leaves = $child1->get_all_leaves;
    foreach my $this_leaf (@$all_leaves) {
        my $name = $this_leaf->get_all_genomic_aligns_for_node->[0]->genome_db->name;
        $duplications->{$name} = 1;
    }

    #Find all the leaves of child2 and if there are any shared species with child1, we have found a 
    #duplication node.
    $all_leaves = $child2->get_all_leaves;
    foreach my $this_leaf (@$all_leaves) {
        my $name = $this_leaf->get_all_genomic_aligns_for_node->[0]->genome_db->name;
        if ($duplications->{$name}) {
            $self->node_type("duplication");
        }
    }

    #recurse for each child until we get to the leaves
    foreach my $child (@$children) {
        annotate_node_type($child) unless ($child->is_leaf);
    }
}

#sub DESTROY {
#    my ($self) = @_;
#
#    $self->release_tree unless ($self->{_parent_link});
#}

1;
