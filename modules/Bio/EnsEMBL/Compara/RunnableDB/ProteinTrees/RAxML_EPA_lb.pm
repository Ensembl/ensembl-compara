
=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_EPA_lb;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'cmd'                        => '#raxml_exe# #raxml_extra_params# -f v -G .10 -m #best_fit_model# -p 99123746531 -t #gene_tree_file# -s #alignment_file# -n #gene_tree_id#',
        'raxml_extra_params'         => '',
        'runtime_tree_tag'           => 'raxml_epa_runtime',
        'remove_columns'             => 0,
        'cdna'                       => 1,
        'output_file'                => 'RAxML_labelledTree.#gene_tree_id#',
        'branch_cutoff'              => 100,
    };
}

sub run {
    my $self = shift;

    $self->param('has_removed_node', 0);
    $self->remove_long_branches;
    if (not $self->param('has_removed_node')) {
        $self->dataflow_output_id($self->input_id, 4);
        $self->input_job->incomplete(0);
        $self->autoflow(0);
        die "No branches to remove / re-insert\n";
    }
    $self->SUPER::run(@_);
}

sub remove_long_branches {
    my $self = shift;
    my $root = $self->param('gene_tree')->root;
    # We need this line to load all the initial members in the alignment
    $self->param('gene_tree')->get_all_Members();
    my ($node1, $node2) = @{$root->children};

    # If both branches are too long, probably one of both sub-trees is
    # entirely too long. We have to prune it and find a new root
    if ($node1->distance_to_parent >= $self->param('branch_cutoff') and $node2->distance_to_parent >= $self->param('branch_cutoff')) {
        my $node;
        if ($self->are_all_sub_branches_long($node1)) {
            $self->do_remove($node1);
            $node = $self->find_first_short_branch($node2);
        } else {
            $self->do_remove($node2);
            $node = $self->find_first_short_branch($node1);
        }
        ($node1, $node2) = @{$node->children};
    }

    $self->rec_remove_long_subtrees($node1);
    $self->rec_remove_long_subtrees($node2);
    $self->param('gene_tree')->{_root} = $root->minimize_tree;
}

sub do_remove {
    my ($self, $node) = @_;
    $node->disavow_parent;
    $node->print_tree(1e-5);
    foreach my $leaf (@{$node->get_all_leaves}) {
        printf("%d\n", $leaf->seq_member_id);
    }
    $node->release_tree;
    $self->param('has_removed_node', 1);
}

sub rec_remove_long_subtrees {
    my ($self, $node) = @_;

    if ($node->distance_to_parent >= $self->param('branch_cutoff')) {
        $self->do_remove($node);

    } elsif (not $node->is_leaf) {
        my ($node1,$node2) = @{$node->children};
        $self->rec_remove_long_subtrees($node1);
        $self->rec_remove_long_subtrees($node2);
    }
}

sub find_first_short_branch {
    my ($self, $node) = @_;
    my ($node1, $node2) = @{$node->children};
    my $long1 = $self->are_all_sub_branches_long($node1);
    my $long2 = $self->are_all_sub_branches_long($node2);
    die "The tree cannot possibly only be composed of long branches !\n" if $long1 and $long2;
    return $node if not $long1 and not $long2;
    if ($long1) {
        $self->do_remove($node2);
        return $self->find_first_short_branch($node1);
    } else {
        $self->do_remove($node1);
        return $self->find_first_short_branch($node2);
    }
}

sub are_all_sub_branches_long {
    my ($self, $node) = @_;
    return 0 if $node->distance_to_parent < $self->param('branch_cutoff');
    return 1 if $node->is_leaf;
    return 0 if not $self->are_all_sub_branches_long($node->children->[0]);
    return 0 if not $self->are_all_sub_branches_long($node->children->[1]);
    return 1;
    my @short_branches = grep {$_->distance_to_parent < $self->param('branch_cutoff')} ($node->get_all_subnodes);
    return scalar(@short_branches) ? 0 : 1;
}

1;
