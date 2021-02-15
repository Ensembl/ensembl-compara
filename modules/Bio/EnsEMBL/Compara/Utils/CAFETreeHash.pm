=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

use strict;
use warnings;

package Bio::EnsEMBL::Compara::Utils::CAFETreeHash;

use POSIX ();
use Bio::EnsEMBL::Utils::Scalar qw(check_ref);

sub convert {
  my ($self, $tree) = @_;

  return $self->_head_node($tree);
}

sub _head_node {
  my ($self, $tree) = @_;
  my $hash = {
    type => 'cafe tree',
    rooted => 1,
    pvalue_avg => $tree->pvalue_avg()+0,
  };

  if($tree->can('stable_id')) {
    $hash->{id} = $tree->stable_id();
  }

  $hash->{tree} = 
    $self->_recursive_conversion($tree->root());

  return $hash;
}

sub _recursive_conversion {
  my ($self, $tree) = @_;;
  my $new_hash = $self->_convert_node($tree);
  if($tree->get_child_count()) {
    my @converted_children;
    foreach my $child (@{$tree->sorted_children()}) {
      my $converted_child = $self->_recursive_conversion($child);
      push(@converted_children, $converted_child);
    }
    $new_hash->{children} = \@converted_children;
  }
  return $new_hash;
}

sub _convert_node {
  my ($self, $node) = @_;
  my $hash;

  my $taxon_id   = $node->taxon_id();
  if ($taxon_id) {
    $hash->{tax} = {
		    'id' => $taxon_id + 0,
		    'timetree_mya' => $node->get_divergence_time() || 0 + 0
		   };
    $hash->{tax}->{'scientific_name'} = $node->get_scientific_name;
    my $cn = $node->get_common_name();
    $hash->{tax}->{'common_name'} = $cn if $cn;
    if ($node->genome_db_id) {
        $hash->{tax}->{'production_name'} = $node->genome_db->name;
    }
  }

  my $node_id = $node->node_id();
  if (defined ($node_id)) {
    $hash->{id} = $node_id + 0;
  }

  my $n_members = $node->n_members();
  if (defined $n_members) {
    $hash->{n_members} = $n_members + 0;
  }

  my $pvalue = $node->pvalue();
  if (defined $pvalue) {
    $hash->{pvalue} = $pvalue + 0;
  }

  my $lambdas = $node->lambdas();
  if ($lambdas) {
    $hash->{lambda} = $lambdas + 0;
  }

  my $p_value_lim = $node->pvalue_lim();
  if ($p_value_lim) {
    $hash->{p_value_lim} = $p_value_lim+0;
  }

  my $is_node_significant = $node->is_node_significant();
  if ($is_node_significant) {
    $hash->{is_node_significant} = $is_node_significant + 0;
  }

  my $is_contraction = $node->is_contraction();
  if ($is_contraction) {
    $hash->{is_contraction} = $is_contraction + 0;
  }

  my $is_expansion = $node->is_expansion();
  if ($is_expansion) {
    $hash->{is_expansion} = $is_expansion + 0;
  }

  my $name = $node->node_name();
  if ($name) {
    $hash->{name} = $name;
  }

  return $hash;
}

# __PACKAGE__->meta()->make_immutable();

1;
