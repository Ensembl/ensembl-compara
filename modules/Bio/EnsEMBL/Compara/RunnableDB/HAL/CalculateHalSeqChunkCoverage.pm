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

Bio::EnsEMBL::Compara::RunnableDB::HAL::CalculateHalSeqChunkCoverage

=head1 DESCRIPTION

Calculate genomic coverage for one HAL sequence chunk.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::CalculateHalSeqChunkCoverage;

use strict;
use warnings;

use JSON qw(decode_json);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift @_;

    my $hal_cov_one_seq_chunk_exe = $self->param_required('hal_cov_one_seq_chunk_exe');
    my $hal_alignment_depth_exe = $self->param_required('hal_alignment_depth_exe');
    my $hal_file_path = $self->param_required('hal_file_path');

    my $ref_genome_name = $self->param_required('hal_genome_name');
    my $ref_sequence_name = $self->param_required('hal_sequence_name');
    my $chunk_offset = $self->param_required('chunk_offset');
    my $chunk_length = $self->param_required('chunk_length');

    my $species_map = $self->param_required('species_name_mapping');
    my $target_genomes_arg = join(',', values %{$species_map});

    my $cmd = [
        $hal_cov_one_seq_chunk_exe,
        $hal_file_path,
        $ref_genome_name,
        '--ref-sequence',
        $ref_sequence_name,
        '--start',
        $chunk_offset,
        '--length',
        $chunk_length,
        '--target-genomes',
        $target_genomes_arg,
        '--hal_alignment_depth_exe',
        $hal_alignment_depth_exe,
    ];

    my $output = $self->get_command_output($cmd);
    my $dnafrag_cov_stats = decode_json($output);

    $self->param('num_aligned_positions', $dnafrag_cov_stats->{'num_aligned_positions'});
    $self->param('num_positions', $dnafrag_cov_stats->{'num_positions'});
}


sub write_output {
    my $self = shift;

    $self->dataflow_output_id({
        'hal_sequence_name'     => $self->param('hal_sequence_name'),
        'chunk_offset'          => $self->param('chunk_offset'),
        'num_positions'         => $self->param('num_positions'),
        'num_aligned_positions' => $self->param('num_aligned_positions'),
    }, 3);
}


1;
