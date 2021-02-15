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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes

=head1 DESCRIPTION

Sets/Updates the neighbour nodes of every node of the given genomic align tree.

=over

=item root_id

Mandatory. Root ID of the genomic align tree to set/update.

=back

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes \
        -compara_db $(mysql-ens-compara-prod-7-ensadmin details url jalvarez_sauropsids_epo_update_103) \
        -root_id 19490000000007

=cut

package Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

$| = 1;

my $flanking_region = 1000000;

sub run {
    my( $self) = @_;

    my $root_id = $self->param('root_id');

    my $genomic_align_tree_adaptor = $self->compara_dba->get_GenomicAlignTreeAdaptor();
    my $this_genomic_align_tree = $genomic_align_tree_adaptor->fetch_node_by_node_id($root_id);
 
    my $all_nodes = $this_genomic_align_tree->get_all_nodes_from_leaves_to_this();
    foreach my $this_node (@{$all_nodes}) {
	if ($this_node->is_leaf()) {
	    $genomic_align_tree_adaptor->set_neighbour_nodes_for_leaf($this_node);
	} else {
	    set_neighbour_nodes_for_internal_node($this_node);
	}
    }
    print " ", $this_genomic_align_tree->node_id . "(" . @$all_nodes . ")" if $self->debug;
    $genomic_align_tree_adaptor->update_neighbourhood_data($this_genomic_align_tree);
}

##########################################
#
# internal methods
#
##########################################
sub set_neighbour_nodes_for_internal_node {
  my ($this_node) = @_;

  my ($left_node_id, $right_node_id);
  foreach my $this_child (@{$this_node->children}) {
    my $left_node = $this_child->left_node;
    my $right_node = $this_child->right_node;

    if ($left_node and $left_node->parent) {
      if (!defined($left_node_id)) {
        $left_node_id = $left_node->parent->node_id;
      } elsif ($left_node_id != $left_node->parent->node_id) {
        $left_node_id = undef;
      }
    } else {
      $left_node_id = undef;
    }
    if ($right_node and $right_node->parent) {
      if (!defined($right_node_id)) {
        $right_node_id = $right_node->parent->node_id;
      } elsif ($right_node_id != $right_node->parent->node_id) {
        $right_node_id = undef;
      }
    } else {
      $right_node_id = undef;
    }
    $left_node->release_tree if (defined $left_node);
    $right_node->release_tree if (defined $right_node);
  }
  $this_node->left_node_id($left_node_id);
  $this_node->right_node_id($right_node_id);

  return $this_node;
}

1;
