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

Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::SyncAncestralDB

=head1 DESCRIPTION

Removes all entries in seq_region and dna tables that match ancestor_names in
the given ancestral database.

=over

=item ancestral_db

Mandatory. Ancestral database connection hash.

=item ancestor_names

Mandatory. List of ancestor names to be removed (should match the name field in
seq_region table).

=back

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::SyncAncestralDB \
        -ancestral_db "{'-dbname' => 'jalvarez_mammals_ancestral_core_102', '-driver' => 'mysql', '-host' => 'mysql-ens-compara-prod-9', '-pass' => '$ENSADMIN_PSW', '-port' => 4647, '-species' => 'ancestral_sequences', '-user' => 'ensadmin'}" \
        -ancestor_names "['Ancestor_1904_1','Ancestor_1904_20']"

=cut

package Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::SyncAncestralDB;

use warnings;
use strict;

use DBI qw(:sql_types);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Hive::Utils;
use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;
    my $ancestral_db = $self->param_required('ancestral_db');
    my $ancestor_names = $self->param_required('ancestor_names');

    my $dbc = Bio::EnsEMBL::Hive::Utils::go_figure_dbc($ancestral_db);
    # Speed up deleting data by disabling the tables keys
    $dbc->do("ALTER TABLE `dna` DISABLE KEYS");
    $dbc->do("ALTER TABLE `seq_region` DISABLE KEYS");
    # Delete the sequence regions that have been removed from the MSA as well
    my $ancestral_adaptor = Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor->new( $dbc );
    my $nrows;
    $ancestral_adaptor->split_and_callback($ancestor_names, 'seq_region.name', SQL_VARCHAR, sub {
        my $sql = "DELETE seq_region, dna FROM seq_region JOIN dna USING (seq_region_id) WHERE " . (shift);
        my $nrows += $dbc->do($sql);
    });
    print "Removed $nrows row(s) from seq_region and dna tables\n" if $self->debug;
    # Re-enable the tables keys
    $dbc->do("ALTER TABLE `seq_region` ENABLE KEYS");
    $dbc->do("ALTER TABLE `dna` ENABLE KEYS");
}


1;
