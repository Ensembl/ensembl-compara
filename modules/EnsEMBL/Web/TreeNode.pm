=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TreeNode;

use parent qw(EnsEMBL::Web::DOM::Node::Element::Generic);

use strict;
use warnings;

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Utils::EqualityComparator qw(is_same);

sub id    :Accessor;
sub data  :Accessor;
sub tree  :Accessor;

sub new {
  ## @constructor
  ## @param Tree object
  ## @param (Optional) DOM object as required by the parent constructor
  ## @param (Optional) Id of the node
  ## @param (Optional) Node specific data
  my ($class, $tree, $dom, $id, $data) =@_;

  my $self = $class->SUPER::new($dom);

  $self->{'id'}   = $id;
  $self->{'data'} = $data || {};
  $self->{'tree'} = $tree;

  return $self;
}

sub get_node    { return shift->tree->get_node(@_);   }
sub nodes       { return shift->tree->nodes(@_);      }
sub is_leaf     { return !$_[0]->has_child_nodes;     }
sub previous    { return $_[0]->previous_sibling;     }
sub next        { return $_[0]->next_sibling;         }
sub append      { return $_[0]->append_child($_[1]);  }
sub prepend     { return $_[0]->prepend_child($_[1]); }

sub descendants {
  ## Gets all the descendant nodes for this node
  ## @return List of TreeNode objects
  my $self = shift;

  return map { $_, $->descendants } @{$self->child_nodes};
}

sub leaves {
  ## Gets a list of all the leave nodes (nodes without any child node)
  ## @return List of TreeNode objects
  my $self = shift;

  return map { $_->has_child_nodes ? $_->leaves : $_ } @{$self->child_nodes};
}

sub get {
  ## Returns shared user data value for the given key if present, otherwise returns value from node specific data
  my ($self, $key)  = @_;
  my $user_data     = $self->user_data;
  my $node_id       = $self->id;

  return $user_data && exists $user_data->{$node_id} && exists $user_data->{$node_id}{$key} ? $user_data->{$node_id}{$key} : $self->data->{$key};
}

sub set {
  ## Adds/modifies the given key-value pair in the 'data' key (not user_data key - use set_user_setting for that)
  my ($self, $key, $value) = @_;
  $self->data->{$key} = $value;
}

sub set_user_setting {
  ## Modifies given key-value from shared user data key node's id
  ## @return 1 if data is changed, 0 otherwise
  my ($self, $key, $value) = @_;

  my $node_id   = $self->id;
  my $user_data = $self->tree->user_data;

  # If same as default value - remove data
  if (is_same($value, $self->data->{$key})) {
    delete $user_data->{$node_id}{$key};
    delete $user_data->{$node_id} unless scalar %{$user_data->{$node_id}};
    return 1;
  }

  # If not same as current value set and return true
  if (!is_same($value, $user_data->{$node_id}{$key})) {
    $user_data->{$node_id}{$key} = $value;
    return 1;
  }

  return 0;
}

sub reset_user_settings {
  ## Removes shared user data settings for the current node
  ## @return 1 if data is removed, 0 otherwise
  my $self      = shift;
  my $node_id   = $self->node_id;
  my $user_data = $self->tree->user_data;

  # remove node specific data if it exists
  if (exists $user_data->{$node_id}) {
    delete $user_data->{$node_id};
    return 1;
  }

  return 0;
}

sub clear_references {
  ## Clean interlinked references to make sure object gets destroyed properly after we are done with it
  my $self  = shift;

  # remove all child nodes, and clear references on each node
  $_->clear_references for @{$self->remove_children};
}

sub set_user :Deprecated('Use set_user_setting') { return shift->set_user_setting(@_); }

1;
