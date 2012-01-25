=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes

=head1 SYNOPSIS

    $set_neighbour_nodes->fetch_input();
    $set_neighbour_nodes->run();
    $set_neighbour_nodes->write_output(); writes to database

=head1 DESCRIPTION


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes;

use strict;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

$| = 1;

my $flanking_region = 1000000;

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->compara_dba->dbc->disconnect_when_inactive(0);
}

sub run {
    my( $self) = @_;

    my $root_id = $self->param('root_id');

    my $mlss_id = $self->param('method_link_species_set_id');

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
