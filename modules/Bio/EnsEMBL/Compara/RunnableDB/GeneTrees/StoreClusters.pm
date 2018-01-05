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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters

=head1 DESCRIPTION

This is a base RunnableDB to stores a set of clusters in the database.
ProteinTrees::HclusterParseOutput, ncRNAtrees::RFAMClassify and ComparaHMM::HMMClusterize
inherit from it. The easiest way to use this class is by creating an
array of arrays of seq_member_id, and give it to store_clusterset.
This would create the clusterset and create the subsequent jobs.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::GeneTreeNode;
use Bio::EnsEMBL::Compara::GeneTreeMember;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');


=head2 store_clusterset

  Description: Shortcut for all the individual steps. This function stores the
               clusters and the clusterset
  Arg [1]    : clusterset_id of the new clusterset
  Arg [2]    : hashref of hashref with at least a 'members' key
  Parameters : member_type, immediate_dataflow, sort_clusters
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub store_clusterset {
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
    warn scalar(@cluster_list), " clusters to add\n";

    my @allcluster_ids;
    foreach my $cluster_name (@cluster_list) {
        print STDERR "Storing cluster with name $cluster_name\n" if ($self->debug());
        my $cluster = $self->add_cluster($clusterset, $allclusters->{$cluster_name});
        push @allcluster_ids, $cluster->root_id if ($cluster && !$self->param('immediate_dataflow'));
    }
    $self->build_clusterset_indexes($clusterset);
    return ($clusterset, [@allcluster_ids]);
}


=head2 fetch_or_create_clusterset

  Description: Fetch a clusterset from the database, or create (and store it)
               otherwise.
               NB: Do not call this method in parallel if you expect to create
               a clusterset: it may end up creating several ones
  Parameters : mlss_id, member_type
  Arg [1]    : clusterset_id of the new clusterset
  Returntype : GeneTree: the created clusterset
  Exceptions : none
  Caller     : general

=cut

sub fetch_or_create_clusterset {
    my $self = shift;
    my $clusterset_id = shift;

    my $mlss_id = $self->param_required('mlss_id');

    my %args = (
        -member_type => $self->param('member_type'),
        -tree_type => 'clusterset',
        -method_link_species_set_id => $mlss_id,
        -clusterset_id => $clusterset_id,
    );

    # Checks whether there is already a clusterset in the database
    my $all_matching_clustersets = $self->compara_dba->get_GeneTreeAdaptor->fetch_all(%args);
    if (scalar(@$all_matching_clustersets) >= 2) {
        die sprintf('Found %d "%s" clustersets in the database: which one to use ?', scalar(@$all_matching_clustersets), $clusterset_id);
    } elsif (scalar(@$all_matching_clustersets) == 1) {
        my $clusterset = $all_matching_clustersets->[0];
        print STDERR "Found clusterset '$clusterset_id' with root_id=", $clusterset->root_id, "\n" if $self->debug;
        return $clusterset;
    }

    # Create the clusterset and associate mlss
    my $clusterset = new Bio::EnsEMBL::Compara::GeneTree(%args);

    # Assumes a root node will be automatically created
    $self->compara_dba->get_GeneTreeAdaptor->store($clusterset);
    print STDERR "Clusterset '$clusterset_id' created with root_id=", $clusterset->root_id, "\n" if $self->debug;
    return $clusterset;
}


=head2 add_cluster

  Description: Create a new cluster (a root node linked to many leafes) and
               store it in the database.
  Parameters : member_type, immediate_dataflow 
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

    # Assumes that the *same* cluster may have been stored in a previous attempt
    my $existing_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_all_by_Member($gene_list->[0], -CLUSTERSET_ID => $clusterset->clusterset_id, -METHOD_LINK_SPECIES_SET => $clusterset->method_link_species_set_id);
    if (scalar(@$existing_tree)) {
        $self->warning(sprintf("There is already a tree with seq_member_id=%d: root_id=%s. not writing a new tree", $gene_list->[0], $existing_tree->[0]->root_id));
        return $existing_tree->[0];
    }

    # The new cluster object
    my $cluster = new Bio::EnsEMBL::Compara::GeneTree(
        -member_type => $self->param('member_type'),
        -tree_type => 'tree',
        -method_link_species_set_id => $clusterset->method_link_species_set_id,
        -clusterset_id => $clusterset->clusterset_id,
        $self->param('add_model_id') ? () : (-stable_id => $cluster_def->{'model_id'}),
    );

    # The cluster leaves
    foreach my $seq_member_id (@$gene_list) {
        my $leaf = new Bio::EnsEMBL::Compara::GeneTreeMember;
        $leaf->seq_member_id($seq_member_id);
        $cluster->add_Member($leaf);
    }

    # Stores the cluster
    $self->store_tree_into_clusterset($cluster, $clusterset);
    $cluster->store_tag('gene_count', scalar(@$gene_list));
    print STDERR "cluster root_id=", $cluster->root_id, " in clusterset '", $clusterset->clusterset_id, "' with ", scalar(@$gene_list), " leaves\n" if $self->debug;
    
    # Stores the tags
    for my $tag (keys %$cluster_def) {
        next if $tag eq 'members';
        print STDERR "Storing tag $tag => ", $cluster_def->{$tag} , "\n" if ($self->debug);
        $cluster->store_tag($tag, $cluster_def->{$tag});
    }

    # Dataflows immediately or keep it for later
    if ($self->param('immediate_dataflow')) {
        $self->dataflow_output_id({ 'gene_tree_id' => $cluster->root_id, }, 2);
    }

    # Frees memory
    my $cluster_root = $cluster->root;
    $cluster_root->disavow_parent();
    $cluster_root->release_tree();

    return $cluster;
}


=head2 build_clusterset_indexes

  Description: Updates the left/right_index of the clusterset.
  Arg [1]    : clusterset to attach the new cluster to
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub build_clusterset_indexes {
    my $self = shift;
    my $clusterset = shift;;

    # left/right_index for quicker clusterset retrieval
    $clusterset->root->build_leftright_indexing(1);
    my $sth = $self->compara_dba->dbc->prepare('UPDATE gene_tree_node SET left_index=?, right_index=? WHERE node_id = ?');
    foreach my $node ($clusterset->root, @{$clusterset->root->children}) {
        $sth->execute($node->left_index, $node->right_index, $node->node_id);
    }
    my $leafcount = scalar(@{$clusterset->root->get_all_leaves});
    print STDERR "clusterset ", $clusterset->root_id, " / ", $clusterset->clusterset_id, " with $leafcount leaves\n" if $self->debug;
    $clusterset->root->print_tree if $self->debug;
}


1;
