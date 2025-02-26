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

Bio::EnsEMBL::Compara::RunnableDB::HAL::halDualGenomeFactory

=head1 DESCRIPTION

This runnable dataflows the ID of the GenomeDB represented in a HAL file on branch code 2,
and an arrayref of its corresponding HAL genome name(s) on branch code 3.

For a polyploid genome represented in a HAL file by multiple components,
the GenomeDB ID of the principal genome is dataflowed on branch 2,
while the component HAL genome names are dataflowed on branch 3.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::HAL::halDualGenomeFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $species_map = destringify($mlss->get_value_for_tag('HAL_mapping', '{}'));

    my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

    my %linking_map;
    while (my ($map_gdb_id, $hal_genome_name) = each %{$species_map}) {
        my $genome_db = $genome_db_adaptor->fetch_by_dbID($map_gdb_id);

        my $main_gdb_id = $map_gdb_id;
        if ($genome_db->genome_component) {
            my $principal = $genome_db->principal_genome_db();
            $main_gdb_id = $principal->dbID;
        }

        $linking_map{$main_gdb_id}{$map_gdb_id} = $hal_genome_name;
    }

    $self->param('linking_map', \%linking_map);
}


sub write_output {
    my $self = shift;

    while (my ($main_gdb_id, $species_map_pairs) = each %{$self->param('linking_map')}) {

        while (my ($map_gdb_id, $hal_genome_name) = each %{$species_map_pairs}) {
            $self->dataflow_output_id({ 'genome_db_id' => $map_gdb_id, 'hal_genome_name' => $hal_genome_name }, 3);
        }

        $self->dataflow_output_id({ 'genome_db_id' => $main_gdb_id }, 2);
    }
}


1;
