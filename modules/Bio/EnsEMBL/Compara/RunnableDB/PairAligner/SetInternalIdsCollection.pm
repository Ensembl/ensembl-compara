=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsCollection

=head1 DESCRIPTION

This module rewrite the genomic_align(_block) entries so that the dbIDs are in the range of method_link_species_set_id * 10**10

=head1 CONTACT

Post questions to the Ensembl development list: http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsCollection;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'mlss_padding_n_zeros' => 10.
    }
}

sub fetch_input {
    my $self = shift;

    my $mlss_id = $self->param_required('method_link_species_set_id');
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    $self->param('is_pairwise_aln', $mlss->method->class eq 'GenomicAlignBlock.pairwise_alignment' ? 1 : 0);
}



sub run {
    my $self = shift;

    return if ($self->param('skip'));

    $self->_setInternalIds();
}



sub _setInternalIds {
    my $self = shift;

    my $mlss_id = $self->param('method_link_species_set_id');
    my $magic_number = '1'.('0' x $self->param('mlss_padding_n_zeros'));

    # Write new blocks in the correct range
    my $sql0 = "SELECT MIN(genomic_align_id % $magic_number), MIN(genomic_align_block_id % $magic_number), COUNT(*), COUNT(DISTINCT genomic_align_id % $magic_number), COUNT(DISTINCT genomic_align_block_id % $magic_number) FROM genomic_align WHERE (FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id OR FLOOR(genomic_align_id / $magic_number) != method_link_species_set_id) AND method_link_species_set_id = ?";
    my $sql1 = "INSERT INTO genomic_align_block SELECT (genomic_align_block_id % $magic_number) + ?, method_link_species_set_id, score , perc_id, length , group_id , level_id FROM genomic_align_block WHERE FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id AND method_link_species_set_id = ?";
    # Update the dbIDs in genomic_align
    my $sql2 = "UPDATE genomic_align SET genomic_align_block_id = ? + (genomic_align_block_id % $magic_number), genomic_align_id = ? + (genomic_align_id % $magic_number) WHERE (FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id OR FLOOR(genomic_align_id / $magic_number) != method_link_species_set_id) AND method_link_species_set_id = ?";
    # Update the dbIDs in conservation_score
    my $sql2cs = "UPDATE conservation_score SET genomic_align_block_id = ? + (genomic_align_block_id % $magic_number)";
    # Remove the old blocks
    my $sql3 = "DELETE FROM genomic_align_block WHERE FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id AND method_link_species_set_id = ?";

    # We really need a transaction to ensure we're not screwing the database
    my $dbc = $self->compara_dba->dbc;
    $self->call_within_transaction(sub {
            my ($min_ga, $min_gab, $tot_count, $safe_ga_count, $safe_gab_count) = $dbc->db_handle->selectrow_array($sql0, undef, $mlss_id);
            if (not defined $min_ga) {
                $self->warning("Entries for mlss_id=$mlss_id are already in the correct range. Nothing to do");
                return;
            };
            if (($tot_count != $safe_ga_count) or ($self->param('is_pairwise_aln') && ($tot_count != 2*$safe_gab_count))) {
                my $msg = "genomic_align_id or genomic_align_block_id remainders are not unique. Need a more advanced mapping method";
                $self->complete_early_if_branch_connected($msg, 2);
                die "$msg but none connected on branch #2";
            }
            my $offset_ga = $mlss_id * $magic_number + 1 - $min_ga;
            my $offset_gab = $mlss_id * $magic_number + 1 - $min_gab;
            print STDERR "Offsets: genomic_align_block_id=$offset_gab genomic_align_id=$offset_ga\n";
            print STDERR (my $nd = $dbc->do($sql1, undef, $offset_gab, $mlss_id)), " rows duplicated in genomic_align_block\n";
            print STDERR $dbc->do($sql2, undef, $offset_gab, $offset_ga, $mlss_id), " rows of genomic_align redirected to the new entries in genomic_align_block \n";
            print STDERR $dbc->do($sql2cs, undef, $offset_gab), " rows of conservation_score redirected to the new entries in genomic_align_block \n";
            print STDERR (my $nr = $dbc->do($sql3, undef, $mlss_id)), " rows removed from genomic_align_block\n";
            die "Numbers mismatch: $nd rows duplicated and $nr removed\n" if $nd != $nr;
        }
    );

    ## Let's now fix the node_ids
    my $sql4 = "SELECT MIN(root_id), COUNT(*) FROM genomic_align_tree JOIN genomic_align USING (node_id) WHERE FLOOR(node_id / $magic_number) != method_link_species_set_id AND method_link_species_set_id = ?";
    my $sql5 = "INSERT INTO genomic_align_tree SELECT node_id + ?, IF(parent_id = NULL, NULL, parent_id + ?), root_id + ?, left_index, right_index, IF(left_node_id = NULL, NULL, left_node_id + ?), IF(right_node_id = NULL, NULL, right_node_id + ?), distance_to_parent FROM genomic_align_tree WHERE root_id = ? ORDER BY left_index";
    # Update node_id in genomic_align
    my $sql6 = "UPDATE genomic_align JOIN genomic_align_tree USING (node_id) SET genomic_align.node_id = genomic_align.node_id + ? WHERE root_id = ?";
    # Get the list of all the trees ...
    my $sql7 = "SELECT DISTINCT root_id FROM genomic_align JOIN genomic_align_tree USING (node_id) WHERE method_link_species_set_id = ?";
    # ... to be able to remove them later
    my $sql8 = "DELETE FROM genomic_align_tree WHERE root_id = ?";

    $self->call_within_transaction(sub {
        my ($min_gat, $tot_count) = $dbc->db_handle->selectrow_array($sql4, undef, $mlss_id);
        if (not defined $min_gat) {
            $self->warning("Entries for mlss_id=$mlss_id are already in the correct range. Nothing to do");
            return;
        };
        my $offset_gat = $mlss_id * $magic_number + 1 - $min_gat;
        print STDERR "Offsets: genomic_align_tree.node_id=$offset_gat\n";
        my $all_root_ids = $dbc->db_handle->selectcol_arrayref($sql7, undef, $mlss_id);
        print STDERR scalar(@$all_root_ids)." trees to reindex\n";
        my $nd = 0;
        my $nt = 0;
        my $nr = 0;
        foreach my $root_id (@$all_root_ids) {
            $nd += $dbc->do($sql5, undef, $offset_gat, $offset_gat, $offset_gat, $offset_gat, $offset_gat, $root_id);
            $nt += $dbc->do($sql6, undef, $offset_gat, $root_id);
            $nr += $dbc->do($sql8, undef, $root_id);
        }
        print STDERR "$nd rows duplicated in genomic_align_tree\n";
        print STDERR "$nt rows of genomic_align redirected to the new entries in genomic_align_tree \n";
        print STDERR "$nr rows removed from genomic_align_tree\n";
        die "Numbers mismatch: $nd rows duplicated and $nr removed\n" if $nd != $nr;
    } );
}

1;
