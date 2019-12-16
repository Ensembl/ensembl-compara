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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LiftComponentAlignments

=head1 DESCRIPTION

Lift the component genomic_aligns and genomic_align_blocks to their
corresponding principal and update the dnafrag_id in the genomic_align table.

=over

=item principal_mlss_id

Mandatory. The MLSS id of the principal PWA.

=item component_mlss_ids

Mandatory. List of component MLSS ids linked to the principal_mlss_id.

=back

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LiftComponentAlignments \
        -compara_db $(mysql-ens-compara-prod-8-ensadmin details url jalvarez_shoots_lastz) \
        -principal_mlss_id 2 -component_mlss_ids [5,6]

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LiftComponentAlignments;

use warnings;
use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;

    return {
        %{$self->SUPER::param_defaults},

        'mlss_padding_n_zeros' => 10,
    }
}


sub run {
    my $self = shift;

    $self->_lift_gas_and_gabs();
    $self->_update_dnafrags();
}


=head2 _lift_gas_and_gabs

Description : Lifts the genomic_aligns and genomic_align_blocks calculated for
              the component genomes to their principal genome. To avoid
              conflicts with foreign keys, it creates the new range of
              genomic_align_blocks based on the principal MLSS id
              (method_link_species_set_id * 10**10) and the previously lifted
              genomic_align_blocks (to avoid collisions), updates the
              genomic_align_block_ids and method_link_species_set_ids (from
              the component MLSS id to the principal MLSS id) in the
              genomic_align table and removes the old genomic_align_blocks.
              Note that the lifting is performed in a transaction manner. This
              function is an adaptation of
              Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsCollection::_setInternalIds()
              (first transaction), so these two methods should be kept in sync.

=cut

sub _lift_gas_and_gabs {
    my $self = shift;
    
    my $principal_mlss_id  = $self->param_required('principal_mlss_id');
    my $component_mlss_ids = $self->param_required('component_mlss_ids');
    my $magic_number       = '1' . ('0' x $self->param('mlss_padding_n_zeros'));

    # Create the principal MLSS genomic_align_blocks in the correct range
    my $sql0 = "SELECT MIN(genomic_align_id % $magic_number), MAX(genomic_align_id % $magic_number), MIN(genomic_align_block_id % $magic_number), MAX(genomic_align_block_id % $magic_number), COUNT(*), COUNT(DISTINCT genomic_align_id % $magic_number), COUNT(DISTINCT genomic_align_block_id % $magic_number) FROM genomic_align WHERE method_link_species_set_id = ?";
    my $sql1 = "INSERT INTO genomic_align_block SELECT (genomic_align_block_id % $magic_number) + ?, ?, score, perc_id, length, group_id, level_id FROM genomic_align_block WHERE method_link_species_set_id = ?";
    # Update the genomic_align_ids and genomic_align_block_ids in genomic_align
    my $sql2 = "UPDATE genomic_align SET genomic_align_block_id = (genomic_align_block_id % $magic_number) + ?, genomic_align_id = (genomic_align_id % $magic_number) + ?, method_link_species_set_id = ? WHERE method_link_species_set_id = ?";
    # Remove the component MLSS genomic_align_blocks
    my $sql3 = "DELETE FROM genomic_align_block WHERE method_link_species_set_id = ?";

    # We really need a transaction to ensure we are not screwing the database
    my $dbc = $self->compara_dba->dbc;
    $self->call_within_transaction(sub {
        my $offset_ga  = $principal_mlss_id * $magic_number;
        my $offset_gab = $principal_mlss_id * $magic_number;
        foreach my $mlss_id ( @{$component_mlss_ids} ) {
            # Get the required information about this component MLSS'
            # genomic_aligns and genomic_align_blocks
            my ($min_ga, $max_ga, $min_gab, $max_gab, $tot_count, $safe_ga_count, $safe_gab_count) = $dbc->db_handle->selectrow_array($sql0, undef, $mlss_id);
            die "No entries found for component mlss_id=$mlss_id\n" unless (defined $min_ga && defined $min_gab);
            die "genomic_align_id or genomic_align_block_id remainders are not unique\n" if (($tot_count != $safe_ga_count) || ($tot_count != 2*$safe_gab_count));
            # Lift the genomic_aligns and genomic_align_blocks from the
            # component MLSS to the principal MLSS
            print STDERR "Offsets for mlss_id=$mlss_id:\n\tgenomic_align_block_id=$offset_gab\n\tgenomic_align_id=$offset_ga\n";
            print STDERR (my $nd = $dbc->do($sql1, undef, $offset_gab, $principal_mlss_id, $mlss_id)), " rows duplicated in genomic_align_block\n";
            print STDERR $dbc->do($sql2, undef, $offset_gab, $offset_ga, $principal_mlss_id, $mlss_id), " rows of genomic_align redirected to the new entries in genomic_align_block\n";
            print STDERR (my $nr = $dbc->do($sql3, undef, $mlss_id)), " rows removed from genomic_align_block\n";
            die "Numbers mismatch: $nd rows duplicated and $nr removed\n" if ($nd != $nr);
            # Update the offsets
            $offset_ga  += $max_ga;
            $offset_gab += $max_gab;
        }
    });
}


=head2 _update_dnafrags

Description : Updates the dnafrag_ids from the component genomes to their
              principal genome in genomic_align table. Note that the update is
              performed in a transaction manner.

=cut

sub _update_dnafrags {
    my $self = shift;
    
    my $principal_mlss_id  = $self->param_required('principal_mlss_id');
    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $principal_mlss = $mlss_adaptor->fetch_by_dbID($principal_mlss_id);
    my @genome_dbs = $principal_mlss->find_pairwise_reference();
    
    # Update the dnafrag_ids in genomic_align from component to the principal
    my $sql = "UPDATE genomic_align ga JOIN dnafrag d1 USING (dnafrag_id) JOIN dnafrag d2 USING (name) SET ga.dnafrag_id = d2.dnafrag_id WHERE d1.genome_db_id = ? AND d2.genome_db_id = ? AND method_link_species_set_id = ?";

    # We really need a transaction to ensure we are not screwing the database
    my $dbc = $self->compara_dba->dbc;
    $self->call_within_transaction(sub {
        my $nr;
        foreach my $principal_gdb ( @genome_dbs ) {
            my $component_gdbs = $principal_gdb->component_genome_dbs;
            foreach my $gdb ( @{$component_gdbs} ) {
                $nr += $dbc->do($sql, undef, $gdb->dbID, $principal_gdb->dbID, $principal_mlss_id);
            }
        }
        die "No rows where updated\n" unless $nr;
        print STDERR "$nr rows of genomic_align redirected to the principal dnafrags\n";
    });
}


1;
