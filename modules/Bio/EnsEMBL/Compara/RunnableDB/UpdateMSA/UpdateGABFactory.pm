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

Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGABFactory

=head1 DESCRIPTION

Flows 1 job per genomic align block id (and corresponding genomic align ids)
that are affected by the species removed in the given MSA MLSS.

=over

=item mlss_id

Mandatory. Current release MSA's MLSS id.

=item prev_mlss_id

Mandatory. Previous release MSA's MLSS id.

=back

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGABFactory \
        -compara_db $(mysql-ens-compara-prod-9-ensadmin details url jalvarez_amniotes_pecan_update_101) \
        -mlss_id 1897 -prev_mlss_id 1831

=cut

package Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGABFactory;

use warnings;
use strict;

use Array::Utils qw(array_minus);

use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;
    my $prev_mlss_id = $self->param_required('prev_mlss_id');
    my $curr_mlss_id = $self->param_required('mlss_id');
    my $dba = $self->compara_dba;
    # Get the list of retired genomes that have to be removed from the MSA
    my $mlss_adaptor = $dba->get_MethodLinkSpeciesSetAdaptor();
    my $prev_mlss = $mlss_adaptor->fetch_by_dbID($prev_mlss_id);
    my $curr_mlss = $mlss_adaptor->fetch_by_dbID($curr_mlss_id);
    # Set algebra: prev_genome_db_ids - curr_genome_db_ids
    my @gdbs_to_rm = map { $_->dbID }
        array_minus(@{ $prev_mlss->species_set->genome_dbs }, @{ $curr_mlss->species_set->genome_dbs });
    die "No genomes to remove in the MSA. Are you sure you need to update it?" if !@gdbs_to_rm;
    print "Genome dbs to remove: " . join(', ', @gdbs_to_rm) . "\n" if $self->debug;
    # Get the ids of every genomic align and genomic align block affected
    my $sth = $dba->dbc->prepare("SELECT genomic_align_id, genomic_align_block_id FROM genomic_align ga
        JOIN dnafrag df USING (dnafrag_id) WHERE method_link_species_set_id = $curr_mlss_id
        AND genome_db_id IN (" . join(',', @gdbs_to_rm) . ")");
    $sth->execute();
    my %affected_gabs;
    while ( my ($ga_id, $gab_id) = $sth->fetchrow ) {
        push @{ $affected_gabs{$gab_id} }, $ga_id;
    }
    $self->param('affected_gabs', \%affected_gabs);
}


sub write_output {
    my $self = shift;
    my $affected_gabs = $self->param('affected_gabs');

    my @gab_ids_sorted = sort keys(%$affected_gabs); # important for testing
    foreach my $gab_id ( @gab_ids_sorted ) {
        $self->dataflow_output_id({
            'gab_id'     => $gab_id,
            'ga_id_list' => $affected_gabs->{$gab_id},
        }, 2);
    }
}


1;
