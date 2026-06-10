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

Bio::EnsEMBL::Compara::RunnableDB::HAL::ChainToBigChain

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::ChainToBigChain;

use strict;
use warnings;

use File::Copy qw(move);
use File::Basename qw(fileparse);
use File::Path qw(make_path);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub pre_cleanup {
    my $self = shift;

    my $bigchain_file = $self->param_required('bigchain_file');

    my $cmd = "rm -f $bigchain_file";

    $self->run_command($cmd, { die_on_failure => 1 });
}


sub run {
    my $self = shift;

    my $big_bed_exe = $self->require_executable('big_bed_exe');
    my $chain_to_big_chain_exe = $self->require_executable('chainToBigChain_exe');
    my $hal_stats_exe = $self->require_executable('halStats_exe');
    my $map_maf_src_field_exe = $self->require_executable('map_maf_src_field_exe');
    my $validateFiles_exe = $self->require_executable('validateFiles_exe');

    my $bigchain_autosql = $self->param_required('bigchain_autosql');

    my $hal_file = $self->param('hal_file');
    my $hal_mapping_dir = $self->param_required('hal_mapping_dir');
    my $chain_target_hal_genome = $self->param_required('chain_target_hal_genome');
    my $target_hal_mapping_file = catfile($hal_mapping_dir, $chain_target_hal_genome . '.hal_mapping.tsv');

    $self->warning("Loading target HAL mapping ...");
    my %target_seq_map;
    open(my $fh, '<', $target_hal_mapping_file) or die "Cannot read $target_hal_mapping_file";
    my $header = <$fh>;
    chomp($header);
    my @head_cols = split(/\t/, $header);
    while( my $line = <$fh> ) {
        chomp($line);
        my $row = map_row_to_header( $line, \@head_cols );
        if ($row->{'hal_genome_name'} eq $chain_target_hal_genome) {
            my $hal_seq_name = $row->{'hal_sequence_name'};
            my $ens_seq_name = $row->{'assembly_sequence'};
            $target_seq_map{$hal_seq_name} = $ens_seq_name;
        }
    }
    close($fh);

    my $bigchain_file_path = $self->param_required('bigchain_file');
    my ($output_bigchain_file_name, $output_bigchain_dir) = fileparse($bigchain_file_path);

    $self->param('bigchain_parent_dir', $output_bigchain_dir);
    my $temp_dir = tempdir( CLEANUP => 1, DIR => $self->worker_temp_directory );
    my $temp_bigchain_file_path = catfile($temp_dir, $output_bigchain_file_name);
    my $temp_bigchain_autosql = catfile($temp_dir, 'bigChain.as');

    $self->warning("Fetching bigChain.as ...");
    my $cmd1_args = ['wget', $bigchain_autosql, '--quiet', '--output-document', $temp_bigchain_autosql];
    $self->run_command($cmd1_args, { die_on_failure => 1 });

    $self->warning("Creating target chromSizes file ...");
    my $temp_target_chrom_sizes_file_path = catfile($temp_dir, 'target.chrom.sizes');
    my $cmd3_args = [$hal_stats_exe, '--chromSizes', $chain_target_hal_genome, $hal_file];
    my $hal_chrom_size_text = $self->get_command_output($cmd3_args, { die_on_failure => 1 });

    my @maf_chrom_size_lines;
    open(my $fh, '<', \$hal_chrom_size_text);
    while( my $line = <$fh> ) {
        chomp($line);
        my ($hal_seq_name, $seq_size) = split(/\t/, $line);
        if (exists $target_seq_map{$hal_seq_name}) {
            my $maf_seq_name = $target_seq_map{$hal_seq_name};
            push(@maf_chrom_size_lines, join("\t", ($maf_seq_name, $seq_size)));
        }
    }
    close($fh);
    my $maf_chrom_size_text = join("\n", @maf_chrom_size_lines);
    $self->_spurt($temp_target_chrom_sizes_file_path, $maf_chrom_size_text);

    my $chain_file_path = $self->param_required('chain_file');

    $self->warning("Creating preliminary bigChain files ...");
    my $prelim_bigchain_file_path = catfile($temp_dir, 'bigChain.pre');  # intermediate BED file
    my $cmd2_args = [
        $chain_to_big_chain_exe,
        $chain_file_path,
        $prelim_bigchain_file_path,
        '/dev/null',
    ];
    $self->run_command($cmd2_args, { die_on_failure => 1 });

    $self->warning("Creating bigChain file ...");
    my $cmd3_args = [
        $big_bed_exe,
        '-type=bed6+6',
        '-as=' . $temp_bigchain_autosql,
        '-tab',
        $prelim_bigchain_file_path,
        $temp_target_chrom_sizes_file_path,
        $temp_bigchain_file_path,
    ];
    $self->run_command($cmd3_args, { die_on_failure => 1 });

    $self->warning("Validating bigChain file ...");
    my $cmd4_args = [
        $validateFiles_exe,
        '-chromInfo=' . $temp_target_chrom_sizes_file_path,
        '-type=bigBed6+6',
        '-as=' . $temp_bigchain_autosql,
        '-tab',
        $temp_bigchain_file_path,
    ];
    $self->run_command($cmd4_args, { die_on_failure => 1 });

    $self->param('temp_bigchain_file_path', $temp_bigchain_file_path);
}


sub write_output {
    my $self = shift;

    my $bigchain_parent_dir = $self->param_required('work_dir');
    make_path($bigchain_parent_dir);

    my $temp_bigchain_file_path = $self->param_required('temp_bigchain_file_path');
    my $bigchain_file_name = $self->param_required('bigchain_file');
    my $bigchain_file_path = catfile($bigchain_parent_dir, $bigchain_file_name);
    move($temp_bigchain_file_path, $bigchain_file_path);
}


1;
