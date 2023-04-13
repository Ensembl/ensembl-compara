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

Bio::EnsEMBL::Compara::RunnableDB::HAL::CalculateHalSequenceCoverage

=head1 DESCRIPTION

Calculate genomic coverage for one HAL sequence.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::CalculateHalSequenceCoverage;

use strict;
use warnings;

use JSON qw(decode_json);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');
    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);
    $self->param('hal_file', $mlss->url);
}


sub run {
    my $self = shift @_;

    my $hal_cov_one_seq_exe = $self->param_required('hal_cov_one_seq_exe');
    my $hal_alignment_depth_exe = $self->param_required('hal_alignment_depth_exe');
    my $hal_stats_exe = $self->param_required('hal_stats_exe');

    my $hal_genome_name = $self->param_required('hal_genome_name');
    my $hal_sequence_name = $self->param_required('hal_sequence_name');
    my $hal_file = $self->param('hal_file');

    my $cmd = [
        $hal_cov_one_seq_exe,
        $hal_file,
        $hal_genome_name,
        $hal_sequence_name,
        '--hal_alignment_depth_exe', $hal_alignment_depth_exe,
        '--hal_stats_exe', $hal_stats_exe,
    ];

    my $output = $self->get_command_output($cmd);
    my $dnafrag_cov_stats = decode_json($output);

    $self->param('num_aligned_positions', $dnafrag_cov_stats->{'num_aligned_positions'});
    $self->param('num_positions', $dnafrag_cov_stats->{'num_positions'});
}


sub write_output {
    my $self = shift;

    $self->dataflow_output_id({
        'hal_genome_name'       => $self->param('hal_genome_name'),
        'hal_sequence_name'     => $self->param('hal_sequence_name'),
        'num_positions'         => $self->param('num_positions'),
        'num_aligned_positions' => $self->param('num_aligned_positions'),
    }, 2);
}


1;
