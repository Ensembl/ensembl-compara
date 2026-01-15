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

Bio::EnsEMBL::Compara::RunnableDB::HAL::PrepVariationChain

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::PrepVariationChain;

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use JSON qw(decode_json);

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(check_for_null_characters);
use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub pre_cleanup {
    my $self = shift;

    my $prepped_chain_file = $self->param_required('prepped_chain_file');

    my @cmds = (
        "rm -f $prepped_chain_file",
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

    if (!$self->param_is_defined('alt_hal_genome')) {
        my $mlss_id = $self->param_required('mlss_id');
        my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
        my $species_map = destringify($mlss->get_value_for_tag('hal_mapping', '{}'));
        $self->param('alt_hal_genome', join(',', values %{$species_map}));
    }
    my %maf_genome_name_set = map { $_ => 1 } split(/,/, $self->param('alt_hal_genome'));

    if ($self->param_is_defined('hal_genome_name')) {
        $maf_genome_name_set{$self->param('hal_genome_name')} = 1;
    }

    $self->param('maf_genomes', [sort keys %maf_genome_name_set]);
}


sub run {
    my $self = shift;

    my $maf_duplicate_filter_exe = $self->require_executable('mafDuplicateFilter_exe');
    my $process_cactus_maf_exe = $self->require_executable('process_cactus_maf_exe');
    my $left_align_maf_exe = $self->require_executable('left_align_maf_exe');
    my $maf_convert_exe = $self->require_executable('maf_convert_exe');
    my $map_maf_src_field_exe = $self->require_executable('map_maf_src_field_exe');
    my $split_maf_on_gaps_exe = $self->require_executable('split_maf_on_gaps_exe');
    my $taffy_exe = $self->require_executable('taffy_exe');

    my $hal_file = $self->param('hal_file');
    my $hal_mapping_dir = $self->param_required('hal_mapping_dir');
    my @maf_genomes = @{$self->param('maf_genomes')};

    my $dumped_maf_file = $self->param_required('dumped_maf_file');
    my $dumped_maf_block_count = $self->param_required('dumped_maf_block_count');
    my $chain_file_path = $self->param_required('prepped_chain_file');

    my($chain_file_name, $chunk_parent_dir) = fileparse($chain_file_path);
    $self->param('chunk_parent_dir', $chunk_parent_dir);

    my $temp_dir = tempdir( CLEANUP => 1, DIR => $self->worker_temp_directory );
    my $temp_chain_file_path = catfile($temp_dir, $chain_file_name);

    my $mapping_tsv = catfile($temp_dir, 'mapping.tsv');
    my $reverse_mapping_tsv = catfile($temp_dir, 'revmap.tsv');
    my @hal_mapping_files;
    my @mapping_lines;
    my @revmap_lines;
    foreach my $idx (0 .. $#maf_genomes) {
        my @row = ($maf_genomes[$idx], 'genome' . $idx);
        push(@mapping_lines, join("\t", @row));
        push(@revmap_lines, join("\t", reverse @row));

        my $hal_mapping_file = catfile($hal_mapping_dir, $maf_genomes[$idx] . '.hal_mapping.tsv');
        push(@hal_mapping_files, $hal_mapping_file);
    }
    $self->_spurt($mapping_tsv, join("\n", @mapping_lines));
    $self->_spurt($reverse_mapping_tsv, join("\n", @revmap_lines));

    $self->warning("Processing raw Cactus MAF file: $dumped_maf_file") if($self->debug);
    my $filtered_maf = catfile($temp_dir, 'filtered.maf');
    my $cmd1_args = [
        $process_cactus_maf_exe,
        $dumped_maf_file,
        $filtered_maf,
        '--min-block-cols',
        1,
        '--min-seq-length',
        1,
        '--expected-block-count',
        $dumped_maf_block_count
    ];
    $self->run_command($cmd1_args, { die_on_failure => 1 });

    $self->warning("Sanitising genome names in filtered MAF: $filtered_maf") if($self->debug);
    my $sanitised_maf = catfile($temp_dir, 'sanitised.maf');
    my $cmd2_args = [
        $taffy_exe,
        'view',
        '--maf',
        '--nameMapFile',
        $mapping_tsv,
        '--inputFile',
        $filtered_maf,
        '--outputFile',
        $sanitised_maf,
    ];
    $self->run_command($cmd2_args, { die_on_failure => 1 });

    $self->warning("Deduplicating sanitised MAF: $sanitised_maf") if($self->debug);
    my $deduped_maf = catfile($temp_dir, 'deduped.maf');
    my $cmd3 = "$maf_duplicate_filter_exe --keep-first --maf $sanitised_maf > $deduped_maf";
    $self->run_command($cmd3, { die_on_failure => 1 });

    $self->warning("Restoring genome names in deduplicated MAF: $deduped_maf") if($self->debug);
    my $renamed_maf = catfile($temp_dir, 'renamed.maf');
    my $cmd4_args = [
        $taffy_exe,
        'view',
        '--nameMapFile',
        $reverse_mapping_tsv,
        '--inputFile',
        $deduped_maf,
        '--outputFile',
        $renamed_maf,
        '--maf',
    ];
    $self->run_command($cmd4_args, { die_on_failure => 1 });

    $self->warning("Further processing MAF: $renamed_maf") if($self->debug);
    my $reprocessed_maf = catfile($temp_dir, 'reprocessed.maf');
    my $cmd5_args = [
        $process_cactus_maf_exe,
        $renamed_maf,
        $reprocessed_maf,
        '--min-block-cols',
        1,
        '--min-seq-length',
        1,
    ];
    $self->run_command($cmd5_args, { die_on_failure => 1 });

    $self->warning("Left-aligning Cactus MAF file: $filtered_maf") if($self->debug);
    my $left_aligned_maf = catfile($temp_dir, 'left_aligned.maf');
    my $cmd6_args = [
        $left_align_maf_exe,
        $reprocessed_maf,
        $left_aligned_maf,
    ];
    $self->run_command($cmd6_args, { die_on_failure => 1 });

    $self->warning("Relabelling sequences in MAF: $reprocessed_maf") if($self->debug);
    my @maf_src_map_params = map { ('--src-map-file', $_) } @hal_mapping_files;
    my $relabelled_maf = catfile($temp_dir, 'relabelled.maf');
    my $cmd7_args = [
        $map_maf_src_field_exe,
        $left_aligned_maf,
        $relabelled_maf,
        '--only-seq-name',
        @maf_src_map_params,
    ];
    $self->run_command($cmd7_args, { die_on_failure => 1 });

    $self->warning("Splitting MAF into ungapped blocks: $relabelled_maf") if($self->debug);
    my $temp_dataflow_file = catfile($temp_dir, 'dataflow.json');
    my $temp_prepped_maf_file_path = catfile($temp_dir, 'prepped.maf');
    my $cmd8_args = [
        $split_maf_on_gaps_exe,
        $relabelled_maf,
        $temp_prepped_maf_file_path,
        '--dataflow-file',
        $temp_dataflow_file,
    ];
    $self->run_command($cmd8_args, { die_on_failure => 1 });

    $self->warning("Extracting stats from $temp_dataflow_file") if($self->debug);
    my ($dataflow_event, @surplus_events) = split(/\n/, $self->_slurp($temp_dataflow_file));

    $self->warning("Dataflow event: $dataflow_event") if($self->debug);

    if (@surplus_events) {
        $self->die_no_retry("unexpected dataflow events in $temp_dataflow_file") if (@surplus_events);
    }

    if ($dataflow_event =~ /^(-?\d+)\s+(.*)$/) {  # pattern from Bio::EnsEMBL::Hive::Process::from dataflow_output_ids_from_json
        my $dataflow_data = decode_json($2);
        $self->param('maf_block_count', $dataflow_data->{'maf_block_count'});
        $self->param('maf_seq_count', $dataflow_data->{'maf_seq_count'});
    } else {
        $self->die_no_retry("failed to parse dataflow event in $temp_dataflow_file");
    }

    $self->warning("Converting MAF to chain file") if($self->debug);
    my @cmd9_args = (
        $maf_convert_exe,
        'chain',
        '--subject',
        '1',
        $temp_prepped_maf_file_path,
        '>',
        $temp_chain_file_path,
    );
    $self->run_command(join(' ', @cmd9_args), { die_on_failure => 1 });

    $self->param('temp_chain_file_path', $temp_chain_file_path);

    $self->param('exp_chain_count', $self->param('maf_block_count'));
    $self->param('obs_chain_count', $self->_get_chain_count($temp_chain_file_path));

    if ( $self->param_is_defined('healthcheck_list') ) {
        $self->_healthcheck();
    }
}


sub write_output {
    my $self = shift;

    my $hal_chunk_index = $self->param_required('hal_chunk_index');
    my $chunk_parent_dir = $self->param_required('chunk_parent_dir');
    my $temp_chain_file_path = $self->param_required('temp_chain_file_path');
    my $prepped_chain_file_path = $self->param_required('prepped_chain_file');
    my $chain_count = $self->param_required('obs_chain_count');

    my @output_cmds = (
        "mkdir -p $chunk_parent_dir",
        "mv $temp_chain_file_path $prepped_chain_file_path",
    );

    foreach my $cmd (@output_cmds) {
        $self->run_command($cmd, { die_on_failure => 1 });
    }

    my $output_id = {
        'hal_chunk_index' => $hal_chunk_index,
        'chain_count'     => $chain_count,
        'chain_file'      => $prepped_chain_file_path,
    };

    $self->dataflow_output_id($output_id, 2);
}


sub _get_chain_count {
    my ($self, $chain_file_path) = @_;

    my $chain_count_cmd = "grep -c '^chain' $chain_file_path";
    my $run_cmd = $self->run_command($chain_count_cmd);
    $run_cmd->die_with_log() if $run_cmd->exit_code >= 2;
    my ($chain_count) = split(/\n/, $run_cmd->out);

    return $chain_count;
}


sub _healthcheck {
    my $self = shift;

    my $healthcheck_list = destringify($self->param_required('healthcheck_list'));
    my $temp_chain_file_path = $self->param('temp_chain_file_path');

    foreach my $hc_type (@{$healthcheck_list}) {
        if ( $hc_type eq 'chain_count' ) {

            my $exp_chain_count = $self->param_required('exp_chain_count');
            my $obs_chain_count = $self->param_required('obs_chain_count');
            if ($obs_chain_count != $exp_chain_count) {
                $self->die_no_retry(
                    sprintf(
                        "Number of chains in file is %d but should be %d",
                        $obs_chain_count,
                        $exp_chain_count,
                    )
                );
            }

        } elsif ( $hc_type eq 'unexpected_nulls' ) {
            check_for_null_characters($temp_chain_file_path);
        } else {
            $self->die_no_retry("Healthcheck type '$hc_type' not recognised");
        }
    }
}


1;
