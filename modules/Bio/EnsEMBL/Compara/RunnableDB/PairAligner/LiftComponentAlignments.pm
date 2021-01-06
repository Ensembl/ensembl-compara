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


sub run {
    my $self = shift;

    $self->_update_dnafrags();
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
