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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput

=head1 DESCRIPTION

This is the RunnableDB that parses the output of Hcluster, stores the clusters as trees without internal structure
(each tree will have one root and several leaves) and dataflows the cluster_ids down branch #2.

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HclusterParseOutput');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput(
                         -input_id   => "{'mlss_id'=>40069}",
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput;

use strict;

use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::GeneTreeNode;
use Bio::EnsEMBL::Compara::GeneTreeMember;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');



sub run {
    my $self = shift @_;

    $self->parse_hclusteroutput;
}


sub write_output {
    my $self = shift @_;

    $self->dataflow_clusters;
}


##########################################
#
# internal methods
#
##########################################

sub parse_hclusteroutput {
    my $self = shift;

    my $mlss_id = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";

    my $protein_tree_adaptor = $self->compara_dba->get_ProteinTreeAdaptor;

    my $cluster_dir   = $self->param('cluster_dir');
    my $filename      = $cluster_dir . '/hcluster.out';

    # Create the clusterset and associate mlss
    my $clusterset = new Bio::EnsEMBL::Compara::GeneTree;
    $clusterset->tree_type('proteinclusterset');
    $clusterset->method_link_species_set_id($mlss_id);
    $self->param('clusterset', $clusterset);

    my $clusterset_root = new Bio::EnsEMBL::Compara::GeneTreeNode;
    $clusterset->root($clusterset_root);
    $protein_tree_adaptor->store($clusterset);

    my @allclusters;
    my @allcluster_ids;
    $self->param('allcluster_ids', \@allcluster_ids);

    # FIXME: load the entire file in a hash and store in decreasing
    # order by cluster size this will make big clusters go first in the
    # alignment process, which makes sense since they are going to take
    # longer to process anyway
    open(FILE, $filename) or die "Could not open '$filename' for reading : $!";
    while (<FILE>) {
        # 0       0       0       1.000   2       1       697136_68,
        # 1       0       39      1.000   3       5       1213317_31,1135561_22,288182_42,426893_62,941130_38,
        chomp $_;

        my ($cluster_id, $dummy1, $dummy2, $dummy3, $dummy4, $dummy5, $cluster_list) = split("\t",$_);

        next if ($dummy5 < 2);
        $cluster_list =~ s/\,$//;
        $cluster_list =~ s/_[0-9]*//g;
        my @cluster_list = split(",",$cluster_list);

        # If it's a singleton, we don't store it as a protein tree
        next if (2 > scalar(@cluster_list));
        push @allclusters, \@cluster_list;
    }
    close FILE;

    # load the entire file in a hash and store in decreasing order by cluster
    # size this will make big clusters go first in the alignment process,
    # which makes sense since they are going to take longer to process anyway
    foreach my $cluster_list (sort {scalar(@$b) <=> scalar(@$a)} @allclusters) {
        my $clusterset_leaf = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $clusterset_leaf->no_autoload_children();
        $clusterset_root->add_child($clusterset_leaf);

        my $cluster = new Bio::EnsEMBL::Compara::GeneTree;
        $cluster->tree_type('proteintree');
        $cluster->method_link_species_set_id($mlss_id);

        my $cluster_root = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $cluster->root($cluster_root);
        $cluster->clusterset_id($clusterset_root->node_id);
        $cluster_root->tree($cluster);
        $clusterset_leaf->add_child($cluster_root);

        foreach my $member_id (@$cluster_list) {
            my $node = new Bio::EnsEMBL::Compara::GeneTreeMember;
            $cluster_root->add_child($node);
            $node->member_id($member_id);
        }

        # Store the cluster:
        $protein_tree_adaptor->store($clusterset_leaf);
        push @allcluster_ids, $cluster->root_id;

        my $leafcount = scalar(@{$cluster->root->get_all_leaves});
        print STDERR "cluster $cluster with $leafcount leaves\n" if $self->debug;
        $cluster->store_tag('gene_count', $leafcount);
        $cluster_root->disavow_parent();
        $cluster_root->release_tree();

    }
    $clusterset_root->build_leftright_indexing(1);
    $protein_tree_adaptor->store($clusterset);
    $self->param('clusterset_id', $clusterset_root->node_id);
    my $leafcount = scalar(@{$clusterset->root->get_all_leaves});
    print STDERR "clusterset $clusterset with $leafcount leaves\n" if $self->debug;

}


sub dataflow_clusters {
    my $self = shift;

    foreach my $tree_id (@{$self->param('allcluster_ids')}) {
        $self->dataflow_output_id({ 'protein_tree_id' => $tree_id, }, 2);
    }
    $self->input_job->autoflow(0);
    $self->dataflow_output_id({ 'clusterset_id' => $self->param('clusterset_id') }, 1);
}

1;
