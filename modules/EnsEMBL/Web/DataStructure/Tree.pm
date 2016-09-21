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

package EnsEMBL::Web::DataStructure::Tree;

## Typical tree with multiple siblings, multiple child nodes and single parent node

use strict;
use warnings;
no warnings qw(recursion); # deep recursion expected

use EnsEMBL::Web::Exceptions qw(DataStructureException);

use parent qw(EnsEMBL::Web::DataStructure::DoubleLinkedList);

sub new {
  my ($class, $obj) = @_;

  $obj->{'__ds_first_child'}  = undef;
  $obj->{'__ds_last_child'}   = undef;
  $obj->{'__ds_parent'}       = undef;

  return $class->SUPER::new($obj);
}

sub to_array {
  my ($self, $options) = @_;

  $options ||= {};

  my $array;
  my $unlink = delete $options->{'unlink'};

  if (delete $options->{'siblings_only'}) {
     $array = $self->SUPER::to_array;

  } elsif (delete $options->{'whole_tree'}) {
    $array = $self->top->to_array($options);

  } else {
    $array = [ $self ];

    my $children = $self->children;

    push @$array, @$children if $options->{'breadth_first'};

    for (@$children) {
      push @$array, $_ unless $options->{'breadth_first'};
      push @$array, $_->to_array($options);
    }
  }

  $self->unlink if $unlink;

  return $array;
}

sub get_all_nodes {
  ## Gets all the child nodes recursively from a node
  ## @return ArrayRef of Tree objects
  my $self  = shift;
  my $nodes = [];

  push @$nodes, $self if @_ && shift;
  push @$nodes, @{$_->get_all_nodes(1)} for @{$self->children};
  return $nodes;
}

sub parent {
  return shift->{'__ds_parent'};
}

sub first_child {
  return shift->{'__ds_first_child'};
}

sub last_child {
  return shift->{'__ds_last_child'};
}

sub children {
  return shift->{'__ds_first_child'}->to_array({'siblings_only' => 1});
}

sub top {
  my $node = shift;

  $node = $node->{'__ds_parent'} while $node->{'__ds_parent'};

  return $node;
}

sub append {
  my ($self, $child) = @_;

  $self->_append($self->_check_node($child)->remove);

  return $self;
}

sub prepend {
  my ($self, $child) = @_;

  $self->_prepend($self->_check_node($child)->remove);

  return $self;
}

sub append_to {
  my ($self, $parent) = @_;

  $self->_check_node($parent)->_append($self->remove);

  return $self;
}

sub prepend_to {
  my ($self, $parent) = @_;

  $self->_check_node($parent)->_prepend($self->remove);

  return $self;
}

sub remove {
  my $self = shift;

  my $parent = $self->{'__ds_parent'};

  if ($parent->{'__ds_first_child'} eq $self) {
    $parent->{'__ds_first_child'} = $self->{'__ds_next'};
  }

  if ($parent->{'__ds_last_child'} eq $self) {
    $parent->{'__ds_last_child'} = $self->{'__ds_prev'};
  }

  return $self->SUPER::remove;
}

sub unlink {
  my $self = shift->SUPER::unlink;

  my $parent      = delete $self->{'__ds_parent'};
  my $first_child = delete $self->{'__ds_first_child'};

  delete $self->{'_ds_last_child'};

  $parent->unlink       if $parent;
  $first_child->unlink  if $first_child;

  return $self;
}

sub _check_node_hierarchy {
  my ($node, $child) = @_;

  while ($node = $node->{'__ds_parent'}) {
    throw DataStructureException('Attempt to append ancestor node as a child node in the tree.') if $node eq $child;
  }

  return $child;
}

sub _append {
  my ($self, $child) = @_;

  $self->{'__ds_last_child'}->_after($self->_check_node_hierarchy($child)) if $self->{'__ds_last_child'};
  $self->{'__ds_last_child'} = $child;
}

sub _prepend {
  my ($self, $child) = @_;

  $self->{'__ds_first_child'}->_before($self->_check_node_hierarchy($child)) if $self->{'__ds_first_child'};
  $self->{'__ds_first_child'} = $child;
}

1;
