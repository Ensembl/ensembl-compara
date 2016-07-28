=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

use EnsEMBL::Web::TreeNode;
use EnsEMBL::Web::Exceptions qw(WebException);

sub new {
  ## @constructor
  ## @param Object with allowed keys if initialising from a cached object
  my ($class, $cached_object) = shift;

  my $self = bless {
    '_nodes'      => {},      # map of all the nodes belonging to this tree for easy lookup
    '_new_id'     => 'aaaa',  # incremental string id of the last node created that didn't have any id provided
    '_user_data'  => undef,   # reference to user data that's shared among all nodes of the tree
    '_root'       => undef,   # topmost node
    '_dom'        => undef,   # DOM object as needed by TreeNode's constructor
  }, $class;

  if ($cached_object) {
    for ($self->_cacheable_keys) {
      $self->{$_} = $cached_object;
    }
  }

  return $self;
}

sub get_cacheable_object {
  ## Gets the object that can be safely saved to a cache for this instance
  ## @return Hashref
  my $self = shift;

  return { map { $_ => $self->{$_} } $self->_cacheable_keys };
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

sub leaves {
  ## Gets all the leaves in the tree (nodes that don't have children)
  ## @return List of TreeNode objects
  return $_[0]->root->leaves;
}

sub get_node {
  ## Gets a node with the given id from anywhere in the tree
  ## @param Node id
  ## @return Requested node (EnsEMBL::Web::TreeNode object) or possibly undef if node with the given id doesn't exist
  my ($self, $id) = @_;

  throw WebException('Node id is needed to get a node') unless $id;

  return $self->{'_nodes'}{$self->clean_id($id)};
}

sub create_node {
  ## Create a new node, not yet inserted in the tree
  ## @param id of the node
  ## @param Hashref to be saved in 'data' key
  ## @return TreeNode object
  my ($self, $id, $data) = @_;

  $id = $id ? $self->clean_id($id) : $self->_generate_unique_id;

  # if node exists, update data and return node object
  if (exists $self->{'_nodes'}{$id}) {
    my $node = $self->{'_nodes'}{$id};
    $node->set_data($_, $data->{$_}) for keys %{$data || {}};

    return $node;
  }

  my $node = EnsEMBL::Web::TreeNode->new($self, $self->{'_dom'}, $id, $data);

  $self->{'_dom'} ||= $node->dom; # save it once and use it for other nodes

  return $self->{'_nodes'}{$id} = $node;
}

sub clone_node {
  ## Clones a node without it's child nodes
  ## @param Node to be cloned
  ## @param Id for the cloned node
  ## @return Cloned node
  my ($self, $node, $id) = @_;

  throw WebException('Node with given id already exists') if $id && $self->get_node($id);

  return $self->create_node($id, { map { $_ => $node->get_data($_) } $node->data_keys });
}

sub clean_id {
  ## Replaces anything other than a word (\w) and a hiphen with underscore
  return $_[1] =~ s/[^\w-]/_/gr;
}

sub clear_references {
  ## Clean interlinked references to make sure all tree nodes gets destroyed properly after we are done with it
  my $self = shift;

  if (my $root = delete $self->{'_root'}) {
    delete $self->{'_nodes'}{$_} for keys %{$self->{'_nodes'}};

    $root->clear_references;
  }
}

sub _generate_unique_id {
  ## @private
  my $self = shift;
  while (exists $self->{'_nodes'}{$self->{'_new_id'}}) {
    $self->{'_new_id'}++;
  }
  return $self->{'_new_id'};
}

sub _cacheable_keys {
  ## @private
  return qw(_nodes _new_id _root _dom);
}

1;
