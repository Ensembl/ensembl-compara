=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input.

This must already have a multiple alignment run on it. It uses that
alignment as input into the QuickTree program which then generates a
simple phylogenetic tree to be broken down into 2 pieces.

Google QuickTree to get the latest tar.gz from the Sanger.

input_id/parameters format eg: "{'gene_tree_id'=>1234,'clusterset_id'=>1}"
    gene_tree_id : use 'id' to fetch a cluster from the ProteinTree

This module was previously in Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::QuickTreeBreak
so look at the history of that file in case you want to access previous versions of the file.

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $quicktreebreak = Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$quicktreebreak->fetch_input(); #reads from DB
$quicktreebreak->run();
$quicktreebreak->write_output(); #writes to DB

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

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak;

use strict;
use IO::File;
use File::Basename;

use Bio::AlignIO;

use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::GeneTreeNode;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree', 'Bio::EnsEMBL::Compara::RunnableDB::RunCommand');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
    my $self = shift @_;

    my $gene_tree_id = $self->param_required('gene_tree_id');
    my $gene_tree    = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($gene_tree_id) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";
    $self->param('gene_tree', $gene_tree);

    # We reload the cigar lines in case the subtrees are partially written
    $self->param('cigar_lines', $self->compara_dba->get_AlignedMemberAdaptor->fetch_all_by_gene_align_id($gene_tree->gene_align_id));

    my $exe = $self->param_required('quicktree_exe');
    die "Cannot execute '$exe'" unless (-x $exe);

    ## 'tags_to_copy' can also be set
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs NJTREE PHYML
    Returns :   none
    Args    :   none

=cut


sub run {
    my $self = shift @_;

    my $supertree = $self->param('gene_tree');;
    $supertree->tree_type('supertree');

    my $tree = new Bio::EnsEMBL::Compara::GeneTree(
            -tree_type => 'tree',
            -member_type => $supertree->member_type,
            -method_link_species_set_id => $supertree->method_link_species_set_id,
            -clusterset_id => $supertree->clusterset_id,
            );

    my %cigars;
    foreach my $member (@{$self->param('cigar_lines')}) {
        $cigars{$member->member_id} = $member->cigar_line;
    }
    print STDERR scalar(keys %cigars), " cigars loaded\n" if $self->debug;

    foreach my $member (@{$supertree->get_all_Members}) {
        $tree->add_Member($member);
        $member->cigar_line($cigars{$member->member_id});
    }
    print STDERR scalar(@{$supertree->get_all_Members}), " members found in the super-tree\n" if $self->debug;

    # Nodes from a previous QTB run
    # They are in reverse order to make sure we delete the roots at the end
    print STDERR $supertree->root->string_tree if $self->debug;
    my @nodes_to_delete = reverse($supertree->root->get_all_subnodes);;
    $self->param('nodes_to_delete', \@nodes_to_delete);
    print STDERR "found ", scalar(@nodes_to_delete), " to delete\n";

    $supertree->root->release_children;
    $supertree->clear();
    $supertree->root->add_child($tree->root);

    print "ini_root: ", $supertree->root, "\n";
    print "tree_root: ", $tree->root, "\n";

    $self->do_quicktree_loop($supertree->root);
    print_supertree($supertree->root, "");
}

sub print_supertree {
    my $node = shift;
    my $indent = shift;
    print $indent; $node->print_node;
    if ($node->tree->tree_type eq 'tree') {
        print $indent, "TREE: ", scalar(@{$node->get_all_leaves}), "\n";
    } else {
        print $indent, "SUPERTREE\n";
        $indent .= "\t";
        foreach my $child (@{$node->children}) {
            print_supertree($child, $indent);
        }
    }
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores tree
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my $self = shift @_;

    $self->compara_dba->get_GeneTreeAdaptor->store($self->param('gene_tree'));

    my $dbc = $self->compara_dba->dbc;
    foreach my $node (@{$self->param('nodes_to_delete')}) {
        if ($node->node_id == $node->{_root_id}) {
            my $root_id = $node->{_root_id};
            $dbc->do("DELETE FROM gene_tree_root_tag WHERE root_id = $root_id");
            $dbc->do("DELETE FROM gene_tree_root     WHERE root_id = $root_id");
        }
        $self->compara_dba->get_GeneTreeNodeAdaptor->delete_node($node);
    }

    $self->rec_update_tags($self->param('gene_tree')->root);
}


sub post_cleanup {
    my $self = shift;

    printf("QuickTreeBreak::post_cleanup releasing trees\n") if($self->debug);

    $self->param('gene_tree')->release_tree;

    $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
}


##########################################
#
# internal methods
#
##########################################


sub do_quicktree_loop {
    my $self = shift;
    my $supertree_root = shift;
    my $input_aln = $self->dumpAlignedMemberSetAsStockholm($supertree_root->children->[0]);
    my $quicktree_newick_string = $self->run_quicktreebreak($input_aln);
    my $newtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($quicktree_newick_string);
    my @todo = ();
    push @todo, [$newtree, $supertree_root];
    while (scalar(@todo)) {
        my $args = shift @todo;
        my $res = $self->generate_subtrees(@$args);
        foreach my $node_cluster (@$res) {
            if (defined $self->param('treebreak_gene_count') and (scalar(@{$node_cluster->[1]->get_all_leaves}) >= $self->param('treebreak_gene_count'))) {
                push @todo, $node_cluster;
            } else {
                $node_cluster->[0]->release_tree;
            }
        }
    }
    $self->rec_update_indexing($supertree_root);
}


sub run_quicktreebreak {
    my $self = shift;
    my $input_aln = shift;

    my $cmd = sprintf('%s -out t -in a %s', $self->param('quicktree_exe'), $input_aln);
    my $cmd_out = $self->run_command($cmd);
    return $cmd_out->out;
}



########################################################
#
# Tree input/output section
#
########################################################

sub rec_update_indexing {
    my $self = shift;
    my $node = shift;
    my $index = shift;

    if ($node->tree->tree_type eq 'supertree') {
        $node->left_index($index);
        $index++;
        foreach my $child (@{$node->children}) {
            $index = $self->rec_update_indexing($child, $index);
        }
        $node->right_index($index);
        $index++;
    }
    return $index;
}


sub rec_update_tags {
    my $self = shift;
    my $node = shift;

    if ($node->tree->tree_type eq 'tree') {
        my $cluster = $node->tree;
        my $node_id = $cluster->root_id;

        my $leafcount = scalar(@{$cluster->root->get_all_leaves});
        $cluster->store_tag('gene_count', $leafcount);
        print STDERR "Stored $node_id with $leafcount leaves\n" if ($self->debug);

        #We replicate needed tags into the children
        if (defined $self->param('tags_to_copy')) {
            my @tags = @{$self->param('tags_to_copy')};
            for my $tag (@tags) {
                print STDERR "Stored tag $tag in $node_id\n" if ($self->debug);
                my $value = $self->param('gene_tree')->get_tagvalue($tag);
                $self->throw("$tag tag not found in " . $self->param('gene_tree')->root_id) unless (defined $value);
                $cluster->store_tag($tag, $value);
            }
        }

    } else {
        $node->store_tag('tree_support', 'quicktree');
        $node->store_tag('node_type', 'speciation');
        foreach my $child (@{$node->children}) {
            $self->rec_update_tags($child);
        }
    }

}


sub generate_subtrees {
    my $self                    = shift @_;
    my $newtree                 = shift @_;
    my $attach_node             = shift @_;

    my $supertree = $attach_node->tree;
    my $members = $attach_node->get_all_leaves;

    # Break the tree by immediate children recursively
    my @children;
    my $keep_breaking = 1;
    my $max_subtree = $newtree;
    my $half_count = int(scalar(@{$members})/2);
    while ($keep_breaking) {
        @children = @{$max_subtree->children};
        my $max_num_leaves = 0;
        foreach my $child (@children) {
            my $num_leaves = scalar(@{$child->get_all_leaves});
            if ($num_leaves > $max_num_leaves) {
                $max_num_leaves = $num_leaves;
                $max_subtree = $child;
            }
        }
        # Broke down to half, happy with it
        print STDERR "QuickTreeBreak iterate -- $max_num_leaves (goal: $half_count)\n"; # if ($self->debug);
        if ($max_num_leaves <= $half_count) {
            $keep_breaking = 0;
        }
    }

    my $supertree_leaf1 = new Bio::EnsEMBL::Compara::GeneTreeNode;
    my $cluster1 = new Bio::EnsEMBL::Compara::GeneTree(
            -tree_type => 'tree',
            -member_type => $supertree->member_type,
            -method_link_species_set_id => $supertree->method_link_species_set_id,
            -clusterset_id => $supertree->clusterset_id,
            );

    my $supertree_leaf2 = new Bio::EnsEMBL::Compara::GeneTreeNode;
    my $cluster2 = new Bio::EnsEMBL::Compara::GeneTree(
            -tree_type => 'tree',
            -member_type => $supertree->member_type,
            -method_link_species_set_id => $supertree->method_link_species_set_id,
            -clusterset_id => $supertree->clusterset_id,
            );

    my %in_cluster1;
    foreach my $leaf (@{$max_subtree->get_all_leaves}) {
        $in_cluster1{$leaf->name} = 1;
    }

    foreach my $leaf (@{$members}) {
        if (defined $in_cluster1{$leaf->member_id}) {
            $cluster1->add_Member($leaf);
        } else {
            $cluster2->add_Member($leaf);
        }
    }

    print "supertree_leaf1: $supertree_leaf1\n";
    print "cluster1_root: ", $cluster1->root, "\n";
    print "supertree_leaf2: $supertree_leaf2\n";
    print "cluster2_root: ", $cluster2->root, "\n";

    $attach_node->release_children;
    print "attach node: "; $attach_node->print_node;
    
    $supertree_leaf1->add_child($cluster1->root);
    $supertree_leaf1->tree($supertree);
    $attach_node->add_child($supertree_leaf1, $max_subtree->distance_to_parent/2);
    
    $supertree_leaf2->add_child($cluster2->root);
    $supertree_leaf2->tree($supertree);
    $attach_node->add_child($supertree_leaf2, $max_subtree->distance_to_parent/2);

    $max_subtree->disavow_parent;

    return [[$max_subtree, $supertree_leaf1], [$newtree, $supertree_leaf2]];
}

1;
