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

Bio::EnsEMBL::Compara::RunnableDB::HAL::halSeqChunkFactory

=head1 DESCRIPTION

Info about HAL genome sequence chunks is dataflowed on branch 2,
while the HAL sequence name is dataflowed on branch 3.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::halSeqChunkFactory;

use strict;
use warnings;

use List::Util qw(min);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift @_;

    my $hal_stats_exe = $self->param_required('hal_stats_exe');

    my $mlss_id = $self->param_required('mlss_id');
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $hal_file_path = $mlss->url;
    my $hal_genome_name = $self->param_required('hal_genome_name');

    my $cmd = [
        $hal_stats_exe,
        '--chromSizes',
        $hal_genome_name,
        $hal_file_path,
    ];

    my @chrom_size_lines = $self->get_command_output($cmd);
    my %hal_genome_seq_lengths = map { split /\t/ } @chrom_size_lines;
    $self->param('hal_genome_seq_lengths', \%hal_genome_seq_lengths);
}


sub write_output {
    my $self = shift;

    my $req_chunk_length = 1_000_000;
    while (my ($hal_sequence_name, $hal_sequence_length) = each %{$self->param('hal_genome_seq_lengths')}) {

        $self->dataflow_output_id({ 'hal_sequence_name' => $hal_sequence_name }, 3);

        for (my $offset = 0; $offset < $hal_sequence_length; $offset += $req_chunk_length) {
            my $chunk_length = min($req_chunk_length, $hal_sequence_length - $offset);
            my $h = {
                'hal_sequence_name' => $hal_sequence_name,
                'chunk_offset'      => $offset,
                'chunk_length'      => $chunk_length,
            };
            $self->dataflow_output_id($h, 2);
        }
    }
}


1;
