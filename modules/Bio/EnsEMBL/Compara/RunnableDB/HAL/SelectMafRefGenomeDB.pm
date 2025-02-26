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

Bio::EnsEMBL::Compara::RunnableDB::HAL::SelectMafRefGenomeDB

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::SelectMafRefGenomeDB;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $num_pending_ref_gdb_ids = $self->param_required('num_pending_ref_gdb_ids');
    my $pending_ref_gdb_ids = $self->param_required('pending_ref_gdb_ids');
    my $mlss_id = $self->param_required('mlss_id');

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);

    my $ref_genome_db_id;
    if (scalar(@{$pending_ref_gdb_ids}) == 1) {
        $ref_genome_db_id = pop @{$pending_ref_gdb_ids};
    } else {
        $self->die_no_retry("reference GenomeDB selection not implemented");
    }

    @{$pending_ref_gdb_ids} = grep { $_ != $ref_genome_db_id } @{$pending_ref_gdb_ids};

    my %pending_ref_info = (
        'num_pending_ref_gdb_ids' => scalar(@{$pending_ref_gdb_ids}),
        'pending_ref_gdb_ids' => $pending_ref_gdb_ids,
    );

    my %fan_output_id = (
        %pending_ref_info,
        'ref_genome_db_id' => $ref_genome_db_id,
    );

    $self->dataflow_output_id(\%fan_output_id, 3);
}


1;
