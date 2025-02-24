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

Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadHalMapping

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadHalMapping;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils qw(destringify stringify);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $hal_stats_exe = $self->require_executable('halStats_exe');

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor();

    my $mlss_id = $self->param_required('mlss_id');
    my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);

    my $species_map;
    if ( $self->param_is_defined('species_name_mapping') ) {
        $species_map = destringify($self->param('species_name_mapping'));

    } else {

        my @genome_dbs = map { $gdb_adaptor->fetch_by_dbID($_->dbID) } @{$mlss->species_set->genome_dbs};

        # Keep only principal GenomeDBs; these will be expanded to include components as appropriate.
        @genome_dbs = grep { !$_->genome_component } @genome_dbs;

        my $hal_file = $mlss->url;

        my $cmd_args = [$hal_stats_exe, '--genomes', $hal_file];
        my ($output) = $self->get_command_output($cmd_args, { die_on_failure => 1 });  # We only need the first line of output.
        my @hal_genome_names = split(/ /, $output);
        my @hal_leaf_genome_names = grep { $_ !~ /^Anc[0-9]+$/ } @hal_genome_names;

        foreach my $genome_db (@genome_dbs) {
            my $id_separator = '.';
            my %rev_species_map;

            my $genome_db_name = $genome_db->get_distinct_name();
            my $assembly_name = $genome_db->assembly;

            foreach my $exp_hal_name ($genome_db_name, $genome_db_name . $id_separator . $assembly_name) {
                $rev_species_map{$exp_hal_name} = $genome_db->dbID;
            }

            if ($genome_db->is_polyploid) {
                my $comp_gdbs = $genome_db->component_genome_dbs;
                foreach my $comp_gdb (@{$comp_gdbs}) {
                    my $comp_gdb_name = $comp_gdb->get_distinct_name();
                    foreach my $exp_hal_name ($comp_gdb_name, $comp_gdb_name . $id_separator . $assembly_name) {
                        $rev_species_map{$exp_hal_name} = $comp_gdb->dbID;
                    }
                }
            }

            my @matching_genome_names = grep { exists $rev_species_map{$_} } @hal_leaf_genome_names;

            if ( scalar(@matching_genome_names) == 0 ) {
                throw("Cannot map GenomeDB $genome_db_name to any HAL genome name");
            }

            foreach my $matching_genome_name (@matching_genome_names) {
                my $matching_gdb_id = $rev_species_map{$matching_genome_name};

                if (exists $species_map->{$matching_gdb_id}) {
                    throw(sprintf(
                        "GenomeDB with ID %d matches to multiple HAL genome names (e.g. %s, %s)",
                        $matching_gdb_id, $matching_genome_name, $species_map->{$matching_gdb_id}
                    ));
                }

                $species_map->{$matching_gdb_id} = $matching_genome_name;
            }
        }
    }

    $mlss->store_tag('hal_mapping', stringify($species_map));
}


1;
