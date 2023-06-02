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

Bio::EnsEMBL::Compara::RunnableDB::HAL::halGenomeDBFactory

=head1 DESCRIPTION

This Runnable flows the GenomeDB ids from the 'HAL_mapping'
tag of the MLSS specified by the 'mlss_id' parameter.

IDs are flown on branch "fan_branch_code" (default: 2)

=cut


package Bio::EnsEMBL::Compara::RunnableDB::HAL::halGenomeDBFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {

        'fan_branch_code' => 2,
    }
}


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);

    my $map_tag = $mlss->get_value_for_tag('HAL_mapping', '{}');
    my $species_map = eval $map_tag;

    my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    my @genome_dbs = map { $genome_db_adaptor->fetch_by_dbID($_) } keys %$species_map;

    $self->param('genome_dbs', \@genome_dbs);
}


sub write_output {
    my $self = shift;

    foreach my $gdb (@{$self->param('genome_dbs')}) {
        my $h = { 'genome_db_id' => $gdb->dbID };
        $self->dataflow_output_id($h, $self->param('fan_branch_code'));
    }
}


1;
