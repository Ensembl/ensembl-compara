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

Bio::EnsEMBL::Compara::RunnableDB::HAL::PrepVariationMaf

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::PrepVariationMaf;

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use JSON qw(decode_json);

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub pre_cleanup {
    my $self = shift;

    my $prepped_maf_file = $self->param_required('prepped_maf_file');

    my @cmds = (
        "rm -f $prepped_maf_file",
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
    my %maf_genome_name_set = map { $_ => 1 } split(/,/, $self->param('target_genomes'));

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
    my $map_maf_src_field_exe = $self->require_executable('map_maf_src_field_exe');
    my $split_maf_on_gaps_exe = $self->require_executable('split_maf_on_gaps_exe');
    my $taffy_exe = $self->require_executable('taffy_exe');

    my $hal_file = $self->param('hal_file');
    my $hal_mapping_dir = $self->param_required('hal_mapping_dir');
    my @target_genomes = @{$self->param('maf_genomes')};

    my $dumped_maf_file = $self->param_required('dumped_maf_file');
    my $dumped_maf_block_count = $self->param_required('dumped_maf_block_count');
    my $prepped_maf_file_path = $self->param_required('prepped_maf_file');

    my($prepped_maf_file_name, $maf_parent_dir) = fileparse($prepped_maf_file_path);
    $self->param('maf_parent_dir', $maf_parent_dir);

    my $temp_dir = tempdir( CLEANUP => 1, DIR => $self->worker_temp_directory );
    my $temp_prepped_maf_file_path = catfile($temp_dir, $prepped_maf_file_name);

    my $mapping_tsv = catfile($temp_dir, 'mapping.tsv');
    my $reverse_mapping_tsv = catfile($temp_dir, 'revmap.tsv');
    my @hal_mapping_files;
    my @mapping_lines;
    my @revmap_lines;
    foreach my $idx (0 .. $#target_genomes) {
        my @row = ($target_genomes[$idx], 'genome' . $idx);
        push(@mapping_lines, join("\t", @row));
        push(@revmap_lines, join("\t", reverse @row));

        my $hal_mapping_file = catfile($hal_mapping_dir, $target_genomes[$idx] . '.hal_mapping.tsv');
        push(@hal_mapping_files, $hal_mapping_file);
    }
    $self->_spurt($mapping_tsv, join("\n", @mapping_lines));
    $self->_spurt($reverse_mapping_tsv, join("\n", @revmap_lines));

    print STDERR "Processing raw Cactus MAF file: $dumped_maf_file\n" if($self->debug);
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

    print STDERR "Sanitising genome names in filtered MAF: $filtered_maf\n" if($self->debug);
    my $sanitised_maf = catfile($temp_dir, 'sanitised.maf');
    my $cmd4_args = [
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
    $self->run_command($cmd4_args, { die_on_failure => 1 });

    print STDERR "Deduplicating sanitised MAF: $sanitised_maf\n" if($self->debug);
    my $deduped_maf = catfile($temp_dir, 'deduped.maf');
    my $cmd5 = "$maf_duplicate_filter_exe --keep-first --maf $sanitised_maf > $deduped_maf";
    $self->run_command($cmd5, { die_on_failure => 1 });

    print STDERR "Restoring genome names in deduplicated MAF: $deduped_maf\n" if($self->debug);
    my $renamed_maf = catfile($temp_dir, 'renamed.maf');
    my $cmd6_args = [
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
    $self->run_command($cmd6_args, { die_on_failure => 1 });

    print STDERR "Further processing MAF: $renamed_maf\n" if($self->debug);
    my $reprocessed_maf = catfile($temp_dir, 'reprocessed.maf');
    my $cmd7_args = [
        $process_cactus_maf_exe,
        $renamed_maf,
        $reprocessed_maf,
        '--min-block-cols',
        1,
        '--min-seq-length',
        1,
    ];
    $self->run_command($cmd7_args, { die_on_failure => 1 });

    print STDERR "Left-aligning Cactus MAF file: $filtered_maf\n" if($self->debug);
    my $left_aligned_maf = catfile($temp_dir, 'left_aligned.maf');
    my $cmd2_args = [
        $left_align_maf_exe,
        $reprocessed_maf,
        $left_aligned_maf,
    ];
    $self->run_command($cmd2_args, { die_on_failure => 1 });

    print STDERR "Relabelling sequences in MAF: $reprocessed_maf\n" if($self->debug);
    my @maf_src_map_params = map { ('--src-map-file', $_) } @hal_mapping_files;
    my $relabelled_maf = catfile($temp_dir, 'relabelled.maf');
    my $cmd8_args = [
        $map_maf_src_field_exe,
        $left_aligned_maf,
        $relabelled_maf,
        @maf_src_map_params,
    ];
    $self->run_command($cmd8_args, { die_on_failure => 1 });

    print STDERR "Splitting MAF into ungapped blocks: $relabelled_maf\n" if($self->debug);
    my $temp_dataflow_file = catfile($temp_dir, 'dataflow.json');
    my $cmd9_args = [
        $split_maf_on_gaps_exe,
        $relabelled_maf,
        $temp_prepped_maf_file_path,
        '--dataflow-file',
        $temp_dataflow_file,
    ];
    $self->run_command($cmd9_args, { die_on_failure => 1 });

    print STDERR "Extracting stats from $temp_dataflow_file\n" if($self->debug);
    my ($dataflow_event, @surplus_events) = split(/\n/, $self->_slurp($temp_dataflow_file));

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

    $self->param('temp_prepped_maf_file_path', $temp_prepped_maf_file_path);
}


sub write_output {
    my $self = shift;

    my $hal_chunk_index = $self->param_required('hal_chunk_index');
    my $maf_parent_dir = $self->param_required('maf_parent_dir');
    my $temp_prepped_maf_file_path = $self->param_required('temp_prepped_maf_file_path');
    my $prepped_maf_file_path = $self->param_required('prepped_maf_file');
    my $maf_block_count = $self->param_required('maf_block_count');
    my $maf_seq_count = $self->param_required('maf_seq_count');

    my @output_cmds = (
        "mkdir -p $maf_parent_dir",
        "mv $temp_prepped_maf_file_path $prepped_maf_file_path",
    );

    foreach my $cmd (@output_cmds) {
        $self->run_command($cmd, { die_on_failure => 1 });
    }

    my $output_id = {
        'hal_chunk_index' => $hal_chunk_index,
        'maf_block_count' => $maf_block_count,
        'maf_seq_count'   => $maf_seq_count,
        'maf_file'        => $prepped_maf_file_path,
    };

    $self->dataflow_output_id($output_id, 2);
}


1;
