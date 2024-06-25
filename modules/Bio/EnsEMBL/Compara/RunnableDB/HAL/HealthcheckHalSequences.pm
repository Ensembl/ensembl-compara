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

Bio::EnsEMBL::Compara::RunnableDB::HAL::HealthcheckHalSequences

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::HealthcheckHalSequences;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $hal_stats_exe = $self->param_required('hal_stats_exe');
    my $mlss_id = $self->param_required('mlss_id');

    my $compara_dba = $self->compara_dba;
    my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();

    my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);
    my $hal_file_path = $mlss->url;

    my $hal_species_mapping = destringify($mlss->get_value_for_tag('hal_mapping', '{}'));
    while (my ($map_gdb_id, $hal_genome_name) = each %{$hal_species_mapping}) {
        my $map_gdb = $genome_db_adaptor->fetch_by_dbID($map_gdb_id);
        my $principal = $map_gdb->principal_genome_db();
        my $gdb_id = defined $principal ? $principal->dbID : $map_gdb_id;

        my $gdb = $genome_db_adaptor->fetch_by_dbID($gdb_id);
        my $dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB($gdb);
        my %dnafrag_name_to_length = map { $_->name => $_->length } @{$dnafrags};

        my $cmd = [
            $hal_stats_exe,
            '--chromSizes',
            $hal_genome_name,
            $hal_file_path,
        ];

        my @chrom_size_lines = $self->get_command_output($cmd, { die_on_failure => 1 });
        my @chrom_size_pairs = map { [ split /\t/ ] } @chrom_size_lines;

        @chrom_size_pairs = sort {
             ($a->[0]=~/^[0-9]+$/ && $b->[0]=~/^[0-9]+$/)
            ? $a->[0] <=> $b->[0]
            : $a->[0] cmp $b->[0]
        } @chrom_size_pairs;

        foreach my $chrom_size_pair (@chrom_size_pairs) {
            my ($hal_seq_name, $hal_seq_length) = @$chrom_size_pair;
            if (exists $dnafrag_name_to_length{$hal_seq_name}) {
                my $dnafrag_length = $dnafrag_name_to_length{$hal_seq_name};
                if ($hal_seq_length != $dnafrag_length) {
                    $self->die_no_retry(
                        sprintf(
                            "HAL genome %s has sequence %s whose length (%d) does not match that of its namesake dnafrag in %s (%d)",
                            $hal_genome_name,
                            $hal_seq_name,
                            $hal_seq_length,
                            $gdb->get_distinct_name(),
                            $dnafrag_length,
                        )
                    );
                }
            } else {
                $self->die_no_retry(
                    sprintf(
                        "No namesake dnafrag found in %s for sequence %s of HAL genome %s",
                        $gdb->get_distinct_name(),
                        $hal_seq_name,
                        $hal_genome_name,
                    )
                );
            }
        }
    }
}


1;
