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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters

=head1 DESCRIPTION

This is a base RunnableDB to stores a set of clusters in the database.
ProteinTrees::HclusterParseOutput and ncRNAtrees::RFAMClassify both
inherit from it. The easiest way to use this class is by creating an
array of arrays of member_id, and give it to store_and_dataflow_clusterset.
This would create the c;usterset and create the subsequent jobs.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters;

use strict;

use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::GeneTreeNode;
use Bio::EnsEMBL::Compara::GeneTreeMember;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 store_and_dataflow_clusterset

  Description: Shortcut for all the individual steps. This function stores the
               clusters and the clusterset, then flow the clusters into the
               branch 2.
  Arg [1]    : clusterset_id of the new clusterset
  Arg [2]    : hashref of hashref with at least a 'members' key
  Parameters : member_type, immediate_dataflow, input_id_prefix, sort_clusters
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub store_and_dataflow_clusterset {
    my $self = shift;
    my $clusterset_id = shift;
    my $allclusters = shift;
    
    my $clusterset = $self->fetch_or_create_clusterset($clusterset_id);
    print STDERR "STORING AND DATAFLOWING THE CLUSTERSET\n" if ($self->debug());
    for my $cluster_name (keys %$allclusters) {
        print STDERR "$cluster_name has ", scalar @{$allclusters->{$cluster_name}{members}} , " members (leaves)\n";
    }

    # Do we sort the clusters by decreasing size ?
    my @cluster_list;
    if ($self->param('sort_clusters')) {
        @cluster_list = sort {scalar(@{$allclusters->{$b}->{members}}) <=> scalar(@{$allclusters->{$a}->{members}})} keys %$allclusters;
    } else {
        @cluster_list = keys %$allclusters;
    }

    my @allcluster_ids;
    foreach my $cluster_name (@cluster_list) {
        print STDERR "Storing cluster with name $cluster_name\n" if ($self->debug());
        my $cluster = $self->add_cluster($clusterset, $allclusters->{$cluster_name});
        push @allcluster_ids, $cluster->root_id unless $self->param('immediate_dataflow');
    }
    $self->finish_store_clusterset($clusterset);
    $self->dataflow_clusters($clusterset, \@allcluster_ids);
}


=head2 fetch_or_create_clusterset

  Description: Create an empty clusterset and store it in the database if not
                present yet. Otherwise, return the existing object
  Parameters : mlss_id, member_type
  Arg [1]    : clusterset_id of the new clusterset
  Returntype : GeneTree: the created clusterset
  Exceptions : none
  Caller     : general

=cut

sub fetch_or_create_clusterset {
    my $self = shift;
    my $clusterset_id = shift;

    my $mlss_id = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";

    my %params = (
        -member_type => $self->param('member_type'),
        -tree_type => 'clusterset',
        -method_link_species_set_id => $mlss_id,
        -clusterset_id => $clusterset_id,
    );

    # Tries to get it from the database
    my $clusterset = $self->compara_dba->get_GeneTreeAdaptor->fetch_all(%params);
    return $clusterset->[0] if scalar(@$clusterset);

    $self->compara_dba->dbc->do('LOCK TABLES gene_tree_root WRITE, gene_tree_root AS gtr READ, gene_tree_node WRITE');

    # In case someone has meanwhile created the clusterset
    $clusterset = $self->compara_dba->get_GeneTreeAdaptor->fetch_all(%params);
   
    if (scalar(@$clusterset)) {
        $clusterset = $clusterset->[0];
    } else {
        # Create the clusterset and associate mlss
        $clusterset = new Bio::EnsEMBL::Compara::GeneTree(%params);
        # Assumes a root node will be automatically created
        $self->compara_dba->get_GeneTreeAdaptor->store($clusterset);
        print STDERR "Clusterset '$clusterset_id' created with root_id=", $clusterset->root_id, "\n" if $self->debug;
    }

    $self->compara_dba->dbc->do('UNLOCK TABLES');
    return $clusterset;
}


=head2 add_cluster

  Description: Create a new cluster (a root node linked to many leafes) and
               store it in the database.
  Parameters : member_type, immediate_dataflow, input_id_prefix
  Arg [1]    : clusterset to attach the new cluster to
  Arg [2]    : cluster definition (hash reference with a 'members' key and other tags)
  Returntype : GeneTree: the created cluster
  Exceptions : none
  Caller     : general

=cut

sub add_cluster {
    my $self = shift;
    my $clusterset = shift;
    my $cluster_def = shift;
    my $gene_list = $cluster_def->{members};

    return if (2 > scalar(@$gene_list));

    # Every cluster maps to a leaf of the clusterset
    my $clusterset_leaf = new Bio::EnsEMBL::Compara::GeneTreeNode;
    $clusterset_leaf->no_autoload_children();
    $clusterset->root->add_child($clusterset_leaf);

    # The new cluster object
    my $cluster = new Bio::EnsEMBL::Compara::GeneTree(
        -member_type => $self->param('member_type'),
        -tree_type => 'tree',
        -method_link_species_set_id => $clusterset->method_link_species_set_id,
        -clusterset_id => $clusterset->clusterset_id,
    );

    # The cluster root node
    my $cluster_root = $cluster->root;
    $clusterset_leaf->add_child($cluster_root);

    # The cluster leaves
    foreach my $member_id (@$gene_list) {
        my $leaf = new Bio::EnsEMBL::Compara::GeneTreeMember;
        $leaf->member_id($member_id);
        $cluster_root->add_child($leaf);
    }

    # Stores the cluster
    $self->compara_dba->get_GeneTreeNodeAdaptor->store($clusterset_leaf);
    $cluster->store_tag('gene_count', $cluster_root->get_child_count);
    print STDERR "cluster root_id=", $cluster->root_id, " in clusterset '", $clusterset->clusterset_id, "' with ", $cluster_root->get_child_count, " leaves\n" if $self->debug;
    
    # Stores the tags
    for my $tag (keys %$cluster_def) {
        next if $tag eq 'members';
        print STDERR "Storing tag $tag => ", $cluster_def->{$tag} , "\n" if ($self->debug);
        $cluster->store_tag($tag, $cluster_def->{$tag});
    }

    # Dataflows immediately or keep it for later
    if ($self->param('immediate_dataflow')) {
        $self->dataflow_output_id({ $self->param('input_id_prefix').'_tree_id' => $cluster->root_id, }, 2);
    }

    # Frees memory
    $cluster_root->disavow_parent();
    $cluster_root->release_tree();

    return $cluster;
}


=head2 finish_store_clusterset

  Description: Updates the left/right_index of the clusterset.
  Arg [1]    : clusterset to attach the new cluster to
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub finish_store_clusterset {
    my $self = shift;
    my $clusterset = shift;;

    # left/right_index for quicker clusterset retrieval
    $clusterset->root->build_leftright_indexing(1);
    $self->compara_dba->get_GeneTreeAdaptor->store($clusterset);
    my $leafcount = scalar(@{$clusterset->root->get_all_leaves});
    print STDERR "clusterset ", $clusterset->root_id, " / ", $clusterset->clusterset_id, " with $leafcount leaves\n" if $self->debug;
    $clusterset->root->print_tree if $self->debug;
}


=head2 dataflow_clusters

  Description: Creates one job per cluster into branch 2.
               Flows into branch 1 with the clusterset_id of the new clusterset
  Parameters : input_id_prefix
  Arg [1]    : clusterset
  Arg [2]    : array reference of root_id
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub dataflow_clusters {
    my $self = shift;
    my $clusterset = shift;
    my $root_ids = shift;

    # Loop on all the clusters that haven't been dataflown yet
    foreach my $tree_id (@$root_ids) {
        $self->dataflow_output_id({ $self->param('input_id_prefix').'_tree_id' => $tree_id, }, 2);
    }
    $self->dataflow_output_id({ 'clusterset_id' => $clusterset->clusterset_id }, 1);
}

1;
