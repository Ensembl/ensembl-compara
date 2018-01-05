
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

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_EPA_lb;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'cmd'                        => '#raxml_exe# #extra_raxml_args# -m #best_fit_model# -p 99123746531 -r #gene_tree_file# -s #alignment_file# -n #gene_tree_id#;',
        'runtime_tree_tag'           => 'raxml_epa_runtime',
        'remove_columns'             => 0,
        'cdna'                       => 1,
        'branch_cutoff'              => 100,
    };
}

sub get_gene_tree_file {
    my ($self, $gene_tree_root) = @_;

    $self->param('long_branches', 0);
    my $new_root = $self->init_remove_long_subtrees($gene_tree_root);

    unless ($self->param('long_branches')) {
        $self->dataflow_output_id(undef, 4);
        $self->input_job->autoflow(0);
        $self->complete_early("No branches to remove / re-insert.");
    }
    return $self->SUPER::get_gene_tree_file($new_root);
}

sub init_remove_long_subtrees {
    my $self = shift;
    my $root = shift;

    my ($node1, $node2) = @{$root->children};

    my $new1 = $self->rec_remove_long_subtrees($node1);
    my $new2 = $self->rec_remove_long_subtrees($node2);
    if ($new1 and not $new2) {
        $new1->disavow_parent();
        return $new1;
    } elsif ($new2 and not $new1) {
        $new2->disavow_parent();
        return $new2;
    } elsif ($new1 and $new2) {
        return $root;
    } else {
        die "The tree cannot possibly only be composed of long branches !\n";
    }
}


sub do_remove {
    my ($self, $node) = @_;
    $node->disavow_parent;
    $node->print_tree(1e-5);
    foreach my $leaf (@{$node->get_all_leaves}) {
        push @{$self->param('hidden_genes')}, $leaf;
        printf("Removing seq_member_id=%d\n", $leaf->seq_member_id);
    }
    $node->release_tree;
}

sub rec_remove_long_subtrees {
    my ($self, $node) = @_;

    if ($self->are_all_sub_branches_long($node)) {
        $self->do_remove($node);
        return undef;
    }

    if (not $node->is_leaf) {
        my ($node1,$node2) = @{$node->children};
        my $new1 = $self->rec_remove_long_subtrees($node1);
        my $new2 = $self->rec_remove_long_subtrees($node2);
        if ($new1 and not $new2) {
            $node->parent->add_child($new1, $new1->distance_to_parent);
            $node->disavow_parent();
            return $new1;
        } elsif ($new2 and not $new1) {
            $node->parent->add_child($new2, $new2->distance_to_parent);
            $node->disavow_parent();
            return $new2;
        }
    }
    return $node;
}


sub are_all_sub_branches_long {
    my ($self, $node) = @_;
    return 0 if $node->distance_to_parent < $self->param('branch_cutoff');
    $self->param('long_branches', 1);
    return 1 if $node->is_leaf;
    return 0 if not $self->are_all_sub_branches_long($node->children->[0]);
    return 0 if not $self->are_all_sub_branches_long($node->children->[1]);
    return 1;
}

1;
