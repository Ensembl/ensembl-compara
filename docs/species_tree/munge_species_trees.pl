# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 USAGE

Usage: munge_species_trees.pl ref_tree.nw tree_with_bl1.nw tree_with_bl2.nw tree_with_bl3.nw

The script will replace subtrees of the reference tree with the other trees passed as arguments.
The distances of the reference tree are reset to .1, and then overridden by the other trees.
The topologies are supposed to be exactly the same.

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Graph::NewickParser;

die "You should run this script with a reference-topology tree, followed by trees with estimated branch-lengths for some clades\n" if scalar(@ARGV) < 2;
my @parsed_trees = map {Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree(qx" cat $_")} @ARGV;
my $topology_tree = shift @parsed_trees;

# Assign the default branch length everywhere
my $default_branch_length = .1;
map {$_->distance_to_parent($default_branch_length)} ($topology_tree->get_all_subnodes);

## Puts $new_subtree into $ini_tree
sub replace_subtree {
    my ($ini_tree, $new_subtree) = @_;

    # $l1 and $l2 are two leaves of $new_subtree whose LCA is the root of $new_subtree
    my $l1 = $new_subtree->children->[0]->get_all_leaves->[0];
    my $l2 = $new_subtree->children->[1]->get_all_leaves->[0];
    my $ini_l1 = $ini_tree->find_leaf_by_name($l1->name) || die sprintf("Cannot find '%s' in the reference tree\n", $l1->name);
    my $ini_l2 = $ini_tree->find_leaf_by_name($l2->name) || die sprintf("Cannot find '%s' in the reference tree\n", $l2->name);
    # Their LCA in $ini_tree points to the node we should replace
    my $insertion_point = $ini_tree->find_first_shared_ancestor_from_leaves([$ini_l1, $ini_l2]);

    # Warning: sub_tree may contain an outgroup species ! (mouse for fish, opossum for sauropsids)
    # If it is the case, we remove the outgroup and rerun the procedure
    if (scalar(@{$insertion_point->get_all_leaves}) != scalar(@{$new_subtree->get_all_leaves})) {
        if ((not $new_subtree->children->[0]->is_leaf) and not ($new_subtree->children->[1]->is_leaf )) {
            die sprintf("The number of species don't match (subtree linking '%s' and '%s') and there is no clear outgroup species\n", $l1->name, $l2->name);
        }
        warn sprintf("Found that '%s' was used as an outgroup. Removing it\n", $new_subtree->children->[0]->is_leaf ? $new_subtree->children->[0]->name : $new_subtree->children->[1]->name);
        my $real_subtree = $new_subtree->children->[0]->is_leaf ? $new_subtree->children->[1] : $new_subtree->children->[0];
        return replace_subtree($ini_tree, $real_subtree);
    }

    # NestedSet magic
    $insertion_point->parent->add_child($new_subtree);
    $insertion_point->release_tree;
    $new_subtree->distance_to_parent($default_branch_length);
}

map {replace_subtree($topology_tree, $_)} @parsed_trees;

# It used to be log(1.2+d) for internal branches, and log(1.6+d) for terminal branches
# Now we add 0.1 to internal branches and 0.2 to leaves. No logarithm !
my $log_extra_addition_terminal_leaves = .1;
my $log_addition_all_nodes = .1;
#map {$_->distance_to_parent($_->distance_to_parent + $log_addition_all_nodes)} ($topology_tree->get_all_subnodes);
#map {$_->distance_to_parent($_->distance_to_parent + $log_extra_addition_terminal_leaves)} @{$topology_tree->get_all_leaves};
#map {$_->distance_to_parent(log($_->distance_to_parent))} ($topology_tree->get_all_subnodes);

#map {$_->distance_to_parent(1)} ($topology_tree->get_all_subnodes);

print $topology_tree->newick_format('simple'), "\n";

