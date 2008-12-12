=head1 NAME

ProteinTree - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Specific subclass of NestedSet to add functionality when the nodes of this tree
are GenomicAlign objects and the tree is a representation of a Protein derived
Phylogenetic tree

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL compara project: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::GenomicAlignTree;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::SimpleAlign;
use IO::File;

use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet Bio::EnsEMBL::Compara::GenomicAlignBlock);
# our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet);


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


=head2 get_original_strand

  Args       : -none-
  Example    : if (!$genomic_align_tree->get_original_strand()) {
                 # original GenomicAlignTree has been reverse-complemented
               }
  Description: getter for the _orignal_strand attribute
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub get_original_strand {
  my ($self) = @_;

  if (!defined($self->{_original_strand})) {
    $self->{_original_strand} = 1;
  }

  return $self->{_original_strand};
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


=head2 get_all_GenomicAligns

  Arg [1]     : -none-
  Example     : $genomic_aligns = $object->get_all_GenomicAligns
  Description : Getter for all the GenomicAligns contained in the
                genomic_align_group object. This method is a short
                cut for $object->genomic_align_group->get_all_GenomicAligns()
  Returntype  : listref of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_GenomicAligns {
  my $self = shift(@_);
  return [] if (!$self->genomic_align_group);
  return $self->genomic_align_group->get_all_GenomicAligns;
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


# # =head2 group_id
# # 
# #   Arg [1]    : integer $group_id
# #   Example    : my $group_id = $genomic_align_tree->group_id;
# #   Example    : $genomic_align_tree->group_id(1234);
# #   Description: get/set for attribute group_id of the underlying
# #                GenomicAlignBlock objects
# #   Returntype : integer
# #   Exceptions : A GenomicAlignTree is made of two GenomicAlignBlock
# #                object. The method fail when gettign the value if the
# #                two group_ids don't match
# #   Caller     : general
# # 
# # =cut
# # 
# # sub group_id {
# #     my ($self, $group_id) = @_;
# # 
# #     if (defined($group_id)) {
# #       $self->{'group_id'} = $group_id;
# #       # Set the group_id on the genomic_align_blocks...
# #       my %genomic_align_blocks;
# #       foreach my $this_genomic_align_node (@{$self->get_all_sorted_genomic_align_nodes()}) {
# #         my $this_genomic_align_block = $this_genomic_align_node->genomic_align->genomic_align_block;
# #         if ($this_genomic_align_block and !defined($genomic_align_blocks{$this_genomic_align_block})) {
# #           $this_genomic_align_block->group_id($group_id);
# #           $genomic_align_blocks{$this_genomic_align_block} = 1;
# #         }
# #       }
# #     } elsif (!defined($self->{'group_id'}) and defined($self->{adaptor})) {
# #       # Try to get the ID from other sources...
# #       my %group_ids;
# #       my $genomic_align_block_adaptor = $self->adaptor->dba->get_GenomicAlignBlockAdaptor;
# #       foreach my $this_genomic_align_node (@{$self->get_all_sorted_genomic_align_nodes()}) {
# #         my $this_genomic_align_block_id = $this_genomic_align_node->genomic_align->genomic_align_block_id;
# #         my $this_genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($this_genomic_align_block_id);
# #         if ($this_genomic_align_block->group_id) {
# #           $group_ids{$this_genomic_align_block->group_id} = 1;
# #         } else {
# #           $group_ids{"undef"} = 1;
# #         }
# #       }
# #       if (keys %group_ids == 1) {
# #         if (!defined($group_ids{"undef"})) {
# #           $self->{'group_id'} = (keys %group_ids)[0];
# #         }
# #       } else {
# #         warning("Different group_ids found for this GenomicAlignTree\n");
# #       }
# #     }
# #     return $self->{'group_id'};
# # }


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
      $genomic_align_group->genome_db->name =~ /(.)[^ ]+ (.{3})/;
      $self->{_name} = "${1}${2}_".$genomic_align_group->dnafrag->name."_".
          $genomic_align_group->dnafrag_start."_".$genomic_align_group->dnafrag_end."[".
          (($genomic_align_group->dnafrag_strand eq "-1")?"-":"+")."]";
    } else {
      $self->{_name} = join("-", map {$_->genomic_align_group->genome_db->name =~ /(.)[^ ]+ (.{3})/; $_ = "$1$2"}
          @{$self->get_all_leaves})."[".scalar(@{$self->get_all_leaves})."]";
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
    my $genomic_align_group = $this_node->genomic_align_group;
    next if (!$genomic_align_group);
    my $new_genomic_aligns = [];
    foreach my $this_genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
      my $restricted_genomic_align = $this_genomic_align->restrict($start, $end);
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

        $restricted_genomic_align->genomic_align_block($genomic_align_tree);
        push(@$new_genomic_aligns, $restricted_genomic_align);
      }
    }
    if (@$new_genomic_aligns) {
      $genomic_align_group->{genomic_align_array} = undef;
      foreach my $this_genomic_align (@$new_genomic_aligns) {
        $genomic_align_group->add_GenomicAlign($this_genomic_align);
      }
    } else {
      $this_node->disavow_parent();
      my $reference_genomic_align = $genomic_align_tree->reference_genomic_align;
      my $reference_genomic_align_node = $genomic_align_tree->reference_genomic_align_node;
      $genomic_align_tree = $genomic_align_tree->minimize_tree();
      ## Make sure links are not broken after tree minimization
      $genomic_align_tree->reference_genomic_align($reference_genomic_align);
      $genomic_align_tree->reference_genomic_align->genomic_align_block($genomic_align_tree);
      $genomic_align_tree->reference_genomic_align_node($reference_genomic_align_node);
    }
  }

  return $genomic_align_tree;
}


=head2 restrict_between_reference_positions

  Arg[1]     : [optional] int $start, refers to the reference_dnafrag
  Arg[2]     : [optional] int $end, refers to the reference_dnafrag
  Arg[3]     : [optional] Bio::EnsEMBL::Compara::GenomicAlign $reference_GenomicAlign
  Arg[4]     : [optional] boolean $skip_empty_GenomicAligns [ALWAYS FALSE]
  Example    : none
  Description: restrict this GenomicAlignBlock. It returns a new object unless no
               restriction is needed. In that case, it returns the original unchanged
               object
               It might be the case that the restricted region coincide with a gap
               in one or several GenomicAligns. By default these GenomicAligns are
               returned with a dnafrag_end equals to its dnafrag_start + 1. For instance,
               a GenomicAlign with dnafrag_start = 12345 and dnafrag_end = 12344
               correspond to a block which goes on this region from before 12345 to
               after 12344, ie just between 12344 and 12345. You can choose to remove
               these empty GenomicAligns by setting $skip_empty_GenomicAligns to any
               true value.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object in scalar context. In
               list context, returns the previous object and the start and end
               positions of the restriction in alignment coordinates (from 1 to
               alignment_length)
  Exceptions : return undef if reference positions lie outside of the alignment
  Caller     : general
  Status     : At risk

=cut

sub restrict_between_reference_positions {
  my ($self, $start, $end, $reference_genomic_align, $skip_empty_GenomicAligns) = @_;
  my $genomic_align_tree;

  $reference_genomic_align ||= $self->reference_genomic_align;
  throw("A reference Bio::EnsEMBL::Compara::GenomicAlignTree must be given")
      if (!$reference_genomic_align);

   my @restricted_genomic_align_tree_params = $self->SUPER::restrict_between_reference_positions($start, $end, $reference_genomic_align, $skip_empty_GenomicAligns);
  my $restricted_genomic_align_tree = $restricted_genomic_align_tree_params[0];

  #return $self if (!$restricted_genomic_align_tree or $restricted_genomic_align_tree eq $self);

  return wantarray ? @restricted_genomic_align_tree_params : $restricted_genomic_align_tree;
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

  my $new_copy = $self->SUPER::copy();
  $new_copy->genomic_align_group($self->genomic_align_group->copy) if ($self->genomic_align_group);
  $new_copy->reference_genomic_align($self->reference_genomic_align) if ($self->reference_genomic_align);
  $new_copy->reference_genomic_align_node($self->reference_genomic_align_node) if ($self->reference_genomic_align_node);

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
  if (grep {$_ eq $reference_genomic_align} @{$self->get_all_GenomicAligns}) {
    $mark = "* ";
  }
  print STDERR " " x $level, $mark,
      "[", $self->node_id, "/", ($self->get_original_strand?"+":"-"), "] ",
      $self->genomic_align_group->genome_db->name,":",
      $self->genomic_align_group->dnafrag->name,":",
      $self->genomic_align_group->dnafrag_start,":",
      $self->genomic_align_group->dnafrag_end,":",
      $self->genomic_align_group->dnafrag_strand,":",
      " (", ($self->left_node_id?$self->left_node->node_id."/".$self->left_node->root->node_id:"...."),
      " - ",  ($self->right_node_id?$self->right_node->node_id."/".$self->right_node->root->node_id:"...."),")\n";
  foreach my $this_genomic_align (@{$self->get_all_GenomicAligns}) {
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

  my $leaves = {};
  $self->_recursive_get_all_leaves($leaves);
  my @leaf_list = values(%{$leaves});
  return \@leaf_list;
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
  my $reference_genomic_align;

  if (defined ($a->root) && defined($b->root) && $a->root eq $b->root and $a->root->reference_genomic_align) {
    $reference_genomic_align = $a->root->reference_genomic_align;
  }

  ## Reference GenomicAlign based sorting
  if ($reference_genomic_align) {
    if (grep {$_ eq $reference_genomic_align} map {@{$_->get_all_GenomicAligns}}
        @{$a->get_all_nodes}) {
      return -1;
    } elsif (grep {$_ eq $reference_genomic_align} map {@{$_->get_all_GenomicAligns}}
        @{$b->get_all_nodes}) {
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
          $self->genomic_align_group->{original_dbID} or 0),
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
    
    if (defined($self->{_original_strand})) {
	$self->{_original_strand} = 1 - $self->{_original_strand};
    } else {
	$self->{_original_strand} = 0;
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
      if (defined($self->{'adaptor'}) and defined($self->dbID)) {
	  # ...from the database, using the dbID of the Bio::Ensembl::Compara::GenomicAlignBlock object
	  $self->adaptor->retrieve_all_direct_attributes($self);
      } elsif (@{$self->get_all_GenomicAligns} and $self->get_all_GenomicAligns->[0]->aligned_sequence("+FAKE_SEQ")) {
	  $self->{'length'} = CORE::length($self->get_all_GenomicAligns->[0]->aligned_sequence("+FAKE_SEQ"));
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


1;
