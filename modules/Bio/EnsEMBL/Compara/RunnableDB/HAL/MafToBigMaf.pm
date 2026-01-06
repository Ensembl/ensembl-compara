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

Bio::EnsEMBL::Compara::RunnableDB::HAL::MafToBigMaf

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::MafToBigMaf;

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

    my $output_bigmaf_file = $self->param_required('output_bigmaf_file');

    my @cmds = (
        "rm -f $output_bigmaf_file",
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
}


sub run {
    my $self = shift;

    my $maf_to_big_maf_exe = $self->require_executable('mafToBigMaf_exe');
    my $hal_stats_exe = $self->require_executable('halStats_exe');
    my $bigmaf_autosql = $self->param_required('bigmaf_autosql');

    my $hal_file = $self->param('hal_file');
    my $output_maf_file_name = $self->param_required('output_maf_file');
    my $work_dir = $self->param_required('work_dir');
    my $output_maf_file_path = catfile($work_dir, $output_maf_file_name);

    my $ref_hal_genome = $self->param_required('ref_hal_genome');
    my $hal_mapping_dir = $self->param_required('hal_mapping_dir');
    my $hal_mapping_file = catfile($hal_mapping_dir, $ref_hal_genome . '.hal_mapping.tsv');

    my %ref_seq_map;
    my $assembly_uuid;
    open(my $fh, '<', $hal_mapping_file) or die "Cannot read $hal_mapping_file";
    my $header = <$fh>;
    chomp($header);
    my @head_cols = split(/\t/, $header);
    my @current_homologs;
    while( my $line = <$fh> ) {
        chomp($line);
        my $row = map_row_to_header( $line, \@head_cols );
        if ($row->{'hal_genome_name'} eq $ref_hal_genome) {
            $assembly_uuid = $row->{'assembly_uuid'} unless defined $assembly_uuid;

            my $hal_seq_name = $row->{'hal_sequence_name'};
            my $ens_seq_name = $row->{'assembly_sequence'};
            $ref_seq_map{$hal_seq_name} = $ens_seq_name;
        }
    }
    close($fh);

    my $output_bigmaf_file_path = $self->param_required('output_bigmaf_file');

    my($output_bigmaf_file_name, $output_bigmaf_dir) = fileparse($output_bigmaf_file_path);
    $self->param('bigmaf_parent_dir', $output_bigmaf_dir);

    my $temp_dir = tempdir( CLEANUP => 1, DIR => $self->worker_temp_directory );
    my $temp_bigbed_file_path = catfile($temp_dir, 'bigMaf.bb');
    my $temp_bed_file_path = catfile($temp_dir, 'bigMaf.bed');
    my $temp_bigmaf_autosql = catfile($temp_dir, 'bigMaf.as');
    my $temp_chrom_sizes_file_path = catfile($temp_dir, 'ref.chrom.sizes');

    my $cmd1_args = ['wget', $bigmaf_autosql, '--quiet', '--output-document', $temp_bigmaf_autosql];
    $self->run_command($cmd1_args, { die_on_failure => 1 });

    my $cmd2_args = [$hal_stats_exe, '--chromSizes', $ref_hal_genome, $hal_file];
    my $hal_chrom_size_text = $self->get_command_output($cmd2_args, { die_on_failure => 1 });

    my @maf_chrom_size_lines;
    open(my $fh, '<', \$hal_chrom_size_text) or die "Cannot read $hal_mapping_file";
    while( my $line = <$fh> ) {
        chomp($line);
        my ($hal_seq_name, $seq_size) = split(/\t/, $line);
        if (exists $ref_seq_map{$hal_seq_name}) {
            my $maf_seq_name = $ref_seq_map{$hal_seq_name};
            push(@maf_chrom_size_lines, join("\t", ($maf_seq_name, $seq_size)));
        }
    }
    close($fh);
    my $maf_chrom_size_text = join("\n", @maf_chrom_size_lines);
    $self->_spurt($temp_chrom_sizes_file_path, $maf_chrom_size_text);

    my $cmd3_args = [
        $maf_to_big_maf_exe,
        $assembly_uuid,
        $output_maf_file_path,
        $temp_bed_file_path,
    ];
    $self->run_command($cmd3_args, { die_on_failure => 1 });

    my $cmd4_args = [
        'sort',
        '-k1,1',
        '-k2,2n',
        $temp_bed_file_path,
        '-o',
        $temp_bed_file_path,
    ];
    $self->run_command($cmd4_args, { die_on_failure => 1 });


    my $cmd5_args = [
        'bedToBigBed',
        '-type=bed3+1',
        '-as=' . $temp_bigmaf_autosql,
        '-tab',
        $temp_bed_file_path,
        $temp_chrom_sizes_file_path,
        $temp_bigbed_file_path,
    ];
    $self->run_command($cmd5_args, { die_on_failure => 1 });

    $self->param('temp_bigmaf_file_path', $temp_bigbed_file_path);
}


sub write_output {
    my $self = shift;

    my $temp_bigmaf_file_path = $self->param_required('temp_bigmaf_file_path');
    my $bigmaf_parent_dir = $self->param_required('work_dir');
    my $bigmaf_file_name = $self->param_required('output_bigmaf_file');

    my $bigmaf_file_path = catfile($bigmaf_parent_dir, $bigmaf_file_name);

    make_path($bigmaf_parent_dir);
    move($temp_bigmaf_file_path, $bigmaf_file_path);
}


1;
