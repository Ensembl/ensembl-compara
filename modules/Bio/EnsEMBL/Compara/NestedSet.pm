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

=head1 NAME

Bio::EnsEMBL::Compara::NestedSet

=head1 DESCRIPTION

Abstract superclass to encapsulate the process of storing and manipulating a
nested-set representation tree.  Also implements a 'reference count' system 
based on the ObjectiveC retain/release design. 
Designed to be used as the Root class for all Compara 'proxy' classes 
(Member, GenomeDB, DnaFrag, NCBITaxon) to allow them to be made into sets and trees.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::NestedSet;

use strict;
use warnings;

use List::Util qw(sum);

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Storable;

use Bio::TreeIO;

use Bio::EnsEMBL::Compara::Graph::Node;

our @ISA = qw(Bio::EnsEMBL::Compara::Graph::Node Bio::EnsEMBL::Storable);

#################################################
# Factory methods
#################################################

=head2 _attr_to_copy_list

  Description: Returns the list of all the attributes to be copied by deep_copy()
  Returntype : Array of String
  Caller     : deep_copy()
  Status     : Stable

=cut

sub _attr_to_copy_list {
    return qw(_distance_to_parent _left_index _right_index);
}


sub copy_node {
    my $self = shift;
    my $mycopy = $self->SUPER::copy(@_);
    foreach my $attr ($self->_attr_to_copy_list) {
        $mycopy->{$attr} = $self->{$attr} if exists $self->{$attr};;
    }
    return $mycopy;
}


=head2 copy

  Overview   : creates copy of tree starting at this node going down
  Example    : my $clone = $self->copy;
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub copy {
    my ($self, $class, $adaptor) = @_;

    my $mycopy = $self->copy_node();

    if ($adaptor) {
        $mycopy->adaptor($adaptor);
        $mycopy->node_id($self->node_id);
    }

    if ($class) {
        eval "require $class";
        bless $mycopy, $class;
        $mycopy->_complete_cast_node($self) if $mycopy->can('_complete_cast_node');
    }

    $mycopy->{'_children_loaded'} = 1;  # So that leaves know they are leaves
    foreach my $child (@{$self->children}) {
        $mycopy->add_child($child->copy($class, $adaptor));
    }
    return $mycopy;
}


=head2 release_tree

  Overview   : deletes and frees the memory used by this tree
               and all the underlying nodes.
  Example    : $self->release_tree;
  Returntype : undef
  Exceptions : none
  Caller     : general

=cut

sub release_tree {
  my $self = shift;
  
  my $child_count = $self->get_child_count;
  $self->disavow_parent;
  $self->cascade_unlink if($child_count);
  return undef;
}


sub dbID {
    my ($self) = @_;
#    throw("NestedSet objects do not implement dbID()");
    return $self->node_id;
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
  Arg [2]    : (opt.) distance between this node and child
  Example    : $self->add_child($child);
  Returntype : undef
  Exceptions : if child is undef or not a NestedSet subclass
  Caller     : general

=cut

sub add_child {
  my $self = shift;
  my $child = shift;
  my $dist = shift;
  
  throw("child not defined") 
     unless(defined($child));
  assert_ref($child, 'Bio::EnsEMBL::Compara::NestedSet', 'child');
  
  #printf("add_child: parent(%s) <-> child(%s)\n", $self->node_id, $child->node_id);
  
  unless(defined($dist)) { $dist = $child->_distance; }

  $child->disavow_parent;
  #create_link_to_node is a safe method which checks if connection exists
  my $link = $self->create_link_to_node($child);
  $child->_set_parent_link($link);
  $self->{'_children_loaded'} = 1;
  $link->distance_between($dist);
  return $link;
}


=head2 disavow_parent

  Overview   : unlink and release self from its parent
  Example    : $self->disavow_parent
  Returntype : undef
  Caller     : general

=cut

sub disavow_parent {
  my $self = shift;

  if($self->{'_parent_link'}) {
    my $link = $self->{'_parent_link'};
    #print("DISAVOW parent : "); $parent->print_node;
    #print("        child  : "); $self->print_node;
    $link->dealloc;
  }
  $self->_set_parent_link(undef);
  return undef;
}


=head2 release_children

  Overview   : recursive releases all children
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
    $child->disavow_parent;
    $child->release_children;
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
    return $self->{'_parent_link'}->get_neighbor($self) if defined $self->{'_parent_link'};
    return $self->adaptor->fetch_parent_for_node($self) if (defined $self->adaptor) and (defined $self->_parent_id);
    return undef;
}


sub parent_link {
  my $self = shift;
  return $self->{'_parent_link'};
}

sub has_parent {
  my $self = shift;
  return 1 if($self->{'_parent_link'} or $self->_parent_id);
  return 0;
}


sub has_ancestor {
  my $self = shift;
  my $ancestor = shift;
  assert_ref($ancestor, 'Bio::EnsEMBL::Compara::NestedSet', 'ancestor');
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
  Description: Returns the root of the tree for this node
               with links to all the intermediate nodes. Sister nodes
               are not included in the result.
  Returntype : undef or Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub root {
  my $self = shift;

  # Only if we don't have it cached
  # Only if we have left and right and it's not a leaf
  # Only if it's for release clusterset (1 genetrees - 0 genomic align trees)
  if (!defined($self->{'_parent_link'}) and $self->adaptor 
      and ($self->right_index-$self->left_index)>1
      and (defined $self->{'_parent_id'})
      and (1==$self->{'_parent_id'})
     ) {
    return $self->adaptor->fetch_root_by_node($self);
  }

  # Otherwise, go through the step-by-step method
  return $self unless(defined($self->parent));
 #  return $self if($self->node_id eq $self->parent->node_id);
  return $self->parent->root;
}


=head2 children

  Overview   : returns a list of NestedSet nodes directly under this parent node
  Example    : my @children = @{$object->children()};
  Returntype : array reference of Bio::EnsEMBL::Compara::NestedSet objects (could be empty)
  Exceptions : none
  Caller     : general
  Algorithm  : new algorithm for fetching children:
                for each link connected to this NestedsSet node, a child is defined if
                  old: the link is not my parent_link
                  new: the link's neighbors' parent_link is the link
               This allows one (with a carefully coded algorithm) to overlay a tree on top
               of a fully connected graph and use the parent/children methods of NestedSet
               to walk the 'tree' substructure of the graph.  
               Trees that are really just trees are still trees.

=cut

sub children {
  my $self = shift;
  $self->load_children_if_needed;
  my @kids;
  foreach my $link (@{$self->links}) {
    next unless(defined($link));
    my $neighbor = $link->get_neighbor($self);
    throw("Not neighbor found\n") unless (defined $neighbor);
    my $parent_link = $neighbor->parent_link;
    next unless($parent_link);
    next unless($parent_link eq $link);
    push @kids, $neighbor;
  }
  return \@kids;
}

sub each_child {
    my $self = shift;

    # Return an iterator over the children (most effective when children list is LONG)
    my $count = -1;
    $self->load_children_if_needed;
    my @links = @{$self->links};

    return sub {
	while ($count < scalar(@links)) {
	    $count++;
	    my $link = $links[$count];
	    next unless(defined $link);

	    my $neighbor = $link->get_neighbor($self);
	    next unless($neighbor->parent_link);
	    next unless($neighbor->parent_link->equals($link));
	    return $neighbor;
	}
	return undef;
    };
}


=head2 traverse_tree

  Arg[1]      : $callback: subroutine to call on each node
  Arg[2]      : $sorted: boolean (false). Whether the children should be sorted or not
  Arg[3]      : $postfix: boolean (false). Whether the parent's callback should be done after its children or not
  Example     : $node->traverse_tree();
  Description : Traverse the tree and call $callback on each node
  Returntype  : None
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub traverse_tree {
    my $self = shift;
    my ($callback, $sorted, $postfix) = @_;
    $callback->($self) unless $postfix;
    foreach my $child (@{$sorted ? $self->sorted_children : $self->children}) {
        $child->traverse_tree(@_);
    }
    $callback->($self) if $postfix;
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


=head2 siblings

  Overview   : returns a ist of NestedSet nodes that share the same parent
  Example    : my @siblings = @{$object->siblings()};
  Returntype : array reference of Bio::EnsEMBL::Compara::NestedSet objects (could be empty)
  Exceptions : none
  Caller     : general

=cut

sub siblings {
    my ($node) = @_;
    return [] unless ($node->has_parent());
    my $parent = $node->parent();
    my $children = $parent->children();
    my @siblings = ();
    for my $child (@$children) {
        if ($child != $node) {
            push @siblings, $child;
        }
    }
    return [@siblings];
}


=head2 get_all_nodes

  Arg 1       : arrayref $node_array [used for recursivity, do not use it!]
  Example     : my $all_nodes = $root->get_all_nodes();
  Description : Returns this and all underlying sub nodes
  ReturnType  : listref of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_nodes {
  my $self = shift;
  my $node_array = shift || [];

  # The recursion is faster than traverse_tree
  push @$node_array, $self;
  foreach my $child (@{$self->children}) {
    no warnings 'recursion';
    $child->get_all_nodes($node_array);
  }

  return $node_array;
}

=head2 get_all_sorted_nodes

  Arg 1       : arrayref $node_array [used for recursivity, do not use it!]
  Example     : my $all_sorted_nodes = $root->get_sorted_nodes();
  Description : Returns this and all underlying sub nodes ordered
  ReturnType  : listref of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_sorted_nodes {
  my $self = shift;
  my $node_array = shift || [];

  # The recursion is faster than traverse_tree
  push @$node_array, $self;
  foreach my $child (@{$self->sorted_children}) {
    no warnings 'recursion';
    $child->get_all_sorted_nodes($node_array);
  }

  return $node_array;
}



=head2 get_all_nodes_by_tag_value

  Arg 1       : tag_name
  Arg 2       : tag_value (optional)
  Example     : my $all_nodes = $root->get_all_nodes_by_tagvalue('tree_support'=>'nj_dn');
  Description : Returns all underlying nodes that have a tag of the given name, and optionally a value of the given value.
  ReturnType  : listref of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : general
  Status      : 

=cut

sub get_all_nodes_by_tag_value {
  my $self  = shift;
  my $tag   = shift || die( "Need a tag name" );
  my $test_value = scalar(@_);
  my $value = shift;
  my @found;
  $self->traverse_tree(sub {
      my $node = shift;
      if ($node->has_tag($tag) && (!$test_value || ($node->get_value_for_tag($tag) eq $value))) {
          push @found, $node;
      }
  });
  return \@found;
}


=head2 get_all_subnodes

  Example     : my @all_subnodes = $root->get_all_subnodes();
  Description : Returns all underlying sub nodes
  ReturnType  : array of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_subnodes {
  my $self = shift;

  my @array;
  # The recursion is faster than traverse_tree
  foreach my $child (@{$self->children}) {
    push @array, @{$child->get_all_nodes};
  }
  return @array;
}

=head2 get_all_ancestors

  Arg 1       : 
  Example     : my @ancestors = @{$node->get_all_ancestors};
  Description : Returns all ancestor nodes for a given node
  ReturnType  : listref of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : general
  Status      :

=cut

sub get_all_ancestors {
  my $self = shift;
  my $this = $self;
  my @ancestors;
  while( $this = $this->parent ){
    push @ancestors, $this;
  }
  return [@ancestors]
}

=head2 get_all_adjacent_subtrees

  Arg 1       : 
  Example     : my @subtrees = @{$node->get_all_adjacent_subtrees};
  Description : Returns subtree 'root' nodes where the subtree is adjacent
                to this node. Used e.g. by the web code for the 'collapse 
                other nodes' action 
  ReturnType  : listref of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : EnsEMBL::Web::Component::Gene::ComparaTree
  Status      :

=cut

sub get_all_adjacent_subtrees {
  my $self = shift;
  my $node_id = $self->node_id;
  my @node_path_to_root = ($self, @{$self->get_all_ancestors} );
  my %path_node_ids = map{ $_->node_id => 1 } @node_path_to_root;

  my $this = $self->root; # Start at the root node

  my @adjacent_subtrees;
  while( $this ){
    last if $this->node_id == $node_id; # Stop on reaching current node
    my $next;
    foreach my $child (@{$this->children}){
      next if $child->is_leaf; # Leaves cannot be subtrees
      if( $path_node_ids{$child->node_id} ){ # Ancestor node
        $next = $child;
      } else {
        push @adjacent_subtrees, $child;
      }
    }
    $this = $next || undef;
  }

  return [@adjacent_subtrees]
}


=head2 num_leaves

  Example     : my $num_leaves = $node->num_leaves
  Description : Returns the number of leaves underlying the node
  ReturnType  : integer
  Exceptions  : none
  Caller      : general
  Status      : At risk (relies on left and right indexes)

=cut

sub num_leaves {
   my $self = shift;

   my $left = $self->left_index;
   my $right = $self->right_index;

   return unless( $left && $right );

   my $num = $right - $left + 1;
   my $num_leaves = ( ($num/2) + 1 ) / 2;

   return $num_leaves;
}


sub get_child_count {
  my $self = shift;
  $self->load_children_if_needed;
  return scalar @{$self->children};
#  my $count = $self->link_count;
#  $count-- if($self->has_parent);
#  return $count;
}

sub load_children_if_needed {
  my $self = shift;
  if(!defined($self->{'_children_loaded'}) and $self->adaptor) {
    #define _children_id_hash thereby signally that I've tried to load my children
    $self->{'_children_loaded'} = 1; 
    #print("load_children_if_needed : "); $self->print_node;
    $self->adaptor->fetch_all_children_for_node($self);
  }
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

sub distance_to_parent {
  my $self = shift;
  my $dist = shift;

  if($self->{'_parent_link'}) {
    if(defined($dist)) { $self->{'_parent_link'}->distance_between($dist); }
    else { $dist = $self->{'_parent_link'}->distance_between; }
  } else {
    if(defined($dist)) { $self->_distance($dist); }
    else { $dist = $self->_distance; } 
  }
  return $dist;
}

sub _distance  {
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


=head2 distance_to_ancestor

  Arg [1]     : Bio::EnsEMBL::Compara::NestedSet $ancestor
  Example     : my $distance = $this_node->distance_to_ancestor($ancestor);
  Description : Calculates the distance in the tree between this node and
                its ancestor $ancestor
  Returntype  : float
  Exceptions  : throws if $ancestor is not an ancestor of this node.
  Caller      : general
  Status      : Stable

=cut

sub distance_to_ancestor {
  my $self = shift;
  my $ancestor = shift;

  if ($ancestor->node_id eq $self->node_id) {
    return 0;
  }
  unless (defined $self->parent) {
    throw("Ancestor not found\n");
  }
  return $self->distance_to_parent + $self->parent->distance_to_ancestor($ancestor);
}


=head2 distance_to_node

  Arg [1]     : Bio::EnsEMBL::Compara::NestedSet $node
  Example     : my $distance = $this_node->distance_to_node($other_node);
  Description : Calculates the distance in the tree between these
                two nodes.
  Returntype  : float
  Exceptions  : returns undef if no ancestor can be found, no distances are
                defined in the tree, etc.
  Caller      : general
  Status      : Stable

=cut

sub distance_to_node {
  my $self = shift;
  my $node = shift;

  my $ancestor = $self->find_first_shared_ancestor($node);
  if (!$ancestor) {
    return undef;
  }
  my $distance = $self->distance_to_ancestor($ancestor);
  $distance += $node->distance_to_ancestor($ancestor);

  return $distance;
}


# Returns a TreeI-compliant object based on this NestedSet.
sub get_TreeI {
    my $self = shift;
    my $newick = $self->newick_format();

    open(my $fake_fh, "+<", \$newick);
    my $treein = new Bio::TreeIO(-fh => $fake_fh, -format => 'newick');
    my $treeI = $treein->next_tree;
    $treein->close;

    return $treeI;
}

sub new_from_newick {
    my $class = shift;
    my $file = shift;
    my $treein = new Bio::TreeIO(-file => $file, -format => 'newick');
    my $treeI = $treein->next_tree;
    $treein->close;

    return $class->new_from_TreeI($treeI);
}

sub new_from_TreeI {
    my $class = shift;
    my $treeI = shift;

    my $rootI = $treeI->get_root_node;
    my $node = new $class;

    # Kick off the recursive, parallel node adding.
    _add_nodeI_to_node($node,$rootI);

    return $node;
}

# Recursive helper for new_from_TreeI.
sub _add_nodeI_to_node {
    my $node = shift; # Our node object (Compara)
    my $nodeI = shift; # Our nodeI object (BioPerl)

    foreach my $c ($nodeI->each_Descendent) {
	my $child = ref($node)->new;

	my $name = $c->id || '';
	$name =~ s/^\s+//;
	$name =~ s/\s+$//;

	# Set name.
	$child->name($name);

	# Set branch length.
	$node->add_child($child,$c->branch_length);

	# Recurse.
	_add_nodeI_to_node($child,$c);
    }
}

=head2 print_tree

  Arg [1]     : int $scale
  Example     : $this_node->print_tree(100);
  Description : Prints this tree in ASCII format. The scale is used to define
                the width of the tree in the output
  Returntype  : undef
  Exceptions  :
  Caller      : general
  Status      : At risk (as the output might change)

=cut

sub print_tree {
  my $self  = shift;
  my $scale = shift;

  $scale = 100 unless($scale);
  $self->_internal_print_tree(undef, 0, $scale);
}

sub string_tree {
  my $self  = shift;
  my $scale = shift;
     $scale ||= 100;
  my $buffer = '';
  $self->_internal_string_tree(undef, 0, $scale, \$buffer);
  return $buffer;
}

sub _internal_string_tree {
  my $self    = shift;
  my $indent  = shift;
  my $lastone = shift;
  my $scale   = shift;
  my $buffer  = shift;

  if(defined($indent)) {
    $$buffer .= $indent;
    for(my $i=0; $i<$self->distance_to_parent()*$scale; $i++) { $$buffer .= '-'; }
  }

  $$buffer .= $self->string_node($indent);

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
    $child_node->_internal_string_tree($indent,$lastone,$scale,$buffer);
  }
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
  my $self = shift;
  print $self->string_node;
}

sub string_node {
    my $self  = shift;
    my $str = '(';

    my $isdup = 0;
    $isdup = 1 if ($self->get_value_for_tag('Duplication', 0) > 0 and not $self->get_value_for_tag('dubious_duplication', 0));
    $isdup = 1 if $self->get_value_for_tag('node_type', '') eq 'duplication';

    my $isdub = ($self->get_value_for_tag('node_type', '') eq 'dubious');

    if ($isdup) {
        if ($self->isa('Bio::EnsEMBL::Compara::GeneTreeNode') and (defined $self->species_tree_node) && ($self->species_tree_node->genome_db_id)) {
            $str .= "Dup ";
        } else {
            $str .= "DUP ";
        }
       my $sis = $self->get_value_for_tag('duplication_confidence_score', 0) * 100;
       $str .= sprintf('SIS=%.2f ', $sis);
    } elsif ($isdub) {
        $str .= "DD  ";
       $str .= 'SIS=0 ';
    }
    if($self->has_tag("bootstrap")) { my $bootstrap_value = $self->bootstrap(); $str .= "B=$bootstrap_value "; }
    if($self->can('taxonomy_level') && $self->taxonomy_level) { my $taxon_name_value = $self->taxonomy_level(); $str .="T=$taxon_name_value "; }
    $str .= sprintf("%s %d,%d)", $self->node_id, $self->left_index, $self->right_index);
    $str .= sprintf("%s\n", $self->name || '');
    return $str;
}


=head2 newick_format

  Arg [1]     : string $format_mode
  Example     : $this_node->newick_format("full");
  Description : Prints this tree in Newick format. Several modes are
                available: full, display_label_composite, simple, species,
                species_short_name, ncbi_taxon, ncbi_name, phylip
  Returntype  : string
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

my %ryo_modes = (
    'member_id' => '%{^-m}:%{d}',
    'member_id_taxon_id' => '%{-m}%{"_"-x}:%{d}',
    'display_label_composite' => '%{-l"_"}%{n}%{"_"-s}:%{d}',
    'full_common' => '%{n}%{" "-c.^}%{"."-g}%{"_"-t"_MYA"}:%{d}',
    'gene_stable_id_composite' => '%{-i"_"}%{n}%{"_"-s}:%{d}',
    'gene_stable_id' => '%{-i}:%{d}',
    'ncbi_taxon' => '%{o}',
    'ncbi_name' => '%{n}',
    'simple' => '%{^-n|i}:%{d}',
    'full' => '%{n|i}:%{d}',
    'species' => '%{^-S|p}',
    'species_short_name' => '%{^-s|p}',
    'otu_id' => '%{-s"|"}%{-l"|"}%{n}:%{d}',
    'int_node_id' => '%{-n}%{o-}:%{d}',
    'full_web' => '%{n-}%{-n|p}%{"_"-s"_"}%{":"d}',
    'phylip' => '%21{n}:%{d}',
);

my $nhx0 = '%{-n|i|C(taxonomy_level)}:%{d}';
my $nhx1 = ':%{-E"D=N"}%{C(_newick_dup_code)-}%{":B="C(bootstrap)}';
my $nhx2 = ':T=%{-x}%{C(species_tree_node,taxon_id)-}';

my %nhx_ryo_modes_1 = (
    'member_id_taxon_id' => '%{-m}%{o-}_%{-x}%{C(species_tree_node,taxon_id)-}:%{d}',
    'protein_id' => '%{-n}:%{d}',
    'transcript_id' => '%{-r}:%{d}',
    'gene_id' => '%{-i}:%{d}',
    'full' => $nhx0,
    'full_web' => $nhx0,
    'display_label' => '%{-l,|i}%{"_"-s}'.$nhx0,
    'display_label_composite' => '%{-l,"_"}%{-i}%{"_"-s}'.$nhx0,
    'treebest_ortho' => '%{-m}%{"_"-x}'.$nhx0,
    'simple' => $ryo_modes{'simple'},
    'phylip' => $ryo_modes{'phylip'},
);

my %nhx_ryo_modes_2 = (
    'member_id_taxon_id' => $nhx1.$nhx2,
    'protein_id' => $nhx1.'%{":G="-i}'.$nhx2,
    'transcript_id' => $nhx1.'%{":G="-i}'.$nhx2,
    'gene_id' => $nhx1.'%{":G="-r}'.$nhx2,
    'full' => $nhx1.$nhx2,
    'full_web' => $nhx1.$nhx2,
    'display_label' => $nhx1.$nhx2,
    'display_label_composite' => $nhx1.$nhx2,
    'treebest_ortho' => $nhx1.$nhx2.':S=%{-x}%{C(species_tree_node,taxon_id)-}',
);


sub newick_format {
    my $self = shift;
    my $format_mode = shift;

    my $ryo_string;

    if (not defined $format_mode) {
        $ryo_string = $ryo_modes{'full'};

    } elsif ($format_mode eq "ryo") {
        $ryo_string = shift @_;

    } elsif (defined $ryo_modes{$format_mode}) {
        $ryo_string = $ryo_modes{$format_mode};

    } else {
        throw("Unrecognized format '$format_mode'. Please use 'ryo' to introduce a roll-your-own format string\n");
    }
    return $self->_internal_newick_format_ryo($ryo_string);
}


=head2 nhx_format

  Arg [1]     : string $format_mode
  Example     : $this_node->nhx_format("full");
  Description : Prints this tree in NHX format. Several modes are:
                member_id_taxon_id, protein_id, transcript_id, gene_id,
                full, full_web, display_label, display_label_composite,
                treebest_ortho, simple, phylip
  Returntype  : string
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

sub nhx_format {
    my ($self, $format_mode) = @_;
    my $ryo_string1;
    my $ryo_string2;

    if (not defined $format_mode) {
        $ryo_string1 = $nhx_ryo_modes_1{'protein_id'};
        $ryo_string2 = $nhx_ryo_modes_2{'protein_id'};

    } elsif ($format_mode eq "ryo") {
        $ryo_string1 = shift @_;
        $ryo_string2 = shift @_;

    } elsif (defined $nhx_ryo_modes_1{$format_mode}) {
        $ryo_string1 = $nhx_ryo_modes_1{$format_mode};
        $ryo_string2 = $nhx_ryo_modes_2{$format_mode};

    } else {
        throw("Unrecognized format '$format_mode'. Please use 'ryo' to introduce a roll-your-own format string\n");
    }
    my $fmt = $ryo_string1;
    $fmt = $ryo_string1.'[&&NHX'.$ryo_string2.']' if defined $ryo_string2;
    return $self->_internal_newick_format_ryo($fmt);
}

sub _internal_newick_format_ryo {
    my ($self, $ryo_string) = @_;
    my $newick_str;
    eval {
        use Bio::EnsEMBL::Compara::Utils::FormatTree;
        my $ryo_formatter = Bio::EnsEMBL::Compara::Utils::FormatTree->new($ryo_string);
        $newick_str = $ryo_formatter->format_newick($self);
    };
    if ($@) {
        throw("Something bad happened while trying to stringify the tree: $@\n");
    }
    return "$newick_str;";
}



##################################
#
# Set theory methods
#
##################################

#sub equals {
#  my $self = shift;
#  my $other = shift;
#  assert_ref($other, 'Bio::EnsEMBL::Compara::NestedSet', 'other');
#  return 1 if($self->node_id eq $other->node_id);
#  foreach my $child (@{$self->children}) {
#    return 0 unless($other->has_child($child));
#  }
#  return 1;
#}

sub has_child {
  my $self = shift;
  my $child = shift;
  assert_ref($child, 'Bio::EnsEMBL::Compara::NestedSet', 'child');
  $self->load_children_if_needed;
  my $link = $self->link_for_neighbor($child);
  return 0 unless($link);
  return 0 if($self->{'_parent_link'} and ($self->{'_parent_link'}->equals($link)));
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
  assert_ref($nset, 'Bio::EnsEMBL::Compara::NestedSet', 'nset');
  foreach my $child_node (@{$nset->children}) {
    $self->add_child($child_node, $child_node->distance_to_parent);
  }
  return $self;
}

sub merge_node_via_shared_ancestor {
  my $self = shift;
  my $node = shift;

  my $node_id_index = shift or $self->_make_search_index_on_nodes('node_id', 1);

  my $node_dup = $node_id_index->{$node->node_id};
  if($node_dup) {
    #warn("trying to merge in a node with already exists\n");
    return $node_dup;
  }

  while (my $parent = $node->parent) {
    my $ancestor = $node_id_index->{$parent->node_id};
    if($ancestor) {
      $ancestor->add_child($node);
      #print("common ancestor at : "); $ancestor->print_node;
      return $ancestor;
    }
    $node_id_index->{$parent->node_id} = $parent;
    $node = $parent;
  }
}


# NB: Will also minimize the tree
sub extract_subtree_from_leaves {
    my $self = shift;
    my $node_ids = shift;	# Array ref of node_ids.

    my %node_ids_to_keep = map {$_ => 1} @{$node_ids};
    return $self->_rec_extract_subtree_from_leaves(\%node_ids_to_keep);
}

sub _rec_extract_subtree_from_leaves {
    my $self = shift;
    my $node_ids_to_keep = shift;   # hashref
    if ($self->is_leaf) {
        if ($node_ids_to_keep->{$self->node_id}) {
            my $copy = $self->copy_node;
            $copy->node_id($self->node_id);
            return $copy;
        } else {
            return undef;
        }
    } else {
        my @new_children = grep {$_} map {$_->_rec_extract_subtree_from_leaves($node_ids_to_keep)} @{$self->children};
        if (scalar(@new_children) == 0) {
            return undef;
        } elsif (scalar(@new_children) == 1) {
            $new_children[0]->distance_to_parent( $new_children[0]->distance_to_parent + $self->distance_to_parent );
            return $new_children[0];
        } else {
            my $copy = $self->copy_node;
            $copy->node_id( $self->node_id );
            $copy->add_child($_, $_->distance_to_parent) for @new_children;
            return $copy;
        }
    }
}

##################################
#
# nested_set manipulations
#
##################################


=head2 flatten_tree

  Overview   : Removes all internal nodes and attaches leaves to the tree root, creating
               a "flattened" star tree structure.
  Example    : $node->flatten_tree();
  Returntype : undef or Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub flatten_tree {
  my $self = shift;
  
  my $leaves = $self->get_all_leaves;
  foreach my $leaf (@{$leaves}) { 
    $leaf->disavow_parent;
  }

  $self->release_children;
  foreach my $leaf (@{$leaves}) {
    $self->add_child($leaf, 0.0);
  }
  
  return $self;
}

=head2 re_root

  Overview   : rearranges the tree structure so that the root is moved to 
               beetween this node and its parent.  If the old root was more than
	       bifurcated (2 children) a new node is created where it was to hold
	       the multiple children that arises from the re-rooting.  
	       The old root is returned.
  Example    : $node->re_root();
  Returntype : undef or Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub re_root {
  my $self = shift;
  
  return $self unless($self->parent); #I'm root so just return self

  my $root = $self->root;
  my $tmp_root = new Bio::EnsEMBL::Compara::NestedSet;
  $tmp_root->merge_children($root);
    
  my $parent = $self->parent;
  my $dist = $self->distance_to_parent;
  $self->disavow_parent;

  my $old_root = $parent->_invert_tree_above;
  $old_root->minimize_node;
  
  $root->add_child($parent, $dist / 2.0);
  $root->add_child($self, $dist / 2.0);
  
  return $root;
}


sub _invert_tree_above {
  my $self = shift;
  return $self unless($self->parent);
  
  my $old_root =  $self->parent->_invert_tree_above;
  #now my parent has been inverted so it is the new root
  
  #flip the direction of the link between myself and my parent
  $self->parent->_set_parent_link($self->{'_parent_link'});
  $self->_set_parent_link(undef);
  
  #now I'm the new root and the old root might need to be modified
  return $old_root;
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


=head2 remove_nodes

  Arg [1]     : arrayref Bio::EnsEMBL::Compara::NestedSet $nodes
  Example     : my $ret_tree = $tree->remove_nodes($nodes);
  Description : Returns the tree with removed nodes in list. Nodes should be in the tree.
  Returntype  : Bio::EnsEMBL::Compara::NestedSet object
  Exceptions  :
  Caller      : general
  Status      : At risk (behaviour on exceptions could change)

=cut

sub remove_nodes {
  my $self = shift;
  my $nodes = shift;

  foreach my $node (@$nodes) {
    if ($node->is_leaf) {
      $node->disavow_parent;
      $self = $self->minimize_tree;
    } else {
      my $node_children = $node->children;
      foreach my $child (@$node_children) {
        $node->parent->add_child($child);
      }
      $node->disavow_parent;
    }
    # Delete dangling one-child trees (help memory manager)
    if ($self->get_child_count == 1) {
      my $child = $self->children->[0];
      $child->parent->merge_children($child);
      $child->disavow_parent;
      return undef;
    }
    # Could be zero if all asked to delete, so return undef instead of
    # fake one-node tree.
    if ($self->get_child_count < 2) {
      return undef;
    }
  }
  return $self;
}


=head2 delete_lineage

  Arg [1]     : Bio::EnsEMBL::Compara::NestedSet $node
  Example     : $tree->delete_lineage($node);
  Description : Removes $node from tree. Nodes should be in the tree.
  Returntype  : 
  Exceptions  :
  Caller      : general
  Status      : At risk (behaviour on exceptions could change)

=cut

sub delete_lineage {
  my $self = shift;
  my $del_me = shift;

  assert_ref($del_me, 'Bio::EnsEMBL::Compara::NestedSet', 'del_me');

  my $parent = $del_me->parent;
  while ($parent) {
    my $num_children = scalar @{$parent->children};
    if ($num_children > 1) {
      $self->remove_nodes([$del_me]);
      return $self;
    } elsif ($num_children == 1) {
      $self->remove_nodes([$del_me]);
      $del_me = $parent;
      $parent = $del_me->parent;
    }
  }
  return $self;
}

=head2 minimize_tree

  Arg [1]     : -none-
  Example     : $leaf->disavow_parent();
                $tree = $tree->minimize_tree();
  Description : Returns the tree after removing internal nodes that do not
                represent an multi- or bi-furcation anymore. This is typically
                required after disavowing a node. Please ensure you use the
                object returned by the method and not the original object
                anymore!
  Returntype  : Bio::EnsEMBL::Compara::NestedSet object
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

sub minimize_tree {
  my $self = shift;
  return $self if($self->is_leaf);
  
  foreach my $child (@{$self->children}) { 
    $child->minimize_tree;
  }
  return $self->minimize_node;
}


sub minimize_node {
  my $self = shift;
  
  return $self unless($self->get_child_count() == 1);
  
  my $child = $self->children->[0];
  my $dist = $child->distance_to_parent + $self->distance_to_parent;
  if ($self->parent) {
     $self->parent->add_child($child, $dist); 
     $self->disavow_parent;
  } else {
     $child->disavow_parent;
  }
  return $child
}


sub scale {
  my $self = shift;
  my $scale = shift;

  # This is faster than traverse_tree
  foreach my $node (@{$self->get_all_nodes}) {
    my $bl = $node->distance_to_parent;
    $bl = 0 unless (defined $bl);
    $node->distance_to_parent($bl*$scale);
  }
  return $self;
}


sub scale_max_to {
  my $self = shift;
  my $new_max = shift;

  my $max_dist = $self->max_distance + $self->distance_to_parent;
  my $scale_factor = $new_max / $max_dist;
  return $self->scale($scale_factor);
}



##################################
#
# search methods
#
##################################

sub find_nodes_by_field {
    my ($self, $field, $value, $acc) = @_;

    $acc = [] unless (defined $acc);

    unless ($self->can($field)) {
        warning("No method $field available for class $self\n");
        return undef;
    }

    push @$acc, $self if((defined $self->$field) and ($self->$field eq $value));
#    return $self if((defined $self->$field) and ($self->$field eq $value));

    my $children = $self->children;
    for my $child (@$children) {
        $child->find_nodes_by_field($field, $value, $acc);
#        my $found = $child->find_node_by_field($field, $value);
#        return $found if(defined $found);
    }
    return $acc;
#    return undef;
}

sub _make_search_index_on_nodes {
    my ($self, $field, $keep_only_one) = @_;
    my %hash = ();
    # This is faster than traverse_tree
    foreach my $node (@{$self->get_all_nodes}) {
        if ($node->can($field) and (defined $node->$field)) {
            if ($keep_only_one) {
                $hash{$node->$field} = $node;
            } else {
                push @{$hash{$node->$field}}, $node;
            }
        }
    }
    return \%hash;
}

sub find_node_by_name {
  my $self = shift;
  my $name = shift;

  return $self->find_nodes_by_field('name', $name)->[0];
}

sub find_node_by_node_id {
  my $self = shift;
  my $node_id = shift;

  return $self->find_nodes_by_field('node_id', $node_id)->[0];
}

sub find_leaves_by_field {
    my ($self, $field, $value) = @_;

    my @leaves;
    $self->traverse_tree(sub {
        my $node = shift;
        if ($node->is_leaf && $node->can($field) && (defined $node->$field) && ($node->$field eq $value)) {
            push @leaves, $node;
        }
    });
    # The original implementation of find_leaves_by_field was calling
    # get_all_leaves, which sorts the leaves by node_id
    return [sort {$a->node_id <=> $b->node_id} @leaves];
}

sub find_leaf_by_name {
  my $self = shift;
  my $name = shift;

  return $self if((defined $self->name) and ($name eq $self->name));
  return $self->find_leaves_by_field('name', $name)->[0];
}

sub find_leaf_by_node_id {
  my $self = shift;
  my $node_id = shift;

  return $self if($node_id eq $self->node_id);
  return $self->find_leaves_by_field('node_id', $node_id)->[0];
}


=head2 get_all_sorted_leaves

  Arg [1]     : Bio::EnsEMBL::Compara::NestedSet $top_leaf
  Arg [...]   : (optional) Bio::EnsEMBL::Compara::NestedSet $secondary_priority_leaf
  Example     : my $sorted_leaves = $object->get_all_sorted_leaves($human_leaf);
  Example     : my $sorted_leaves = $object->get_all_sorted_leaves($human_leaf, $mouse_leaf);
  Description : Sorts the tree such as $top_leaf is the first leave and returns
                all the other leaves in the order defined by the tree.
                It is possible to define as many secondary top leaves as you require
                to sort other branches of the tree. The priority to sort the trees
                is defined by the order in which you specify the leaves.
  Returntype  : listref of Bio::EnsEMBL::Compara::NestedSet (all sorted leaves)
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_sorted_leaves {
  my ($self, @priority_leaves) = @_;

  if (!@priority_leaves) {
    return $self->get_all_leaves;
  }

  # Assign priority scores for all parent nodes of the priority leaves
  my $score_by_node;
  my $score = 0;
  # Loop through all the priority leaves, starting from the last one (lowest score)
  while (my $priority_leaf = pop @priority_leaves) {
    $score++; # Increases the score, next priority leaves (earlier in the argument list) will overwrite the score if needed
    my $this_node = $priority_leaf;
    # Loop through all the parent node up to the root of the tree
    do {
      $score_by_node->{$this_node} = $score;
      $this_node = $this_node->parent;
    } while ($this_node);
  }

  my $sorted_leaves = $self->_recursive_get_all_sorted_leaves($score_by_node);

  return $sorted_leaves;
}

=head2 _recursive_get_all_sorted_leaves

  Arg [1]     : hashref $score_by_node
  Example     : my $sorted_leaves = $object->_recursive_get_all_sorted_leaves($score_by_node);
  Description : Recursive code for the get_all_sorted_leaves() method
  Returntype  : listref of Bio::EnsEMBL::Compara::NestedSet (sorted leaves)
  Exceptions  : none
  Caller      : private
  Status      : Stable

=cut

sub _recursive_get_all_sorted_leaves {
  my $self = shift;
  my $score_by_node = shift;

  my $sorted_leaves = [];
  my $children = $self->children;

  if (@$children == 0) {
    $sorted_leaves = [$self];
  } else {
    $children = [sort {
        ($score_by_node->{$b} || $score_by_node->{$a}) ? (($score_by_node->{$b} || 0)<=>($score_by_node->{$a} || 0)) : ($a->node_id <=> $b->node_id)
      } @$children];
    for (my $i = 0; $i < @$children; $i++) {
      push(@$sorted_leaves, @{$children->[$i]->_recursive_get_all_sorted_leaves($score_by_node)});
    }
  }

  return $sorted_leaves;
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
  
  my $leaves = [];
  # The recursion is faster than traverse_tree
  $self->_recursive_get_all_leaves($leaves);
  my @leaf_list = sort {$a->node_id <=> $b->node_id} @{$leaves};
  return \@leaf_list;
}

sub _recursive_get_all_leaves {
  my $self = shift;
  my $leaves = shift;
    
  push @$leaves, $self if($self->is_leaf);

  foreach my $child (@{$self->children}) {
     no warnings 'recursion';
     $child->_recursive_get_all_leaves($leaves);
  }
}


=head2 traverse_tree_get_all_leaves

  Arg[1]      : $callback: subroutine to call on each internal node with an array of its leaves
  Example     : $node->traverse_tree_get_all_leaves(sub {my ($n, $l) = @_; print $n->name, " has ", scalar(@$l), " leaves\n"});
  Description : Returns the leaves of the tree, but also calls a callback method. Useful to traverse the tree whilst being aware of the leaves
  Returntype  : Arrayref of nodes (Bio::EnsEMBL::Compara::NestedSet)
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub traverse_tree_get_all_leaves {
    my ($self, $callback) = @_;
    return [$self] if $self->is_leaf;
    my @leaves;
    push @leaves, @{$_->traverse_tree_get_all_leaves($callback)} for @{$self->children};
    $callback->($self, \@leaves);
    return \@leaves;
}


=head2 random_binarize_node

 Title   : random_binarize_node
 Usage   : $node->random_binarize_node;
 Function: Forces the resolution of multifurcations on a given node. It resolves them randomly.
 Example :
 Returns : none
 Args    : none

=cut

sub random_binarize_node {
    my ($node) = @_;
    while (scalar(@{$node->children}) > 2) {
        my @children = @{$node->children};
        #----------------------------------------
        #Very simple algorithm (no need to recursivity):
        #   N = root of multifurcated node
        #   I = new internal node
        #   A = child 1
        #   B = child 2
        #
        # Select 2 children
        # Create new internal node attached to N
        # Attach A & B to I
        # Add new node back to the main node
        #----------------------------------------

        # Select 2 children
        my $child_A = $children[0];
        my $child_B = $children[1];

        # Create new internal node attached to N
        my $newNode = $node->copy_node();
        $newNode->adaptor($node->adaptor) if $node->adaptor;

        # Attach A & B to I
        # A & B will be automatically removed from previous parent
        $newNode->add_child($child_A);
        $newNode->add_child($child_B);

        # Add new node back to the main node
        $node->add_child($newNode)
    }
}

=head2 max_distance

 Title   : max_distance
 Args    : none
 Usage   : $tree_node->max_distance;
 Function: searching from the given starting node, calculates the maximum distance to a leaf
 Returns : int

=cut

sub max_distance {
  my $self = shift;

  my $max_distance = 0;
  
  foreach my $child (@{$self->children}) {
    my $distance = $child->distance_to_parent + $child->max_distance;
    $max_distance = $distance if($distance>$max_distance);
  }

  return $max_distance;
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


=head2 average_height

  Example     : $tree_node->average_height();
  Description : The average distance from the node to its leaves, computed in a recursive fashion.
                Once flattened out, the formula is basically a weighted average of the distances to
                the leaves, the weights being given by the degrees of each internal node.
  Returntype  : Float
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub average_height {
    my $self = shift;
    return 0 if $self->is_leaf;
    my $children = $self->children;
    my $s = sum(map {$_->distance_to_parent + average_height($_)} @$children);
    return $s/scalar(@$children);
}


=head2 find_first_shared_ancestor

  Arg [1]     : Bio::EnsEMBL::Compara::NestedSet $node
  Example     : my $ancestor = $this_node->find_first_shared_ancestor($other_node);
  Description : Gets the first common ancestor between this node and the other one.
  Returntype  : Bio::EnsEMBL::Compara::NestedSet object
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

sub find_first_shared_ancestor {
  my $self = shift;
  my $node = shift;

  return $self if($self->equals($node));
  return $node if($self->has_ancestor($node));
  return $self->find_first_shared_ancestor($node->parent);
}


sub find_first_shared_ancestor_from_leaves {
  my $self = shift;
  my $leaf_list = shift;

  my @leaves = @{$leaf_list};

  my $ancestor = shift @leaves;
  while (scalar @leaves > 0) {
    my $node = shift @leaves;
    $ancestor = $ancestor->find_first_shared_ancestor($node);
  }
  return $ancestor;
}


##################################
#
# developer/adaptor API methods
#
##################################


# used for building tree from a DB fetch, want to restrict users to create trees
# by only -add_child method
sub _set_parent_link {
  my ($self, $link) = @_;
  
  $self->{'_parent_id'} = 0;
  $self->{'_parent_link'} = $link;
  $self->{'_parent_id'} = $link->get_neighbor($self)->node_id if($link);
  return $self;
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

