=head1 NAME

NestedSet - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Abstract superclass to encapsulate the process of storing and manipulating a
nested-set representation tree.  Also implements a 'reference count' system 
based on the ObjectiveC retain/release design. 
Designed to be used as the Root class for all Compara 'proxy' classes 
(Member, GenomeDB, DnaFrag, NCBITaxon) to allow them to be made into sets and trees.

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::NestedSet;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

use Bio::EnsEMBL::Compara::Graph::Node;
our @ISA = qw(Bio::EnsEMBL::Compara::Graph::Node);

unless(eval "require Data::UUID") {
  throw("Cpan module Data::UUID is not installed on this system\n". 
        "Please install from http://www.cpan.org/modules/by-module/Data/Data-UUID-0.11.tar.gz\n".
        "If there are problems building on 64bit machines, please install patch at\n".
        "http://www.ebi.ac.uk/~jessica/Data_UUID_64bit_patch.html\n"); 
}

#################################################
# Factory methods
#################################################

sub init {
  my $self = shift;
  $self->SUPER::init;
  return $self;
}

sub dealloc {
  my $self = shift;

  #printf("DEALLOC NestedSet refcount:%d ", $self->refcount); $self->print_node;
  $self->release_children;
  return $self->SUPER::dealloc;
}

sub copy {
  my $self = shift;
  
  my $mycopy = $self->SUPER::copy;

  $mycopy->left_index($self->left_index);
  $mycopy->right_index($self->right_index);

  return $mycopy;
}

sub release_tree {
  my $self = shift;
  $self->release;
  $self->cascade_unlink($self->{'_parent_node'});
}

#################################################
# Object variable methods
#################################################

sub left_index {
  my $self = shift;
  $self->{'_left_index'} = shift if(@_);
  $self->{'_left_index'} = 0 unless(defined($self->{'_left_index'}));
  return $self->{'_left_index'};
}

sub right_index {
  my $self = shift;
  $self->{'_right_index'} = shift if(@_);
  $self->{'_right_index'} = 0 unless(defined($self->{'_right_index'}));
  return $self->{'_right_index'};
}


#######################################
# Set manipulation methods
#######################################

=head2 add_child

  Overview   : attaches child nestedset node to this nested set
  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $child
  Example    : $self->add_child($child);
  Returntype : undef
  Exceptions : if child is undef or not a NestedSet subclass
  Caller     : general

=cut

sub add_child {
  my ($self, $child) = @_;

  throw("child not defined") 
     unless(defined($child));
  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$child]")
     unless($child->isa('Bio::EnsEMBL::Compara::NestedSet'));
  
  #print("add_child\n");  $self->print_node; $child->print_node;
  
  return undef if($self->has_child($child));

  #object linkage
  $child->retain->disavow_parent;
  my $link = $self->create_link_to_node($child);
  $child->_parent_link($link);
  $child->release;
  $self->{'_children_loaded'} = 1; 
  return undef;
}

sub store_child {
  my ($self, $child) = @_;
  throw("store_child has been deprecated. Highly inefficient.".
        "Use add_child, build in memory and store in one go\n") 
}

=head2 remove_child

  Overview   : unlink and release child from self if its mine
               might cause child to delete if refcount reaches Zero.
  Arg [1]    : $child Bio::EnsEMBL::Compara::NestedSet instance
  Example    : $self->remove_child($child);
  Returntype : undef
  Caller     : general

=cut

sub remove_child {
  my ($self, $child) = @_;
  $self->unlink_neighbor($child);
  $child->_parent_link(undef);
  return undef;
}


=head2 disavow_parent

  Overview   : unlink and release self from its parent
               might cause self to delete if refcount reaches Zero.
  Example    : $self->disavow_parent
  Returntype : undef
  Caller     : general

=cut

sub disavow_parent {
  my $self = shift;

  if($self->_parent_link) {
    my $link = $self->_parent_link;
    $self->_parent_link(undef);
    #print("DISAVOW parent : "); $parent->print_node;
    #print("        child  : "); $self->print_node;
    $link->release;
  }
  return undef;
}


=head2 release_children

  Overview   : release all children and clear arrays and hashes
               will cause potential deletion of children if refcount reaches Zero.
  Example    : $self->release_children
  Returntype : $self
  Exceptions : none
  Caller     : general

=cut

sub release_children {
  my $self = shift;
  
  # by calling with parent, this preserved the link to the parent
  # and thus doesn't unlink self
  foreach my $child (@{$self->children}) {
    $child->retain->disavow_parent;
    $child->release_children;
    $child->release;
  }
  #$self->cascade_unlink($self->{'_parent_node'});
  return $self;
}


=head2 parent

  Overview   : returns the parent NestedSet object for this node
  Example    : my $my_parent = $object->parent();
  Returntype : undef or Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub parent {
  my $self = shift;
  if(!defined($self->_parent_link) and $self->adaptor and $self->_parent_id) {
    my $parent = $self->adaptor->fetch_parent_for_node($self);
    #print("fetched parent : "); $parent->print_node;
    $parent->add_child($self);
  }
  return undef unless($self->_parent_link);
  return $self->_parent_link->get_neighbor($self);
}


sub has_parent {
  my $self = shift;
  return 1 if($self->_parent_link or $self->_parent_id);
  return 0;
}


sub has_ancestor {
  my $self = shift;
  my $ancestor = shift;
  throw "[$ancestor] must be a Bio::EnsEMBL::Compara::NestedSet object"
       unless ($ancestor and $ancestor->isa("Bio::EnsEMBL::Compara::NestedSet"));
  my $node = $self->parent;
  while($node) {
    return 1 if($node->equals($ancestor));
    $node = $node->parent;
  }
  return 0;
}


=head2 root

  Overview   : returns the root NestedSet object for this node
               returns $self if node has no parent (this is the root)
  Example    : my $root = $object->root();
  Returntype : undef or Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub root {
  my $self = shift;

  return $self unless(defined($self->parent));
  return $self if($self->node_id eq $self->parent->node_id);
  return $self->parent->root;
}

sub subroot {
  my $self = shift;

  return undef unless($self->parent);
  return $self unless(defined($self->parent->parent));
  return $self->parent->subroot;
}


=head2 children

  Overview   : returns a list of NestedSet nodes directly under this parent node
  Example    : my @children = @{$object->children()};
  Returntype : array reference of Bio::EnsEMBL::Compara::NestedSet objects (could be empty)
  Exceptions : none
  Caller     : general

=cut

sub children {
  my $self = shift;

  $self->load_children_if_needed;
  my @kids;
  foreach my $link (@{$self->links}) {
    next unless(defined($link));
    next if($self->_parent_link and $link->equals($self->_parent_link));
    push @kids, $link->get_neighbor($self);
  }
  return \@kids;
}

=head2 sorted_children

  Overview   : returns a sorted list of NestedSet nodes directly under this parent node
               sort so that internal nodes<leaves and then on distance
  Example    : my @kids = @{$object->ordered_children()};
  Returntype : array reference of Bio::EnsEMBL::Compara::NestedSet objects (could be empty)
  Exceptions : none
  Caller     : general

=cut

sub sorted_children {
  my $self = shift;
  
  my @sortedkids = 
     sort { $a->is_leaf <=> $b->is_leaf     
                     ||
            $a->get_child_count <=> $b->get_child_count         
                     ||
            $a->distance_to_parent <=> $b->distance_to_parent
          }  @{$self->children;};
  return \@sortedkids;
}


sub get_all_subnodes {
  my $self = shift;
  my $node_hash = shift;
  
  my $toplevel = 0;
  unless($node_hash) {
   $node_hash = {};
   $toplevel =1;
  }

  foreach my $child (@{$self->children}) {
    $node_hash->{$child->node_id} = $child; 
    $child->get_all_subnodes($node_hash);
  }
  return values(%$node_hash) if($toplevel);
  return undef;
}


sub get_child_count {
  my $self = shift;
  $self->load_children_if_needed;
  my $count = $self->link_count;
  $count-- if($self->has_parent);
  return $count;
}

sub load_children_if_needed {
  my $self = shift;
  if($self->adaptor and !defined($self->{'_children_loaded'})) {
    #define _children_id_hash thereby signally that I've tried to load my children
    $self->{'_children_loaded'} = 1; 
    #print("fetch_all_children_for_node : "); $self->print_node;
    $self->adaptor->fetch_all_children_for_node($self);
  }
  return $self;
}

sub no_autoload_children {
  my $self = shift;
  
  return if($self->{'_children_loaded'});
  $self->{'_children_loaded'} = 1;
}


=head2 distance_to_parent

  Arg [1]    : (opt.) <int or double> distance
  Example    : my $dist = $object->distance_to_parent();
  Example    : $object->distance_to_parent(1.618);
  Description: Getter/Setter for the distance between this child and its parent
  Returntype : integer node_id
  Exceptions : none
  Caller     : general

=cut

#sub distance_to_parent {
#  my $self = shift;
#  my $value = shift;
#  my $link = $self->link_for_neighbor($self->parent);
#  if(defined($value)) { $link->distance_between($value); };
#  return $link->distance_between;
#}

sub distance_to_parent {
  my $self = shift;
  $self->{'_distance_to_parent'} = shift if(@_);
  $self->{'_distance_to_parent'} = 0.0 unless(defined($self->{'_distance_to_parent'}));
  return $self->{'_distance_to_parent'};
}

sub distance_to_root {
  my $self = shift;
  my $dist = $self->distance_to_parent;
  $dist += $self->parent->distance_to_root if($self->parent);
  return $dist;
}

sub distance_to_ancestor {
  my $self = shift;
  my $ancestor = shift;

  if ($ancestor->node_id == $self->node_id) {
    return 0;
  }
  unless (defined $self->parent) {
    throw("Ancestor not found\n");
  }
  return $self->distance_to_parent + $self->parent->distance_to_ancestor($ancestor);
}

sub print_tree {
  my $self  = shift;
  my $scale = shift;
  
  $scale = 100 unless($scale);
  $self->_internal_print_tree(undef, 0, $scale);
}


sub _internal_print_tree {
  my $self  = shift;
  my $indent = shift;
  my $lastone = shift;
  my $scale = shift; 

  if(defined($indent)) {
    print($indent);
    for(my $i=0; $i<$self->distance_to_parent()*$scale; $i++) { print('-'); }
  }
  
  $self->print_node($indent);

  if(defined($indent)) {
    if($lastone) {
      chop($indent);
      $indent .= " ";
    }
    for(my $i=0; $i<$self->distance_to_parent()*$scale; $i++) { $indent .= ' '; }
  }
  $indent = '' unless(defined($indent));
  $indent .= "|";

  my $children = $self->sorted_children;
  my $count=0;
  $lastone = 0;
  foreach my $child_node (@$children) {  
    $count++;
    $lastone = 1 if($count == scalar(@$children));
    $child_node->_internal_print_tree($indent,$lastone,$scale);
  }
}


sub print_node {
  my $self  = shift;

  printf("(%s %d,%d)", $self->node_id, $self->left_index, $self->right_index);
  printf("%s\n", $self->name);
}


sub newick_format {
  my $self = shift;
  my $newick = "";
  
  if($self->get_child_count() > 0) {
    $newick .= "(";
    my $first_child=1;
    foreach my $child (@{$self->sorted_children}) {  
      $newick .= "," unless($first_child);
      $newick .= $child->newick_format;
      $first_child = 0;
    }
    $newick .= ")";
  }
  
  if($self->parent) {
    $newick .= sprintf("\"%s\"", $self->name,);
    $newick .= sprintf(":%1.4f", $self->distance_to_parent) if($self->distance_to_parent > 0);
  } else {
    $newick .= ";";
  }
  return $newick;
}

sub newick_simple_format {
  my $self = shift;
  my $newick = "";
  
  if($self->get_child_count() > 0) {
    $newick .= "(";
    my $first_child=1;
    foreach my $child (@{$self->sorted_children}) {  
      $newick .= "," unless($first_child);
      $newick .= $child->newick_simple_format;
      $first_child = 0;
    }
    $newick .= ")";
  }
  
  if($self->parent) {
    $newick .= sprintf("\"%s\"", $self->name) if($self->is_leaf);
    $newick .= sprintf(":%1.4f", $self->distance_to_parent);
  } else {
    $newick .= ";";
  }
  return $newick;
}


##################################
#
# Set theory methods
#
##################################

#sub equals {
#  my $self = shift;
#  my $other = shift;
#  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$other]")
#        unless($other->isa('Bio::EnsEMBL::Compara::NestedSet'));
#  return 1 if($self->node_id eq $other->node_id);
#  foreach my $child (@{$self->children}) {
#    return 0 unless($other->has_child($child));
#  }
#  return 1;
#}

sub has_child {
  my $self = shift;
  my $child = shift;
  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$child]")
        unless($child->isa('Bio::EnsEMBL::Compara::NestedSet'));
  $self->load_children_if_needed;
  my $link = $self->link_for_neighbor($child);
  return 0 unless($link);
  return 0 if($self->_parent_link and ($self->_parent_link->equals($link)));
  return 1;
}

sub is_member_of {
  my $A = shift;
  my $B = shift;
  return 1 if($B->has_child($A));
  return 0; 
}

sub is_subset_of {
  my $A = shift;
  my $B = shift;
  foreach my $child (@{$A->children}) {
    return 0 unless($B->has_child($child));
  }
  return 1; 
}

sub is_leaf {
  my $self = shift;
  return 1 unless($self->get_child_count);
  return 0;
}

sub merge_children {
  my $self = shift;
  my $nset = shift;
  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$nset]")
        unless($nset->isa('Bio::EnsEMBL::Compara::NestedSet'));
  foreach my $child_node (@{$nset->children}) {
    $self->add_child($child_node);
  }
  return $self;
}

sub merge_node_via_shared_ancestor {
  my $self = shift;
  my $node = shift;

  my $node_dup = $self->find_node_by_node_id($node->node_id);
  if($node_dup) {
    #warn("trying to merge in a node with already exists\n");
    return $node_dup;
  }
  return undef unless($node->parent);
  
  my $ancestor = $self->find_node_by_node_id($node->parent->node_id);
  if($ancestor) {
    $ancestor->add_child($node);
    #print("common ancestor at : "); $ancestor->print_node;
    return $ancestor;
  }
  return $self->merge_node_via_shared_ancestor($node->parent);
}

##################################
#
# nested_set manipulations
#
##################################

sub flatten_tree {
  my $self = shift;
  
  my $leaves = $self->get_all_leaves;
  foreach my $leaf (@{$leaves}) { $leaf->retain->disavow_parent; }

  $self->release_children;
  foreach my $leaf (@{$leaves}) { $self->add_child($leaf); $leaf->release; }
  
  return $self;
}

sub re_root {
  my $self = shift;
  return unless($self->parent);

  $self->retain;
  my $parent = $self->parent->retain;
  $self->disavow_parent;

  $parent->re_root;
  
  $self->add_child($parent);
  $parent->distance_to_parent($self->distance_to_parent);
  $self->distance_to_parent(0.0);
  $self->release;
  $parent->release;
  return $self;
}

sub build_leftright_indexing {
  my $self = shift;
  my $counter = shift;
  
  $counter = 1 unless($counter);
  
  $self->left_index($counter++);
  foreach my $child_node (@{$self->sorted_children}) {
    $counter = $child_node->build_leftright_indexing($counter);
  }
  $self->right_index($counter++);
  return $counter;
}


sub minimize_tree {
  my $self = shift;
  
  my @all_nodes = $self->get_all_subnodes;
  foreach my $node (@all_nodes) { 
    if($node->parent and 
       ($node->get_child_count() == 1)) 
    {
      my $child = $node->children->[0];
      $child->distance_to_parent($child->distance_to_parent + $node->distance_to_parent);
      $node->parent->add_child($child);
      $node->disavow_parent;
    }
  }
  if($self->get_child_count() == 1) {
    return $self->children->[0];
  } 
  return $self;
}



##################################
#
# search methods
#
##################################

sub find_node_by_name {
  my $self = shift;
  my $name = shift;
  
  return $self if($name eq $self->name);
  
  my $children = $self->children;
  foreach my $child_node (@$children) {
    my $found = $child_node->find_node_by_name($name);
    return $found if(defined($found));
  }
  
  return undef;
}

sub find_node_by_node_id {
  my $self = shift;
  my $node_id = shift;
  
  return $self if($node_id eq $self->node_id);
  
  my $children = $self->children;
  foreach my $child_node (@$children) {
    my $found = $child_node->find_node_by_node_id($node_id);
    return $found if(defined($found));
  }
  
  return undef;
}


=head2 get_all_leaves

 Title   : get_all_leaves
 Usage   : my @leaves = @{$tree->get_all_leaves};
 Function: searching from the given starting node, searches and creates list
           of all leaves in this subtree and returns by reference
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

sub _recursive_get_all_leaves {
  my $self = shift;
  my $leaves = shift;
    
  $leaves->{$self->node_id} = $self if($self->is_leaf);

  foreach my $child (@{$self->children}) {
    $child->_recursive_get_all_leaves($leaves);
  }
  return undef;
}


=head2 max_depth

 Title   : max_depth
 Args    : none
 Usage   : $tree_node->max_depth;
 Function: searching from the given starting node, calculates the maximum depth to a leaf
 Returns : int

=cut

sub max_depth {
  my $self = shift;

  my $max_depth = 0;
  
  foreach my $child (@{$self->children}) {
    my $depth = $child->max_depth + 1;
    $max_depth=$depth if($depth>$max_depth);
  }
  return $max_depth;  
}


sub find_first_shared_ancestor {
  my $self = shift;
  my $node = shift;

  return $node if($self->has_ancestor($node));  
  return $self->find_first_shared_ancestor($node->parent);
}


##################################
#
# developer/adaptor API methods
#
##################################


# used for building tree from a DB fetch, want to restrict users to create trees
# by only -add_child method
sub _old_set_parent {
  my ($self, $parent) = @_;
  $self->{'_parent_id'} = 0;
  $self->{'_parent_node'} = $parent;
  $self->{'_parent_id'} = $parent->node_id if($parent);
  return $self;
}

sub _parent_link {
  my $self = shift;
  $self->{'_parent_link'} = shift if(@_);
  return $self->{'_parent_link'};
}

# used for building tree from a DB fetch until all the objects are in memory
sub _parent_id {
  my $self = shift;
  $self->{'_parent_id'} = shift if(@_);
  return $self->{'_parent_id'};
}

# used for building tree from a DB fetch until all the objects are in memory
sub _root_id {
  my $self = shift;
  $self->{'_root_id'} = shift if(@_);
  return $self->{'_root_id'};
}

1;

