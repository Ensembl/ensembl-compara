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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SuperTreeMerge

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take GeneTree as input

This must already have a rooted tree with duplication/sepeciation tags
on the nodes.

It analyzes that tree structure to pick Orthologues and Paralogs for
each genepair.

input_id/parameters format eg: "{'tree_id'=>1234}"
    tree_id : use 'id' to fetch a cluster from the GeneTree

=head1 SYNOPSIS

my $db    = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $otree = Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id,
                                                    -analysis   => $analysis );
$otree->fetch_input(); #reads from DB
$otree->run();
$otree->output();
$otree->write_output(); #writes to DB

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

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SuperTreeMerge;

use strict;

use Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree;

use Bio::EnsEMBL::Hive::Utils 'stringify';  # import 'stringify()'

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');



sub fetch_input {
    my $self = shift @_;

    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    $self->param('tree_id_str') or die "tree_id_str is an obligatory parameter";
    my $tree_id = $self->param($self->param('tree_id_str')) or die "'*_tree_id' is an obligatory parameter";
    my $tree = $self->param('tree_adaptor')->fetch_node_by_node_id($tree_id) or die "Could not fetch tree with tree_id='$tree_id'";
    $self->param('tree', $tree);

}


sub run {
    my $self = shift @_;
    my $tree = $self->param('tree');
    my @nodes_todelete;
    my @trees_todelete;

    # Merge consecutive nodes
    foreach my $leaf (@{$self->param('tree_adaptor')->fetch_all_leaves_indexed($tree)}) {
        if ($leaf->get_child_count == 0) {

            # Adds the true leaves
            $tree->add_child($leaf);

        } elsif ($leaf->get_child_count == 1) {
            my $subtree = $leaf->children->[0];
            if ($subtree->tree->tree_type eq 'tree') {

                # Keeps the super-tree leaf
                $tree->add_child($leaf, $leaf->distance_to_parent);
                $subtree->disavow_parent();
            } else {

                # Adds the full subtree
                push @nodes_todelete, $leaf;
                print "will have to delete node_id=", $leaf->node_id, "\n";
                push @trees_todelete, $subtree->tree;
                print "will have to delete root_id=", $subtree->node_id, "\n";
                $tree->add_child($tree->adaptor->fetch_subtree_under_node($subtree), $leaf->distance_to_parent);
                foreach my $node (@{$subtree->get_all_nodes}) {
                    $node->tree($tree->tree);
                }

            }
        } else {
            die "should not happen\n";
        }
    }

    $tree->build_leftright_indexing;
    $tree->print_tree;
    $self->print($tree);

    $tree->add_tag('tree_support', 'quicktree');
    # This node_type is probably wrong, but it will be fixed later by OtherParalogs
    $tree->add_tag('node_type', 'speciation');

    $self->param('trees_todelete', \@trees_todelete);
    $self->param('nodes_todelete', \@nodes_todelete);

}

sub print {
    my $self = shift @_;
    my $node = shift @_;
    my $indent = shift;
    print $indent, " ", $node, " ", $node->node_id, " ", $node->tree, " ", $node->tree->root_id, "\n";
    foreach my $child (@{$node->children}) {
        $self->print($child, "$indent\t");
    }

}

sub write_output {
    my $self = shift @_;
    my $tree = $self->param('tree');
    my $tree_adaptor = $self->param('tree_adaptor');

    if (scalar(@{$self->param('nodes_todelete')})) {
        $tree_adaptor->store($tree);
        foreach my $node (@{$self->param('nodes_todelete')}) {
            $tree_adaptor->delete_node($node);
        }
        foreach my $root (@{$self->param('trees_todelete')}) {
            my $old_root_id = $root->root_id;
            my $new_root_id = $tree->node_id;
            $self->compara_dba->dbc->do("UPDATE homology SET tree_node_id=$new_root_id WHERE tree_node_id=$old_root_id");
            $self->compara_dba->dbc->do("DELETE FROM gene_tree_root_tag WHERE root_id=$old_root_id");
            $self->compara_dba->dbc->do("DELETE FROM gene_tree_root WHERE root_id=$old_root_id");
        }
    }
    $tree_adaptor->sync_tags_to_database($tree);
}

1;
