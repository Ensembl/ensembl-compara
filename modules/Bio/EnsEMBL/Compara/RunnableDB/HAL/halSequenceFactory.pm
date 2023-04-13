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

Bio::EnsEMBL::Compara::RunnableDB::HAL::halSequenceFactory

=head1 DESCRIPTION

HAL genome and sequence names are dataflowed on branch "fan_branch_code" (default: 2)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::halSequenceFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {

        'fan_branch_code' => 2,
    }
}

sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param_required('genome_db_id');
    my $mlss_id = $self->param_required('mlss_id');

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);

    my $map_tag = $mlss->get_value_for_tag('HAL_mapping', '{}');
    my $species_map = eval $map_tag;

    if (!exists $species_map->{$genome_db_id}) {
        $self->die_no_retry('genome_db_id ' . $genome_db_id . ' not in HAL mapping');
    }

    my $hal_genome_name = $species_map->{$genome_db_id};
    $self->param('hal_genome_name', $hal_genome_name);

    my $hal_file = $mlss->url;
    my $hal_adaptor = Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor->new($hal_file);

    my @hal_sequence_names = $hal_adaptor->seqs_in_genome($hal_genome_name);
    $self->param('hal_sequence_names', \@hal_sequence_names);
}

sub write_output {
    my $self = shift;

    my $hal_genome_name = $self->param('hal_genome_name');
    foreach my $hal_sequence_name (@{$self->param('hal_sequence_names')}) {
        my $h = { 'hal_genome_name' => $hal_genome_name, 'hal_sequence_name' => $hal_sequence_name };
        $self->dataflow_output_id($h, $self->param('fan_branch_code'));
    }
}


1;
