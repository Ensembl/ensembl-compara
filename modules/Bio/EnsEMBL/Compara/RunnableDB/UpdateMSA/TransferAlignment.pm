=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::TransferAlignment

=head1 DESCRIPTION

Transfers the genomic align, genomic align block and genomic align tree entries
from the previous alignment MLSS to the current one. If the MLSS ids correspond
to an EPO MSA, the ancestral dnafrags are also transferred, updating both their
dnafrag id and name.

=over

=item method_type

Mandatory. Method type of the given MLSS ids.

=item mlss_id

Mandatory. Current release alignment's MLSS id.

=item prev_mlss_id

Mandatory. Previous release alignment's MLSS id.

=back

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::TransferAlignment \
        -compara_db $(mysql-ens-compara-prod-9-ensadmin details url jalvarez_amniotes_pecan_update_101) \
        -method_type pecan -mlss_id 1897 -prev_mlss_id 1831

=cut

package Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::TransferAlignment;

use warnings;
use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Hive::Utils;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;
    my $method_type = $self->param_required('method_type');
    my $prev_mlss_id = $self->param_required('prev_mlss_id');
    my $curr_mlss_id = $self->param_required('mlss_id');
    my $dba = $self->compara_dba;
    # Calculate the id diff to sum to every id column based on the difference between both MLSS ids
    my $id_diff = ($curr_mlss_id - $prev_mlss_id) * 10**10;
    # Get the id range to pick the right nodes in genomic_align_tree table
    my $min_id = $prev_mlss_id * 10**10;
    my $max_id = $min_id + 10**10;
    # Do all the updates in a single transaction to make sure the database is consistent if something fails
    $dba->dbc->sql_helper->transaction(-CALLBACK => sub {
        # Disable foreign key constraints
        $dba->dbc->do("SET FOREIGN_KEY_CHECKS=0");
        # Update main id columns in genomic_align table
        $dba->dbc->do("UPDATE genomic_align SET genomic_align_id = genomic_align_id + $id_diff,
            genomic_align_block_id = genomic_align_block_id + $id_diff,
            method_link_species_set_id = $curr_mlss_id, node_id = node_id + $id_diff
            WHERE method_link_species_set_id = $prev_mlss_id");
        # Update main id columns in genomic_align_block table
        $dba->dbc->do("UPDATE genomic_align_block SET genomic_align_block_id = genomic_align_block_id + $id_diff,
            method_link_species_set_id = $curr_mlss_id, group_id = group_id + $id_diff
            WHERE method_link_species_set_id = $prev_mlss_id");
        # Update all id columns in genomic_align_tree table
        $dba->dbc->do("UPDATE genomic_align_tree SET node_id = node_id + $id_diff,
            parent_id = parent_id + $id_diff, root_id = root_id + $id_diff,
            left_node_id = left_node_id + $id_diff, right_node_id = right_node_id + $id_diff
            WHERE node_id BETWEEN $min_id AND $max_id");
        # If it is an EPO MSA, transfer the ancestral dnafrags to the new MLSS id
        if ( $method_type =~ /^EPO$/i ) {
            $dba->dbc->do("UPDATE dnafrag df JOIN genomic_align ga USING (dnafrag_id)
                SET df.dnafrag_id = df.dnafrag_id + $id_diff, ga.dnafrag_id = ga.dnafrag_id + $id_diff,
                df.name = REPLACE(df.name, '_${prev_mlss_id}_', '_${curr_mlss_id}_')
                WHERE df.name LIKE 'Ancestor_${prev_mlss_id}_%'");
        }
        # The work is done, re-enable foreign key constraints
        $dba->dbc->do("SET FOREIGN_KEY_CHECKS=1");
    });
}


1;
