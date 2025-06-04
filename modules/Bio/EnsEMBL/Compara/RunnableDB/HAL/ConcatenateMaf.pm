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

Bio::EnsEMBL::Compara::RunnableDB::HAL::ConcatenateMaf

=head1 DESCRIPTION

This runnable concatenates many MAF files into one, keeping
comments and metadata from the first of the input MAF files.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::ConcatenateMaf;

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Copy qw(move);
use File::Path qw(make_path);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use List::Util qw(sum);

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(check_for_null_characters);
use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $input_maf_files = $self->param_required('chunked_maf_files');
    my $maf_block_counts = $self->param_required('maf_block_counts');
    my $cat_maf_parent_dir = $self->param_required('work_dir');
    my $cat_maf_file_name = $self->param_required('output_file');

    my ($first_input_maf_file, @other_input_maf_files) = grep { defined $_ } @{$input_maf_files};

    my $temp_dir = tempdir( CLEANUP => 1, DIR => $self->worker_temp_directory );
    my $temp_cat_maf_file_path = catfile($temp_dir, $cat_maf_file_name);

    my $cmd1 = "cp $first_input_maf_file $temp_cat_maf_file_path";
    $self->run_command($cmd1, { die_on_failure => 1 });

    foreach my $other_input_maf_file (@other_input_maf_files) {
        my $cmd2 = "grep -v '^#' $other_input_maf_file >> $temp_cat_maf_file_path";
        $self->run_command($cmd2, { die_on_failure => 1 });
    }

    my $exp_maf_block_count = sum(@{$maf_block_counts});

    $self->param('exp_maf_block_count', $exp_maf_block_count);
    $self->param('temp_cat_maf_file_path', $temp_cat_maf_file_path);
}


sub write_output {
    my $self = shift;

    my $temp_cat_maf_file_path = $self->param_required('temp_cat_maf_file_path');
    my $cat_maf_parent_dir = $self->param_required('work_dir');
    my $cat_maf_file_name = $self->param_required('output_file');

    my $cat_maf_file_path = catfile($cat_maf_parent_dir, $cat_maf_file_name);

    if ( $self->param_is_defined('healthcheck_list') ) {
        $self->_healthcheck();
    }

    make_path($cat_maf_parent_dir);
    move($temp_cat_maf_file_path, $cat_maf_file_path);
}


sub _healthcheck {
    my $self = shift;

    my $healthcheck_list = destringify($self->param_required('healthcheck_list'));
    my $temp_cat_maf_file_path = $self->param('temp_cat_maf_file_path');

    foreach my $hc_type (@{$healthcheck_list}) {
        if ( $hc_type eq 'maf_block_count' ) {

            my $maf_block_count_cmd = "grep -c '^a' $temp_cat_maf_file_path";
            my $run_cmd = $self->run_command($maf_block_count_cmd);
            $run_cmd->die_with_log() if $run_cmd->exit_code >= 2;
            my ($obs_maf_block_count) = split(/\n/, $run_cmd->out);

            my $exp_maf_block_count = $self->param_required('exp_maf_block_count');
            if ($obs_maf_block_count != $exp_maf_block_count) {
                $self->die_no_retry(
                    sprintf(
                        "Number of MAF blocks in concatenated file is %d but should be %d",
                        $obs_maf_block_count,
                        $exp_maf_block_count,
                    )
                );
            }

        } elsif ( $hc_type eq 'unexpected_nulls' ) {
            check_for_null_characters($temp_cat_maf_file_path);
        } else {
            $self->die_no_retry("Healthcheck type '$hc_type' not recognised");
        }
    }
}


1;
