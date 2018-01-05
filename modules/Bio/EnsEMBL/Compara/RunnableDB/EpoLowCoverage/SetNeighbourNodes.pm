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

Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes

=head1 SYNOPSIS

    $set_neighbour_nodes->fetch_input();
    $set_neighbour_nodes->run();
    $set_neighbour_nodes->write_output(); writes to database

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

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

    my $mlss_id = $self->param('mlss_id');

    my $method_link_species_set_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $genomic_align_tree_adaptor = $self->compara_dba->get_GenomicAlignTreeAdaptor();
    my $genomic_align_block_adaptor = $self->compara_dba->get_GenomicAlignBlockAdaptor();
    
    my $method_link_species_set;
     if ($mlss_id) {
 	$method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($mlss_id);
 	if (!$method_link_species_set) {
 	    die "Cannot find a MLSS for ID $mlss_id\n";
 	}
     } else {
	 die "Must define a valid method_link_species_set_id\n";
     }

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
        $left_node_id = 0;
      }
    } else {
      $left_node_id = 0;
    }
    if ($right_node and $right_node->parent) {
      if (!defined($right_node_id)) {
        $right_node_id = $right_node->parent->node_id;
      } elsif ($right_node_id != $right_node->parent->node_id) {
        $right_node_id = 0;
      }
    } else {
      $right_node_id = 0;
    }
    $left_node->release_tree if (defined $left_node);
    $right_node->release_tree if (defined $right_node);
  }
  $this_node->left_node_id($left_node_id) if ($left_node_id);
  $this_node->right_node_id($right_node_id) if ($right_node_id);

  return $this_node;
}

1;
