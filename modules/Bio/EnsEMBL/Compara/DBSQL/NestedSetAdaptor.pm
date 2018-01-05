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

Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor

=head1 DESCRIPTION

Base adaptor for objects inheriting from NestedSet

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::NestedSet;

use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


###########################
# FETCH methods
###########################


=head2 fetch_all

  Example    : $all_trees = $proteintree_adaptor->fetch_all();
  Description: Fetches from the database all the nested sets.
               Note: this does not return all the nodes but all the roots
  Returntype : arrayref of Bio::EnsEMBL::Compara::NestedSet
  Exceptions :
  Caller     :

=cut

sub fetch_all {
  my ($self) = @_;

  my $table = ($self->_tables)[0]->[1];
  my $constraint = "$table.node_id = $table.root_id";
  return $self->generic_fetch($constraint);
}


=head2 fetch_node_by_node_id

  Arg [1]    : int $node_id
  Example    : $taxon = $nbcitaxonDBA->fetch_node_by_node_id($node_id);
  Description: Fetches the node (NestedSet) for the given node ID.
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Exceptions : thrown if $node_id is not defined
  Caller     : general

=cut

sub fetch_node_by_node_id {
  my ($self, $node_id) = @_;

  if (! defined $node_id) {
    throw("node_id is undefined")
  }

  my $table= ($self->_tables)[0]->[1];
  my $constraint = "$table.node_id = ?";
  $self->bind_param_generic_fetch($node_id, SQL_INTEGER);
  return $self->generic_fetch_one($constraint);
}


=head2 fetch_by_dbID

  Arg [1]    : int $node_id
  Example    : $taxon = $nbcitaxonDBA->fetch_by_dbID($node_id);
  Description: Fetches the node (NestedSet) for the given node ID.
               This is the same as fetch_node_by_node_id
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Exceptions : thrown if $node_id is not defined
  Caller     : general

=cut

sub fetch_by_dbID {
    my $self = shift;
    return $self->fetch_node_by_node_id(@_);
}


=head2 fetch_all_by_dbID_list

  Arg [1]    : Arrayref of node_ids
  Example    : $taxa = $nbcitaxonDBA->fetch_all_by_dbID_list([$taxon_id1, $taxon_id2]);
  Description: Returns all the NestedSet objects for the given node ids.
  Returntype : Arrayref of Bio::EnsEMBL::Compara::NestedSet
  Caller     : general

=cut

sub fetch_all_by_dbID_list {
    my ($self, $node_ids) = @_;

    return [] unless scalar(@$node_ids);

    my $table = ($self->_tables)[0]->[1];
    return $self->generic_fetch_concatenate($node_ids, $table.'.node_id', SQL_INTEGER);
}


=head2 fetch_parent_for_node

  Arg[1]     : NestedSet: $node
  Example    : $parent_node = $genetree_adaptor->fetch_parent_for_node($node);
  Description: Fetches from the database the parent node of a node, or returns
                the already-loaded instance if available
  Returntype : Bio::EnsEMBL::Compara::NestedSet

=cut

sub fetch_parent_for_node {
    my ($self, $node) = @_;

    assert_ref($node, 'Bio::EnsEMBL::Compara::NestedSet', 'node');

    return $node->{'_parent_link'}->get_neighbor($node) if defined $node->{'_parent_link'};
    my $parent = undef;
    $parent = $self->fetch_node_by_node_id($node->_parent_id) if defined $node->_parent_id;
    $parent->add_child($node) if defined $parent;
    return $parent;
}


sub fetch_all_children_for_node {
  my ($self, $node) = @_;

  assert_ref($node, 'Bio::EnsEMBL::Compara::NestedSet', 'node');

  my $constraint = 'parent_id = ?';
  $self->bind_param_generic_fetch($node->node_id, SQL_INTEGER);
  my $kids = $self->generic_fetch($constraint);
  foreach my $child (@{$kids}) { $node->add_child($child); }

  return $node;
}

sub fetch_all_leaves_indexed {
  my ($self, $node) = @_;

  assert_ref($node, 'Bio::EnsEMBL::Compara::NestedSet', 'node');
  my $table= ($self->_tables)[0]->[1];
  $self->bind_param_generic_fetch($node->_root_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($node->left_index, SQL_INTEGER);
  $self->bind_param_generic_fetch($node->right_index, SQL_INTEGER);
  my $constraint = "($table.root_id = ?) AND (($table.right_index - $table.left_index) = 1) AND ($table.left_index BETWEEN ? AND ?)";
  return $self->generic_fetch($constraint);
}

sub fetch_subtree_under_node {
  my $self = shift;
  my $node = shift;

  assert_ref($node, 'Bio::EnsEMBL::Compara::NestedSet', 'node');

  unless ($node->left_index && $node->right_index) {
    warning("fetch_subtree_under_node subroutine assumes that left and right index has been built and store in the database.\n This does not seem to be the case for node_id=".$node->node_id.". Returning node.\n");
    return $node;
  }

  my $alias = ($self->_tables)[0]->[1];

  $self->bind_param_generic_fetch($node->_root_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($node->left_index, SQL_INTEGER);
  $self->bind_param_generic_fetch($node->right_index, SQL_INTEGER);
  my $constraint = "($alias.root_id = ?) AND ($alias.left_index BETWEEN ? AND ?)";
  my $all_nodes = $self->generic_fetch($constraint);
  push @{$all_nodes}, $node;
  $self->_build_tree_from_nodes($all_nodes);
  return $node;
}


sub fetch_tree_at_node_id {
  my $self = shift;
  my $node_id = shift;

  assert_integer($node_id, 'node_id');

  my $node = $self->fetch_node_by_node_id($node_id);

  return $self->fetch_subtree_under_node($node);
}



=head2 fetch_tree_by_root_id

  Arg[1]     : root_id: integer
  Example    : $root_node = $proteintree_adaptor->fetch_tree_by_root_id(3);
  Description: Fetches from the database all the nodes linked to this root_id
                and links them in a tree structure. Returns the root node
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Caller     : general

=cut

sub fetch_tree_by_root_id {
  my ($self, $root_id) = @_;

  return $self->_build_tree_from_nodes($self->fetch_all_by_root_id($root_id));
}


=head2 fetch_all_by_root_id

  Arg[1]     : root_id: integer
  Example    : $all_nodes = $proteintree_adaptor->fetch_all_by_root_id(3);
  Description: Fetches from the database all the nodes linked to this root_id
  Returntype : Arrayref of Bio::EnsEMBL::Compara::NestedSet
  Caller     : general

=cut

sub fetch_all_by_root_id {
  my ($self, $root_id) = @_;

  my $table = ($self->_tables)[0]->[1];
  my $constraint = "$table.root_id = ?";
  $self->bind_param_generic_fetch($root_id, SQL_INTEGER);
  return $self->generic_fetch($constraint);
}


=head2 fetch_root_by_node

  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $node
  Example    : $root = $nested_set_adaptor->fetch_root_by_node($node);
  Description: Returns the root of the tree for this node
               with links to all the intermediate nodes. Sister nodes
               are not included in the result. Use fetch_node_by_node_id()
               method to get the whole tree (loaded on demand)
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Exceptions : thrown if $node is not defined
  Status     : At-risk
  Caller     : $nested_set->root

=cut

sub fetch_root_by_node {
  my ($self, $node) = @_;

  assert_ref($node, 'Bio::EnsEMBL::Compara::NestedSet', 'node');

  my $alias = ($self->_tables)[0]->[1];

  $self->bind_param_generic_fetch($node->_root_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($node->left_index, SQL_INTEGER);
  $self->bind_param_generic_fetch($node->right_index, SQL_INTEGER);

  my $constraint = "($alias.root_id = ?) AND ($alias.left_index <= ?) AND ($alias.right_index >= ?)";

  return $self->_build_tree_from_nodes($self->generic_fetch($constraint));
}


=head2 fetch_first_shared_ancestor_indexed

  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $node1
  Arg [2]    : Bio::EnsEMBL::Compara::NestedSet $node2
  Arg [n]    : Bio::EnsEMBL::Compara::NestedSet $node_n
  Example    : $lca = $nested_set_adaptor->fetch_first_shared_ancestor_indexed($node1, $node2);
  Description: Returns the first node of the tree that is an ancestor of all the nodes passed
               as arguments. There must be at least one argument, and all the nodes must share
               the same root
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Exceptions : thrown if the nodes don't share the same root_id

=cut

sub fetch_first_shared_ancestor_indexed {
  my $self = shift;
  
  my $node1 = shift;
  my $root_id = $node1->_root_id;
  my $min_left = $node1->left_index;
  my $max_right = $node1->right_index;

  while (my $node2 = shift) {
    if ($node2->_root_id != $root_id) {
      throw("Nodes must have the same root in fetch_first_shared_ancestor_indexed ($root_id != ".($node2->_root_id).")\n");
    }
    $min_left = $node2->left_index if $node2->left_index < $min_left;
    $max_right = $node2->right_index if $node2->right_index > $max_right;
  }

  my $alias = ($self->_tables)[0]->[1];
  my $constraint = "$alias.root_id = ? AND $alias.left_index <= ? AND $alias.right_index >= ?";
  my $final = " ORDER BY ($alias.right_index-$alias.left_index) LIMIT 1";
  $self->bind_param_generic_fetch($root_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($min_left, SQL_INTEGER);
  $self->bind_param_generic_fetch($max_right, SQL_INTEGER);
  return $self->generic_fetch_one($constraint, undef, $final);
}



###########################
# STORE methods
###########################

sub store_nodes_rec {
    my $self = shift;
    my $node = shift;

    $self->store_node($node, @_);
    for my $node(@{$node->children()}) {
        $self->store_nodes_rec($node, @_);
    }
    return $node->node_id;
}


sub update {
  my ($self, $node) = @_;

  assert_ref($node, 'Bio::EnsEMBL::Compara::NestedSet', 'node');

 my $table= ($self->_tables)[0]->[0];
  my $sth = $self->prepare("UPDATE $table SET parent_id = ?, root_id = ?, left_index = ?, right_index = ?, distance_to_parent = ? WHERE $table.node_id = ?");

  $sth->execute($node->parent ? $node->parent->node_id : undef, $node->root->node_id, $node->left_index, $node->right_index, $node->distance_to_parent, $node->node_id);
}


sub update_subtree {
  my $self = shift;
  my $node = shift;

  $self->update($node);

  foreach my $child (@{$node->children}) {
    $self->update_subtree($child);
  }
}


##################################
#
# Database related methods, sublcass overrides/inherits
#
##################################


sub _objs_from_sth {
    my ($self, $sth) = @_;
    my $node_list = [];

    while (my $rowhash = $sth->fetchrow_hashref) {
        my $node = $self->create_instance_from_rowhash($rowhash);
        push @$node_list, $node;
    }
    return $node_list;
}


sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;

  my $node = new Bio::EnsEMBL::Compara::NestedSet;
  $self->init_instance_from_rowhash($node, $rowhash);

  return $node;
}


sub init_instance_from_rowhash {
  my $self = shift;
  my $node = shift;
  my $rowhash = shift;

  $node->adaptor($self);
  $node->node_id               ($rowhash->{'node_id'});
  $node->_parent_id            ($rowhash->{'parent_id'});
  $node->_root_id              ($rowhash->{'root_id'});
  $node->left_index            ($rowhash->{'left_index'});
  $node->right_index           ($rowhash->{'right_index'});
  $node->distance_to_parent    ($rowhash->{'distance_to_parent'});

  return $node;
}


##################################
#
# INTERNAL METHODS
#
##################################


sub _build_tree_from_nodes {
  my $self = shift;
  my $node_list = shift;

  #first hash all the nodes by id for fast access
  my %node_hash;
  foreach my $node (@{$node_list}) {
    $node->no_autoload_children;
    $node_hash{$node->node_id} = $node;
  }

  #next add children to their parents
  my $root = undef;
  foreach my $node (@{$node_list}) {
    my $parent = $node->_parent_id ? $node_hash{$node->_parent_id} : undef;
    if($parent) { $parent->add_child($node); }
    else { $root = $node; }
  }
  return $root;
}


1;
