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
use Data::UUID;

#################################################
# Factory methods
#################################################

sub new {
  my ($class, @args) = @_;
  my $self = {};

  bless $self,$class;
  $self->init;
  #printf("%s   CREATE refcount:%d\n", $self->nestedset_id, $self->refcount);
  
  return $self;
}

sub init {
  my $self = shift;

  #internal variables minimal allocation
  $self->{'_children_id_hash'} = {};
  $self->{'_nestedset_id'} = undef;
  $self->{'_adaptor'} = undef;
  $self->{'_refcount'} = 0;

  return $self;
}

sub dealloc {
  my $self = shift;

  $self->release_children;
  #printf("DEALLOC refcount:%d ", $self->refcount); $self->print_node;
}

sub DESTROY {
  my $self = shift;
  if(defined($self->{'_refcount'}) and $self->{'_refcount'}>0) {
    printf("WARNING DESTROY refcount:%d  (%d)%s %s\n", $self->refcount, $self->nestedset_id, $self->name, $self);
  }    
  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


#######################################
# reference counting system
# DO NOT OVERRIDE
#######################################

sub retain {
  my $self = shift;
  $self->{'_refcount'}=0 unless(defined($self->{'_refcount'}));
  $self->{'_refcount'}++;
  #printf("RETAIN  refcount:%d ", $self->refcount); $self->print_node;
  return $self;
}

sub release {
  my $self = shift;
  throw("calling release on object which hasn't been retained") 
    unless(defined($self->{'_refcount'}));
  $self->{'_refcount'}--;
  #printf("RELEASE refcount:%d ", $self->refcount); $self->print_node;
  return $self if($self->refcount > 0);
  $self->dealloc;
  return undef;
}

sub refcount {
  my $self = shift;
  return $self->{'_refcount'};
}

#################################################
#
# get/set variable methods
#
#################################################

=head2 nestedset_id

  Arg [1]    : (opt.) integer nestedset_id
  Example    : my $nsetID = $object->nestedset_id();
  Example    : $object->nestedset_id(12);
  Description: Getter/Setter for the nestedset_id of this object in the database
  Returntype : integer nestedset_id
  Exceptions : none
  Caller     : general

=cut

sub nestedset_id {
  my $self = shift;
  $self->{'_nestedset_id'} = shift if(@_);
  unless(defined($self->{'_nestedset_id'})) {
    $self->{'_nestedset_id'} = Data::UUID->new->create_str();
  }
  return $self->{'_nestedset_id'};
}


=head2 adaptor

  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor
  Example    : my $object_adaptor = $object->adaptor();
  Example    : $object->adaptor($object_adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : subclass of Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor
  Exceptions : none
  Caller     : general

=cut

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}


#######################################
# Set manipulation methods
#######################################

=head2 add_child

  Overview   : 
  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor
  Example    : my $object_adaptor = $node->parent();
  Example    : $object->adaptor($object_adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : Bio::EnsEMBL::Compara::NestedSet or subclass
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

  #object linkage
  $child->retain;
  $child->disavow_parent;
  $child->_set_parent($self);

  
  #database linkage
  if(defined($self->adaptor) and ($child->adaptor != $self->adaptor)) {
    $self->adaptor->store($child);
  }
  $self->{'_children_id_hash'}->{$child->nestedset_id} = $child;
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

  my $parent = $self->{'_parent_node'};
  if($parent) {
    delete $parent->{'_children_id_hash'}->{$self->nestedset_id};
    #print("DISAVOW parent : "); $parent->print_node;
    #print("        child  : "); $self->print_node;
    $self->release;
  }
  $self->_set_parent(undef);
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

  my @kids = values(%{$self->{'_children_id_hash'}});
  foreach my $child (@kids) {
    #printf("  parent %d releasing child %d\n", $self->nestedset_id, $child->nestedset_id);
    $child->release if(defined($child));
  }  
  $self->{'_children_id_hash'} = {};
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
  return $self->{'_parent_node'} if(defined($self->{'_parent_node'}));
  if($self->adaptor and $self->_parent_nestedset_id) {
    my $parent = $self->adaptor->fetch_parent_for_node($self);
    #print("fetched parent : "); $parent->print_node;
    $parent->add_child($self);
  }
  return $self->{'_parent_node'};
}


sub has_parent {
  my $self = shift;
  return 1 if($self->{'_parent_node'} or $self->{'_parent_nestedset_id'});
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
  return $self->parent->root;
}


=head2 get_children

  Overview   : returns a list of NestedSet nodes directly under this parent node
  Example    : my @children = @{$object->get_children()};
  Returntype : array reference of Bio::EnsEMBL::Compara::NestedSet objects (could be empty)
  Exceptions : none
  Caller     : general

=cut

sub get_children {
  my $self = shift;
  my @kids = values(%{$self->{'_children_id_hash'}});
  return \@kids;
}


sub get_child_count {
  my $self = shift;
  my @kids = keys(%{$self->{'_children_id_hash'}});
  return scalar(@kids);
}

=head2 distance_to_parent

  Arg [1]    : (opt.) <int or double> distance
  Example    : my $dist = $object->distance_to_parent();
  Example    : $object->distance_to_parent(1.618);
  Description: Getter/Setter for the distance between this child and its parent
  Returntype : integer nestedset_id
  Exceptions : none
  Caller     : general

=cut

sub distance_to_parent {
  my $self = shift;
  $self->{'_distance_to_parent'} = shift if(@_);
  return $self->{'_distance_to_parent'};
}

sub left_index {
  my $self = shift;
  $self->{'_left_index'} = shift if(@_);
  return $self->{'_left_index'};
}

sub right_index {
  my $self = shift;
  $self->{'_right_index'} = shift if(@_);
  return $self->{'_right_index'};
}


sub print_tree {
  my $self  = shift;
  my $indent = shift;
  my $lastone = shift;

  $indent = '' unless(defined($indent));

  $self->print_node($indent);

  if($lastone) {
    chop($indent);
    $indent .= " ";
  }
  $indent .= "   |";

  my $children = $self->get_children;
  my $count=0;
  $lastone = 0;
  foreach my $child_node (@$children) {  
    $count++;
    $lastone = 1 if($count == scalar(@$children));
    $child_node->print_tree($indent,$lastone);
  }
}


sub print_node {
  my $self  = shift;
  my $indent = shift;

  $indent = '' unless(defined($indent));
  printf("%s-%s(%d)\n", $indent, $self->name, $self->nestedset_id);
}


##################################
#
# Set theory methods
#
##################################

sub equals {
  my $self = shift;
  my $other = shift;
  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$other]")
        unless($other->isa('Bio::EnsEMBL::Compara::NestedSet'));
  return 1 if($self->nestedset_id eq $other->nestedset_id);
  return 0;
}

sub has_child {
  my $self = shift;
  my $child = shift;
  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$child]")
        unless($child->isa('Bio::EnsEMBL::Compara::NestedSet'));
  return 1 if($child->parent = $self);
  return 0;
}

sub has_child_with_nestedset_id {
  my $self = shift;
  my $node_id = shift;
  return $self->{'_children_id_hash'}->{$node_id};
}

sub is_member_of {
  my $A = shift;
  my $B = shift;
  return 1 if($B->has_child($A));
  return 0; 
}

sub is_not_member_of {
  my $A = shift;
  my $B = shift;
  return 0 if($B->has_child($A));
  return 1; 
}

sub is_subset_of {
  my $A = shift;
  my $B = shift;
  return 1; 
}

sub merge_in_set {
  my $self = shift;
  my $nset = shift;
  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$nset]")
        unless($nset->isa('Bio::EnsEMBL::Compara::NestedSet'));
}

sub merge_node_via_shared_ancestor {
  my $self = shift;
  my $node = shift;

  my $node_dup = $self->find_node_by_nestedset_id($node->nestedset_id);
  if($node_dup) {
    warn("trying to merge in a node with already exists\n");
    return $node_dup;
  }
  return undef unless($node->parent);
  
  my $ancestor = $self->find_node_by_nestedset_id($node->parent->nestedset_id);
  if($ancestor) {
    $ancestor->add_child($node);
    print("common ancestor at : "); $ancestor->print_node;
    return $ancestor;
  }
  return $self->merge_node_via_shared_ancestor($node->parent);
}

##################################
#
# nested_set manipulations and seaches
#
##################################

sub flatten_set {
  my $self = shift;
  
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
  
  my $children = $self->get_children;
  foreach my $child_node (@$children) {
    my $found = $child_node->find_node_by_name($name);
    return $found if(defined($found));
  }
  
  return undef;
}

sub find_node_by_nestedset_id {
  my $self = shift;
  my $node_id = shift;
  
  return $self if($node_id eq $self->nestedset_id);
  
  my $children = $self->get_children;
  foreach my $child_node (@$children) {
    my $found = $child_node->find_node_by_nestedset_id($node_id);
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
    
  $leaves->{$self->nestedset_id} = $self;

  foreach my $child (@{$self->get_children}) {
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
  
  foreach my $child (@{$self->get_children}) {
    my $depth = $child->max_depth;
    $max_depth=$depth if($depth>$max_depth);
  }
  return $max_depth;  
}


##################################
#
# developer/adaptor API methods
#
##################################

sub name {
  my $self = shift;
  $self->{'_name'} = shift if(@_);
  $self->{'_name'} = '' unless(defined($self->{'_name'}));
  return $self->{'_name'};
}


# used for building tree from a DB fetch, want to restrict users to create trees
# by only -add_child method
sub _set_parent {
  my ($self, $parent) = @_;
  $self->{'_parent_nestedset_id'} = 0;
  $self->{'_parent_node'} = $parent;
  $self->{'_parent_nestedset_id'} = $parent->nestedset_id if($parent);
  return $self;
}


# used for building tree from a DB fetch until all the objects are in memory
sub _parent_nestedset_id {
  my $self = shift;
  $self->{'_parent_nestedset_id'} = shift if(@_);
  return $self->{'_parent_nestedset_id'};
}

# used for building tree from a DB fetch until all the objects are in memory
sub _root_nestedset_id {
  my $self = shift;
  $self->{'_root_nestedset_id'} = shift if(@_);
  return $self->{'_root_nestedset_id'};
}


1;

