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

Bio::EnsEMBL::Compara::RunnableDB::HAL::DumpCactusMaf

=head1 DESCRIPTION

Dump Cactus MAF from HAL file.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::HAL::DumpCactusMaf;

use strict;
use warnings;

use File::Basename qw(basename);
use File::Spec::Functions qw(catfile);

use Bio::AlignIO;

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'max_block_length_to_dump' => 1_000_000,
    }
}


sub pre_cleanup {
    my $self = shift;

    my $maf_file = $self->param_required('maf_file');

    my @cmds = (
        "rm -f $maf_file",
    );

    foreach my $cmd (@cmds) {
        $self->run_command($cmd, { die_on_failure => 1 });
    }
}


sub fetch_input {
    my $self = shift;

    if (!$self->param_is_defined('hal_file')) {
        my $mlss_id = $self->param_required('mlss_id');
        my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
        $self->param('hal_file', $mlss->url);
    }

    if (!$self->param_is_defined('target_genomes')) {
        my $mlss_id = $self->param_required('mlss_id');
        my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
        my $species_map = destringify($mlss->get_value_for_tag('hal_mapping', '{}'));
        $self->param('target_genomes', join(',', values %{$species_map}));
    }
}


sub run {
    my $self = shift;

    my $hal2maf_exe = $self->require_executable('hal2maf_exe');

    my $chunk_length = $self->param_required('chunk_length');
    my $maf_file = $self->param_required('maf_file');

    my $temp_maf_file = catfile($self->worker_temp_directory, basename($maf_file));

    my $cmd_args = [
        $hal2maf_exe,
        $self->param('hal_file'),
        $temp_maf_file,
        '--refGenome',
        $self->param_required('hal_genome_name'),
        '--refSequence',
        $self->param_required('hal_sequence_name'),
        '--start',
        $self->param_required('chunk_offset'),
        '--length',
        $chunk_length,
        '--maxBlockLen',
        $self->param_required('max_block_length_to_dump'),
        '--targetGenomes',
        $self->param('target_genomes'),
        '--noAncestors',
        '--unique',
    ];

    $self->run_command($cmd_args, { die_on_failure => 1 });

    $self->param('temp_maf_file', $temp_maf_file);
}


sub write_output {
    my $self = shift;

    my $hal_chunk_index = $self->param_required('hal_chunk_index');
    my $maf_parent_dir = $self->param_required('maf_parent_dir');
    my $temp_maf_file = $self->param_required('temp_maf_file');
    my $maf_file = $self->param_required('maf_file');

    my $maf_block_count_cmd = "grep -c '^a' $temp_maf_file";
    my $run_cmd = $self->run_command($maf_block_count_cmd);
    $run_cmd->die_with_log() if $run_cmd->exit_code >= 2;
    my ($maf_block_count) = split(/\n/, $run_cmd->out);

    my @output_cmds = (
        "mkdir -p $maf_parent_dir",
        "mv $temp_maf_file $maf_file",
    );

    foreach my $cmd (@output_cmds) {
        $self->run_command($cmd, { die_on_failure => 1 });
    }

    my $output_id = {
        'hal_chunk_index'        => $hal_chunk_index,
        'dumped_maf_block_count' => $maf_block_count,
        'dumped_maf_file'        => $maf_file,
        'maf_parent_dir'         => $maf_parent_dir,
    };

    $self->dataflow_output_id($output_id, 2);
}


1;
