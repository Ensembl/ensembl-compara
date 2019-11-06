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
no warnings 'uninitialized';

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Utils::EqualityComparator qw(is_same);

sub id    :Accessor;
sub tree  :Accessor;

sub new {
  ## @constructor
  ## @param Tree object
  ## @param (Optional) DOM object as required by the parent constructor
  ## @param (Optional) Id of the node
  ## @param (Optional) Node specific data
  ## @caller EnsEMBL::Web::Tree::create_node
  my ($class, $tree, $dom, $id, $data) =@_;

  my $self = $class->SUPER::new($dom);

  $self->{'id'}   = $id;
  $self->{'data'} = $data || {};
  $self->{'tree'} = $tree;

  return $self;
}

sub descendants {
  ## Gets all the descendant nodes for this node
  ## @return List of TreeNode objects
  my $self = shift;

  return map { $_, $_->descendants } @{$self->child_nodes};
}

sub leaves {
  ## Gets a list of all the leave nodes (nodes without any child node)
  ## @return List of TreeNode objects
  my $self = shift;

  return map { $_->has_child_nodes ? $_->leaves : $_ } @{$self->child_nodes};
}

sub get_data {
  ## Returns value from node specific data
  my ($self, $key) = @_;
  return $self->{'data'}{$key};
}

sub set_data {
  ## Adds/modifies the given key-value pair in the 'data' key (not user_data key - use set_user_setting for that)
  my ($self, $key, $value) = @_;
  $self->{'data'}{$key} = $value;
}

sub data_keys {
  ## Gets a list of all the data keys for the node
  ## @return List of keys (Strings)
  my $self = shift;
  return keys %{$self->{'data'}};
}

sub get {
  ## Returns shared user data value for the given key if present, otherwise returns value from node specific data
  my ($self, $key)  = @_;
  my $user_data     = $self->tree->user_data;
  my $node_id       = $self->id;

  return $user_data && exists $user_data->{$node_id} && exists $user_data->{$node_id}{$key} ? $user_data->{$node_id}{$key} : $self->get_data($key);
}

sub set_user_setting {
  ## Modifies given key-value from shared user data key node's id
  ## @return 1 if data is changed, 0 otherwise
  my ($self, $key, $value) = @_;

  my $node_id   = $self->id;
  my $user_data = $self->tree->user_data;

  if ($node_id =~ /trackhub_/) {
    $user_data->{$node_id}{$key} = $value;
    return 1;
  }

  # If same as default value - remove data
  if (is_same($value, $self->get_data($key))) {
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

sub delete_user_setting {
  ## Modifies given key-value from shared user data key node's id
  ## @return 1 if data is changed, 0 otherwise
  my ($self, $key) = @_;

  my $node_id   = $self->id;
  my $user_data = $self->tree->user_data;

  if ($user_data->{$node_id}) {
    delete $user_data->{$node_id}{$key};
    delete $user_data->{$node_id} unless scalar %{$user_data->{$node_id}};
    return 1;
  }
  else {
    return 0;
  }
}

sub has_user_settings {
  ## Checks if the node has any user data linked to it
  ## @return 1 if user settings for this node is presetn, 0 otherwise
  my $self = shift;

  return exists  $self->tree->user_data->{$self->id} ? 1 : 0;
}

sub reset_user_settings {
  ## Removes shared user data settings for the current node
  ## @return 1 if data is removed, 0 otherwise
  my $self      = shift;
  my $node_id   = $self->id;
  my $user_data = $self->tree->user_data;

  if ($node_id =~/^trackhub_/) {
    my $n = $self->get_node($node_id);
    $self->set_user_setting('display', $n->get_data('display'));
    return 1;
  }
  # remove node specific data if it exists
  elsif (exists $user_data->{$node_id}) {
    delete $user_data->{$node_id};
    return 1;
  }

  return 0;
}

sub insert_alphabetically {
  ## Inserts a child node among the existing children alphabetically according to a given key
  ## @param Node to be inserted
  ## @param Data key that needs to be compared alphabetically
  my ($self, $node, $key) = @_;

  $key          ||= 'caption';
  my $node_name   = $node->get_data($key);
  my $next_child  = $self->first_child;

  while ($next_child && ($next_child->get_data($key) || '') lt $node_name) { # empty string lt anything is true
    $next_child = $next_child->next_sibling;
  }

  return $next_child ? $self->insert_before($node, $next_child) : $self->append_child($node);
}

sub clear_references {
  ## Clean interlinked references to make sure object gets destroyed properly after we are done with it
  my $self  = shift;

  # remove all child nodes, and clear references on each node
  $_->clear_references for @{$self->remove_children};
}

sub data        :Deprecated('Use get_data/set_data/data_keys')  { return $_[0]->{'data'};             }
sub get_node    :Deprecated('Call get_nodes on tree')           { return shift->tree->get_node(@_);   }
sub nodes       :Deprecated('Call nodes on tree')               { return shift->tree->nodes(@_);      }
sub is_leaf     :Deprecated('Use has_child_nodes')              { return !$_[0]->has_child_nodes;     }
sub previous    :Deprecated('Use previous_sibling')             { return $_[0]->previous_sibling;     }
sub next        :Deprecated('Use next_sibling')                 { return $_[0]->next_sibling;         }
sub append      :Deprecated('Use append_child')                 { return $_[0]->append_child($_[1]);  }
sub prepend     :Deprecated('Use prepend_child')                { return $_[0]->prepend_child($_[1]); }
sub set_user    :Deprecated('Use set_user_setting')             { return shift->set_user_setting(@_); }
sub set         :Deprecated('Use set_data')                     { return shift->set_data(@_);         }

1;
