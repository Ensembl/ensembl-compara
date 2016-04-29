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

package EnsEMBL::Web::DataStructure::DoubleLinkedList;

## Typical double linked list

use strict;
use warnings;
no warnings qw(recursion); # deep recursion expected

use EnsEMBL::Web::Exceptions qw(DataStructureException);

use parent qw(EnsEMBL::Web::DataStructure::Node);

sub new {
  my ($class, $obj) = @_;

  $obj->{'__ds_prev'} = undef;
  $obj->{'__ds_next'} = undef;

  return $class->SUPER::new($obj);
}

sub from_array {
  my ($class, $arrayref) = @_;

  my ($node1, $node2);

  for (reverse @$arrayref) {
    $node2 = $class->_check_node($_)->remove;
    $node1->_before($node2) if $node1;
    $node1 = $node2;
  }

  return $node1;
}

sub to_array {
  my ($self, $options) = @_;

  my @array = ($self->node);

  my $node = $self;
  while ($node = $node->{'__ds_next'}) {
    push @array, $node->node;
  }

  $node = $self;
  while ($node = $node->{'__ds_prev'}) {
    unshift @array, $node->node;
  }

  $self->unlink if $options && $options->{'unlink'};

  return \@array;
}

sub next {
  return shift->{'__ds_next'};
}

sub previous {
  return shift->{'__ds_prev'};
}

sub first {
  my $node = shift;

  $node = $node->{'__ds_prev'} while $node->{'__ds_prev'};

  return $node;
}

sub last {
  my $node = shift;

  $node = $node->{'__ds_next'} while $node->{'__ds_next'};

  return $node;
}

sub remove {
  my $self = shift;

  $self->{'__ds_next'}{'__ds_prev'} = $self->{'__ds_prev'} if $self->{'__ds_next'};
  $self->{'__ds_prev'}{'__ds_next'} = $self->{'__ds_next'} if $self->{'__ds_prev'};

  return $self;
}

sub after {
  my ($self, $new_node) = @_;

  $self->_after($self->_check_node($new_node)->remove);

  return $self;
}

sub before {
  my ($self, $new_node) = @_;

  $self->_before($self->_check_node($new_node)->remove);

  return $self;
}

sub insert_after {
  my ($self, $ref_node) = @_;

  $self->_check_node($ref_node)->_after($self->remove);

  return $self;
}

sub insert_before {
  my ($self, $ref_node) = @_;

  $self->_check_node($ref_node)->_before($self->remove);

  return $self;
}

sub unlink {
  my $self = shift;

  my $previous  = delete $self->{'__ds_prev'};
  my $next      = delete $self->{'__ds_next'};

  $previous->unlink if $previous;
  $next->unlink     if $next;

  return $self;
}

sub _check_node {
  my ($self, $node) = @_;

  my $class = ref $self || $self;

  if ($node && ref $node) {
    if (ref $self && $self eq $node) {
      throw DataStructureException('Attempt to insert duplicate node in the linked list.');
    }
    return $class->new($node) if ref $node eq 'HASH';
    return $node if UNIVERSAL::isa($node, $class);
  }

  return $class->new({'__ds_node' => $node});
}

sub _before {
  my ($self, $node) = @_;

  $self->{'__ds_prev'}{'__ds_next'} = $node if $self->{'__ds_prev'};
  $node->{'__ds_prev'}              = $self->{'__ds_prev'};
  $node->{'__ds_next'}              = $self;
  $self->{'__ds_prev'}              = $node;
}

sub _after {
  my ($self, $node) = @_;

  $self->{'__ds_next'}{'__ds_prev'} = $node if $self->{'__ds_next'};
  $node->{'__ds_next'}              = $self->{'__ds_next'};
  $node->{'__ds_prev'}              = $self;
  $self->{'__ds_next'}              = $node;
}

1;
