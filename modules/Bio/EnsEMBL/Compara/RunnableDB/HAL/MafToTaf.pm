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

Bio::EnsEMBL::Compara::RunnableDB::HAL::MafToTaf

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::MafToTaf;

use strict;
use warnings;

use File::Copy qw(move);
use File::Basename qw(fileparse);
use File::Path qw(make_path);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub pre_cleanup {
    my $self = shift;

    my $output_maf_file = $self->param_required('output_maf_file');
    my $output_taf_file = $self->param_required('output_taf_file');

    my @cmds = (
        "rm -f ${output_taf_file}.tai",
        "rm -f $output_taf_file",
    );

    foreach my $cmd (@cmds) {
        $self->run_command($cmd, { die_on_failure => 1 });
    }
}


sub run {
    my $self = shift;

    my $output_maf_file_name = $self->param_required('output_maf_file');
    my $output_taf_file_name = $self->param_required('output_taf_file');
    my $work_dir = $self->param_required('work_dir');
    my $output_maf_file_path = catfile($work_dir, $output_maf_file_name);
    my $output_taf_file_path = catfile($work_dir, $output_taf_file_name);
    $output_taf_file_path =~ s/\.gz$//;

    my $taffy_exe = $self->require_executable('taffy_exe');

    my($output_taf_text_file_name, $output_taf_dir) = fileparse($output_taf_file_path);
    $self->param('taf_parent_dir', $output_taf_dir);

    my $temp_dir = tempdir( CLEANUP => 1, DIR => $self->worker_temp_directory );
    my $temp_taf_text_file_path = catfile($temp_dir, $output_taf_text_file_name);

    my $cmd1_args = [
        $taffy_exe,
        'view',
        '--inputFile',
        $output_maf_file_path,
        '--outputFile',
        $temp_taf_text_file_path,
    ];
    $self->run_command($cmd1_args, { die_on_failure => 1 });

    my $cmd2_args = [
        'bgzip',
        $temp_taf_text_file_path,
    ];
    $self->run_command($cmd2_args, { die_on_failure => 1 });

    my $temp_taf_gz_file_path = $temp_taf_text_file_path . '.gz';
    my $cmd3_args = [
        $taffy_exe,
        'index',
        '--inputFile',
        $temp_taf_gz_file_path,
    ];
    $self->run_command($cmd3_args, { die_on_failure => 1 });

    $self->param('temp_taf_gz_file_path', $temp_taf_gz_file_path);

    my $temp_taf_tai_file_path = $temp_taf_gz_file_path . '.tai';
    $self->param('temp_tai_file_path', $temp_taf_tai_file_path);
}


sub write_output {
    my $self = shift;

    my $temp_taf_gz_file_path = $self->param_required('temp_taf_gz_file_path');
    my $temp_tai_file_path = $self->param_required('temp_tai_file_path');
    my $taf_parent_dir = $self->param_required('work_dir');
    my $taf_file_name = $self->param_required('output_taf_file');
    my $tai_file_name = $taf_file_name . '.tai';

    my $taf_file_path = catfile($taf_parent_dir, $taf_file_name);
    my $tai_file_path = catfile($taf_parent_dir, $tai_file_name);

    make_path($taf_parent_dir);
    move($temp_taf_gz_file_path, $taf_file_path);
    move($temp_tai_file_path, $tai_file_path);
}


1;
