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

Bio::EnsEMBL::Compara::RunnableDB::HAL::InitLoadGenomeDB

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::InitLoadGenomeDB;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $num_pending_ref_gdb_ids = $self->param_required('num_pending_ref_gdb_ids');
    my $ref_genome_db_id = $self->param_required('ref_genome_db_id');
    my $mlss_id = $self->param_required('mlss_id');

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $species_map = destringify($mlss->get_value_for_tag('hal_mapping', '{}'));
    my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor();

    my %gdb_hal_rev_map;
    my @pending_ref_hal_genomes;
    while (my ($map_gdb_id, $hal_genome_name) = each %{$species_map}) {
        my $gdb = $genome_db_adaptor->fetch_by_dbID($map_gdb_id);
        my $main_gdb_id = $gdb->genome_component ? $gdb->principal_genome_db->dbID : $map_gdb_id;
        if ($main_gdb_id == $ref_genome_db_id) {
            push(@pending_ref_hal_genomes, $hal_genome_name);
            $gdb_hal_rev_map{$hal_genome_name} = $map_gdb_id;
        }
    }

    my $output_id = {
        'num_pending_ref_gdb_ids' => $num_pending_ref_gdb_ids,
        'num_pending_ref_hal_genomes' => scalar(@pending_ref_hal_genomes),
        'pending_ref_hal_genomes' => \@pending_ref_hal_genomes,
        'gdb_hal_rev_map' => \%gdb_hal_rev_map,
    };

    $self->dataflow_output_id($output_id, 2);
}

1;
