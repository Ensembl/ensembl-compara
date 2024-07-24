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

Bio::EnsEMBL::Compara::RunnableDB::HAL::SelectMafRefHalGenome

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::SelectMafRefHalGenome;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $num_pending_ref_gdb_ids = $self->param_required('num_pending_ref_gdb_ids');
    my $pending_ref_hal_genomes = $self->param_required('pending_ref_hal_genomes');
    my $gdb_hal_rev_map = $self->param_required('gdb_hal_rev_map');
    my $mlss_id = $self->param_required('mlss_id');

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);

    my $ref_hal_genome;
    if (scalar(@{$pending_ref_hal_genomes}) > 0) {
        my @sorted_ref_hal_genomes = sort @{$pending_ref_hal_genomes};
        $ref_hal_genome = $sorted_ref_hal_genomes[0];
    } else {
        $self->die_no_retry("no pending reference HAL genomes");
    }

    @{$pending_ref_hal_genomes} = grep { $_ ne $ref_hal_genome } @{$pending_ref_hal_genomes};

    my %pending_ref_info = (
        'num_pending_ref_gdb_ids' => $num_pending_ref_gdb_ids,
        'num_pending_ref_hal_genomes' => scalar(@{$pending_ref_hal_genomes}),
        'pending_ref_hal_genomes' => $pending_ref_hal_genomes,
    );

    my %fan_output_id = (
        %pending_ref_info,
        'gdb_hal_rev_map' => $gdb_hal_rev_map,
        'ref_hal_genome' => $ref_hal_genome,
    );

    $self->dataflow_output_id(\%fan_output_id, 3);
}


1;
