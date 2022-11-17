=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::DeleteOldMember

=head1 SYNOPSIS

This runnable will delete references to a member that doesn't exist any more.
It is expected to work in conjunction with an analysis that deletes the trees
and their alignments and homologies, as it will not clean up these tables.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::DeleteOldMember;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift @_;

    my $dbc = $self->compara_dba->dbc;

    # Get the root_ids of the trees that need to be deleted
    my $sql_tree = 'SELECT root_id FROM gene_tree_node JOIN gene_tree_root USING (root_id) WHERE ref_root_id IS NULL AND seq_member_id = ?';
    my $tree_ids = $dbc->sql_helper->execute_simple( -SQL => $sql_tree, -PARAMS => [$self->param('seq_member_id')] );

    # Get the gene_align_ids of this member that cannot be found by GeneTreeAdaptor::delete_tree
    my $sql_aligns = 'SELECT DISTINCT gam.gene_align_id
                      FROM gene_align_member gam
                           LEFT JOIN gene_tree_root gtr USING (gene_align_id)
                           LEFT JOIN gene_tree_root_attr gtra ON mcoffee_scores_gene_align_id = gam.gene_align_id
                           LEFT JOIN gene_tree_root_tag gtrt ON tag = "filtered_gene_align_id" AND value = gam.gene_align_id
                      WHERE gtr.root_id IS NULL
                            AND gtra.root_id IS NULL
                            AND gtrt.root_id IS NULL
                            AND seq_member_id = ?';
    my $gene_align_ids = $dbc->sql_helper->execute_simple( -SQL => $sql_aligns, -PARAMS => [$self->param('seq_member_id')] );

    # We clean up all tables but gene_tree*, gene_align*, homology* since
    # the "delete_tree" analysis will deal with those
    $self->call_within_transaction( sub {
            foreach my $gene_align_id (@$gene_align_ids) {
                $dbc->do('DELETE FROM gene_align_member WHERE gene_align_id = ?', undef, $gene_align_id);
                $dbc->do('DELETE FROM gene_align        WHERE gene_align_id = ?', undef, $gene_align_id);
            }

            # remove from supertree alignments - we clean the supertree itself in "delete_tree" analysis
            $dbc->do('DELETE m FROM gene_align_member m JOIN gene_tree_root r USING(gene_align_id)
                      WHERE r.tree_type = "supertree" AND m.seq_member_id = ?;', undef, $self->param('seq_member_id'));

            $dbc->do('DELETE FROM gene_member_qc                  WHERE gene_member_id = ?',        undef, $self->param('gene_member_id'));
            $dbc->do('DELETE FROM member_xref                     WHERE gene_member_id = ?',        undef, $self->param('gene_member_id'));
            $dbc->do('DELETE FROM gene_member_hom_stats           WHERE gene_member_id = ?',        undef, $self->param('gene_member_id'));
            $dbc->do('DELETE FROM seq_member_projection_stable_id WHERE target_seq_member_id = ?',  undef, $self->param('seq_member_id'));
            $dbc->do('DELETE FROM seq_member_projection           WHERE source_seq_member_id = ?',  undef, $self->param('seq_member_id'));
            $dbc->do('DELETE FROM seq_member_projection           WHERE target_seq_member_id = ?',  undef, $self->param('seq_member_id'));
            $dbc->do('DELETE FROM hmm_annot                       WHERE seq_member_id = ?',         undef, $self->param('seq_member_id'));
    } );

    $self->dataflow_output_id( { 'gene_tree_id' => $_, }, 2) for @$tree_ids;
}

1;
