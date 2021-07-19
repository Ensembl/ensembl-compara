=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Tree;

use strict;
use warnings;

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::TreeNode;
use EnsEMBL::Web::Exceptions qw(WebException);
use EnsEMBL::Web::Utils::Sanitize qw(clean_id);

sub new {
  ## @constructor
  my $class = shift;

  my $self = bless {
    '_node_lookup'  => {},      # map of all the nodes belonging to this tree for easy lookup
    '_new_id'       => 'aaaa',  # incremental string id of the last node created that didn't have any id provided
    '_user_data'    => undef,   # reference to user data that's shared among all nodes of the tree
    '_root'         => undef,   # topmost node
    '_dom'          => undef,   # DOM object as needed by TreeNode's constructor
  }, $class;

  return $self;
}

sub user_data {
  ## Gets shared user data or sets user data for all nodes in the tree if argument provided
  ## @param (Optional - only required if setting) User data reference
  ## @return Reference to shared user data (any changes made to that reference afterwards will change the shared user data)
  my $self = shift;

  if (@_ && $_[0] && ref $_[0]) { # only a reference please
    $self->{'_user_data'} = $_[0];
  }

  return $self->{'_user_data'} ||= {};
}

sub nodes {
  ## Gets all the nodes in the tree
  ## @return List of TreeNode objects
  return @{shift->root->get_all_nodes};
}

sub root {
  ## Gets the root node (creates a new one if there's none)
  ## @return TreeNode object
  my $self = shift;

  return $self->{'_root'} //= $self->create_node;
}

sub get_node {
  ## Gets a node with the given id from anywhere in the tree
  ## @param Node id
  ## @return Requested node(s) (EnsEMBL::Web::TreeNode object or list of multiple objects in list context) or possibly undef if node with the given id doesn't exist
  my ($self, $id) = @_;

  if (!$id) {
    warn 'ERROR at EnsEMBL::Web::Tree::get_node: Node id is needed to get a node';
    return undef;
  }

  my @nodes = grep $_->parent_node, @{$self->{'_node_lookup'}{clean_id($id)} || []};

  return wantarray ? @nodes : $nodes[0];
}

sub create_node {
  ## Create a new node, not yet inserted in the tree
  ## @param id of the node
  ## @param Hashref to be saved in 'data' key
  ## @return TreeNode object
  my ($self, $id, $data, $id_duplicate_ok) = @_;

  $id = $id ? clean_id($id) : $self->_generate_unique_id;

  # if node exists, update data and return node object
  if ((my $node = $self->get_node($id)) && !$id_duplicate_ok) {
    $node->set_data($_, $data->{$_}) for keys %{$data || {}};

    return $node;
  }

  my $node = EnsEMBL::Web::TreeNode->new($self, $self->{'_dom'}, $id, $data);

  $self->{'_dom'} ||= $node->dom; # save it once and use it for other nodes

  push @{$self->{'_node_lookup'}{$id}}, $node;

  return $node;
}

sub append_node {
  ## Append a node to the root node
  ## @param As excepted by create_node or a TreeNode object
  ## @return Newly appended TreeNode object
  my $self = shift;

  return $self->root->append_child(UNIVERSAL::isa($_[0], 'EnsEMBL::Web::TreeNode') ? $_[0] : $self->create_node(@_));
}

sub prepend_node {
  ## Inserts a node to the beginning of the root node
  ## @param As excepted by create_node or a TreeNode object
  ## @return Newly inserted TreeNode object
  my $self = shift;

  return $self->root->prepend_child(UNIVERSAL::isa($_[0], 'EnsEMBL::Web::TreeNode') ? $_[0] : $self->create_node(@_));
}

sub clone_node {
  ## Clones a node without it's child nodes
  ## @param Node to be cloned
  ## @param Node id, if to be kept different than the original node
  ## @return Cloned node
  my ($self, $node, $id) = @_;

  return $self->create_node($id // $node->id, { map({ $_ => $node->get_data($_) } $node->data_keys), 'cloned' => 1 }, 1);
}

sub clear_references {
  ## Clean interlinked references to make sure all tree nodes gets destroyed properly after we are done with it
  my $self = shift;

  if (my $root = delete $self->{'_root'}) {
    delete $self->{'_node_lookup'}{$_} for keys %{$self->{'_node_lookup'}};

    $root->clear_references;
  }
}

sub _generate_unique_id {
  ## @private
  my $self = shift;
  while (exists $self->{'_node_lookup'}{$self->{'_new_id'}}) {
    $self->{'_new_id'}++;
  }
  return $self->{'_new_id'};
}

sub _cacheable_keys {
  ## @private
  return qw(_node_lookup _new_id _root _dom);
}

sub append :Deprecated('Use tree->root->append_child')                 { return shift->root->append_child(@_);  }
sub leaves :Deprecated('Use tree->root->leaves')                       { return shift->root->leaves;  }

1;
