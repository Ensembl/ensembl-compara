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

  Arg [1]     : (optional) $left_node
  Example     : $object->left_node($left_node);
  Example     : $left_node = $object->left_node();
  Description : Getter/setter for the left_node attribute
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignTree object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub left_node {
  my $self = shift;
  if (@_) {
    $self->{_left_node} = shift;
  } elsif (!defined($self->{_left_node}) and $self->{_left_node_id} and $self->adaptor) {
    $self->{_left_node} = $self->adaptor->fetch_node_by_node_id($self->{_left_node_id});
  }
  return $self->{_left_node};
}


=head2 right_node

  Arg [1]     : (optional) $left_node
  Example     : $object->left_node($left_node);
  Example     : $left_node = $object->right_node();
  Description : Getter/setter for the left_node attribute
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignTree object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub right_node {
  my $self = shift;
  if (@_) {
    $self->{_right_node} = shift;
  } elsif (!defined($self->{_right_node}) and $self->{_right_node_id} and $self->adaptor) {
    $self->{_right_node} = $self->adaptor->fetch_node_by_node_id($self->{_right_node_id});
  }
  return $self->{_right_node};
}


=head2 genomic_align

  Arg [1]     : (optional) $genomic_align
  Example     : $object->genomic_align($reference_genomic_align);
  Example     : $genomic_align = $object->genomic_align();
  Description : Getter/setter for the genomic_align attribute
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub genomic_align {
  my $self = shift(@_);

  if (@_) {
    $self->{genomic_align} = shift(@_);
  } elsif (!defined($self->{genomic_align}) and $self->node_id and $self->adaptor) {
    my $genomic_align_adaptor = $self->adaptor->db->get_GenomicAlignAdaptor();
    $self->{genomic_align} = $genomic_align_adaptor->fetch_by_dbID($self->node_id);
  }

  return $self->{genomic_align};
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
    my $ref = $self->SUPER::reference_genomic_align(shift);
    $self->get_all_sorted_genomic_align_nodes($ref);
#     if (defined $self->{_node_id}) {
      foreach my $this_node (@{$self->get_all_nodes()}) {
        $this_node->SUPER::reference_genomic_align($ref);
        $this_node->get_all_sorted_genomic_align_nodes($ref);
      }
#     }
  }

  return $self->{reference_genomic_align};
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
    my $genomic_align = $self->genomic_align;
    if ($self->SUPER::name()) {
      ## Uses the name defined before blessing this object as a
      ## Bio::EnsEMBL::Compara::GenomicAlignTree in the Ortheus pipeline
      $self->{_name} = $self->SUPER::name();
    } elsif ($self->is_leaf) {
      $genomic_align->dnafrag->genome_db->name =~ /(.)[^ ]+ (.{3})/;
      $self->{_name} = "${1}${2}_".$genomic_align->dnafrag->name."_".
          $genomic_align->dnafrag_start."_".$genomic_align->dnafrag_end."[".
          (($genomic_align->dnafrag_strand eq "-1")?"-":"+")."]";
    } else {
      $self->{_name} = join("-", map {$_->genomic_align->genome_db->name =~ /(.)[^ ]+ (.{3})/; $_ = "$1$2"}
          @{$self->get_all_leaves})."[".scalar(@{$self->get_all_leaves})."]";
    }
  }

  return $self->{_name};
}


=head2 get_all_sorted_genomic_align_nodes

=cut

sub get_all_sorted_genomic_align_nodes {
  my ($self, $reference_genomic_align) = @_;
  my $sorted_genomic_align_nodes = [];

  if (!$reference_genomic_align and $self->reference_genomic_align) {
    $reference_genomic_align = $self->reference_genomic_align;
  }

  if (@{$self->children} == 2) {
    my $children = [sort _sort_children @{$self->children}];
    push(@$sorted_genomic_align_nodes, @{$children->[0]->get_all_sorted_genomic_align_nodes(
            $reference_genomic_align)});
    push(@$sorted_genomic_align_nodes, $self);
    push(@$sorted_genomic_align_nodes, @{$children->[1]->get_all_sorted_genomic_align_nodes(
            $reference_genomic_align)});
  } elsif (@{$self->children} == 0) {
    push(@$sorted_genomic_align_nodes, $self);
  } else {
    throw("Cannot sort non-binary trees!");
  }

  $self->{genomic_align_array} = [map {$_->genomic_align} @{$sorted_genomic_align_nodes}];

  return $sorted_genomic_align_nodes;
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
  Status      : At risk

=cut

sub restrict_between_reference_positions {
  my ($self, $start, $end, $reference_genomic_align, $skip_empty_GenomicAligns) = @_;
  my $genomic_align_tree;

  $self->get_all_sorted_genomic_align_nodes;
  my $genomic_align_block = $self->SUPER::restrict_between_reference_positions($start, $end,
      $reference_genomic_align, 0);

  return $self if (!$genomic_align_block or $genomic_align_block eq $self);
  # Get a copy of the tree (this method should return a new object in order to comply with parent one.
  $genomic_align_tree = $self->copy;

  # Mess with the genomic_aligns. All of them should be in the same order!
  my $all_genomic_align_nodes = $genomic_align_tree->get_all_sorted_genomic_align_nodes;
  my $all_original_genomic_aligns = $genomic_align_tree->get_all_GenomicAligns;
  my $all_new_genomic_aligns = $genomic_align_block->get_all_GenomicAligns;
  return (1) if (@$all_genomic_align_nodes != @$all_original_genomic_aligns);
  return (2) if (@$all_original_genomic_aligns != @$all_new_genomic_aligns);
  $genomic_align_tree->{genomic_align_array} = $all_new_genomic_aligns;
  for (my $i=0; $i<@$all_genomic_align_nodes; $i++) {
    if ($all_new_genomic_aligns->[$i]->genome_db eq $all_original_genomic_aligns->[$i]->genome_db and
        $all_new_genomic_aligns->[$i]->dnafrag eq $all_original_genomic_aligns->[$i]->dnafrag and
        $all_new_genomic_aligns->[$i]->dnafrag_start >= $all_original_genomic_aligns->[$i]->dnafrag_start and
        $all_new_genomic_aligns->[$i]->dnafrag_end <= $all_original_genomic_aligns->[$i]->dnafrag_end and
        $all_new_genomic_aligns->[$i]->dnafrag_strand == $all_original_genomic_aligns->[$i]->dnafrag_strand) {
      $all_genomic_align_nodes->[$i]->{genomic_align} = $all_new_genomic_aligns->[$i];
      if ($self->reference_genomic_align eq $all_original_genomic_aligns->[$i]) {
$DB::single = 1;
        $genomic_align_tree->reference_genomic_align($all_genomic_align_nodes->[$i]->{genomic_align});
      }
      $all_genomic_align_nodes->[$i]->{genomic_align}->{genomic_align_block} = $genomic_align_block;
    } else {
      for (my $i=0; $i<@$all_genomic_align_nodes; $i++) {
          print STDERR join(":",
              $all_new_genomic_aligns->[$i]->genome_db->name,
              $all_new_genomic_aligns->[$i]->dnafrag->name,
              $all_new_genomic_aligns->[$i]->dnafrag_start,
              $all_new_genomic_aligns->[$i]->dnafrag_end,
              $all_new_genomic_aligns->[$i]->dnafrag_strand), "\n";
          print STDERR join("|",
              $all_original_genomic_aligns->[$i]->genome_db->name,
              $all_original_genomic_aligns->[$i]->dnafrag->name,
              $all_original_genomic_aligns->[$i]->dnafrag_start,
              $all_original_genomic_aligns->[$i]->dnafrag_end,
              $all_original_genomic_aligns->[$i]->dnafrag_strand), "\n";
      }
      warn("Cannot find right order");
      return undef;
    }
  }

  $genomic_align_tree->get_all_sorted_genomic_align_nodes;

  return $genomic_align_tree;
}


=head2 copy

  Status      : At risk

=cut

sub copy {
  my $self = shift(@_);
  my $new_copy = $self->SUPER::copy(@_);
  $new_copy->genomic_align($self->genomic_align) if ($self->genomic_align);
  $new_copy->reference_genomic_align($self->reference_genomic_align) if ($self->reference_genomic_align);
  $new_copy->{genomic_align_array} = $self->{genomic_align_array} if ($self->{genomic_align_array});
  return $new_copy;
}

=head2 print

  Status      : At risk

=cut

sub print {
  my $self = shift(@_);
  my $level = shift;
  my $ref_genomic_align = shift;
  if (!$level) {
    print STDERR $self->newick_format(), "\n";
    $ref_genomic_align = ($self->reference_genomic_align or "");
  }
  $level++;
  my $mark = "- ";
  if ($ref_genomic_align eq $self->genomic_align) {
    $mark = "* ";
  }
  print STDERR " " x $level, $mark,
      "[", $self->node_id, "/", ($self->get_original_strand?"+":"-"), "] ",
      $self->genomic_align->genome_db->name,":",
      $self->genomic_align->dnafrag->name,":",
      $self->genomic_align->dnafrag_start,":",
      $self->genomic_align->dnafrag_end,":",
      $self->genomic_align->dnafrag_strand,":",
      " (", ($self->left_node_id?$self->left_node->node_id."/".$self->left_node->root->node_id:"...."),
      " - ",  ($self->right_node_id?$self->right_node->node_id."/".$self->right_node->root->node_id:"...."),")\n";
  foreach my $node (sort _sort_children @{$self->children}) {
    $node->print($level, $ref_genomic_align);
  }
  $level--;
}


=head2 get_all_nodes_from_leaves_to_this

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

=cut

sub get_all_leaves {
  my $self = shift;

  my $leaves = {};
  $self->_recursive_get_all_leaves($leaves);
  my @leaf_list = values(%{$leaves});
  return \@leaf_list;
}


=head2 _sort_children

=cut

sub _sort_children {
  my $reference_genomic_align;
  if ($a->reference_genomic_align and $b->reference_genomic_align and
      $a->reference_genomic_align eq $b->reference_genomic_align) {
    $reference_genomic_align = $a->reference_genomic_align;
  }

  ## Reference GenomicAlign based sorting
  if ($reference_genomic_align) {
    if (grep {$_ eq $reference_genomic_align} map {$_->genomic_align} @{$a->get_all_nodes}) {
      return -1;
    } elsif (grep {$_ eq $reference_genomic_align} map {$_->genomic_align} @{$b->get_all_nodes}) {
      return 1;
    }
  }

  ## Species name based sorting
  my $species_a = $a->_name_for_sorting;
  my $species_b = $b->_name_for_sorting;

  return $species_a cmp $species_b;
#   if ($a->is_leaf) {
#     $species_a = $a->genomic_align->genome_db->name;
#   } else {
#     $species_a = join(" - ", sort map {sprintf("%s.%s.%020d.%020d", $_->genomic_align->genome_db->name} @{$a->get_all_leaves});
#   }
#   my $species_b;
#   if ($b->is_leaf) {
#     $species_b = $b->genomic_align->genome_db->name;
#   } else {
#     $species_b = join(" - ", sort map {$_->genomic_align->genome_db->name} @{$b->get_all_leaves});
#   }
# #   my $cmp = $species_a cmp $species_b;
# #   if ($cmp < 0) {
# #     print "$species_a <<<<<<<< $species_b\n";
# #   } elsif ($cmp > 0) {
# #     print "$species_b >>>>>>>> $species_a\n";
# #   } else {
# #     print "$species_b ======== $species_a\n";
# #   }
# #   return $cmp;
}

sub _name_for_sorting {
  my ($self) = @_;
  my $name;

  if ($self->is_leaf) {
    $name = sprintf("%s.%s.%020d",
        $self->genomic_align->genome_db->name,
        $self->genomic_align->dnafrag->name,
        $self->genomic_align->dnafrag_start);
  } else {
    $name = join(" - ", sort map {sprintf("%s.%s.%020d",
        $_->genomic_align->genome_db->name,
        $_->genomic_align->dnafrag->name,
        $_->genomic_align->dnafrag_start)} @{$self->get_all_leaves});
  }

  return $name;
}

1;
