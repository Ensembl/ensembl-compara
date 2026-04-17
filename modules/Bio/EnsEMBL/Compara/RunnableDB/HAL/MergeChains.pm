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

Bio::EnsEMBL::Compara::RunnableDB::HAL::MergeChains

=head1 DESCRIPTION

This runnable merges many chain files into one.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::MergeChains;

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
use Bio::EnsEMBL::Utils::IO qw(spurt);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub pre_cleanup {
    my $self = shift;

    my $merged_chain_file = $self->param_required('merged_chain_file');

    my $cmd = "rm -f $merged_chain_file";

    $self->run_command($cmd, { die_on_failure => 1 });
}


sub run {
    my $self = shift;

    my $input_chain_files = $self->param_required('chunked_chain_files');
    my $chain_counts = $self->param_required('chain_counts');
    my $merged_chain_file_path = $self->param_required('merged_chain_file');
    my $merge_chain_files_exe = $self->require_executable('merge_chain_files_exe');

    my($merged_chain_file_name, $merged_chain_parent_dir) = fileparse($merged_chain_file_path);

    my $temp_dir = tempdir( CLEANUP => 1, DIR => $self->worker_temp_directory );

    my $temp_chain_list_file_path = catfile($temp_dir, 'chains.txt');
    my @chain_list = grep { defined $_ } @{$input_chain_files};
    my $chain_list_text = join("\n", @chain_list) . "\n";
    spurt($temp_chain_list_file_path, $chain_list_text);

    my $temp_merged_chain_file_path = catfile($temp_dir, $merged_chain_file_name);
    my $cmd = "$merge_chain_files_exe $temp_chain_list_file_path $temp_merged_chain_file_path";
    $self->run_command($cmd, { die_on_failure => 1 });

    $self->param('temp_merged_chain_file_path', $temp_merged_chain_file_path);

    my $obs_chain_count = $self->_get_chain_count($temp_merged_chain_file_path);
    $self->param('obs_chain_count', $obs_chain_count);

    my $exp_chain_count = sum(@{$chain_counts});
    $self->param('exp_chain_count', $exp_chain_count);

    if ( $self->param_is_defined('healthcheck_list') ) {
        $self->_healthcheck();
    }
}


sub write_output {
    my $self = shift;

    my $temp_merged_chain_file_path = $self->param_required('temp_merged_chain_file_path');
    my $merged_chain_file_path = $self->param_required('merged_chain_file');

    my($merged_chain_file_name, $merged_chain_parent_dir) = fileparse($merged_chain_file_path);

    if ( $self->param_is_defined('healthcheck_list') ) {
        $self->_healthcheck();
    }

    make_path($merged_chain_parent_dir);
    move($temp_merged_chain_file_path, $merged_chain_file_path);
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
    my $temp_merged_chain_file_path = $self->param('temp_merged_chain_file_path');

    foreach my $hc_type (@{$healthcheck_list}) {
        if ( $hc_type eq 'chain_count' ) {

            my $exp_chain_count = $self->param_required('exp_chain_count');
            my $obs_chain_count = $self->param_required('obs_chain_count');
            if ($obs_chain_count != $exp_chain_count) {
                $self->die_no_retry(
                    sprintf(
                        "Number of chains in merged file is %d but should be %d",
                        $obs_chain_count,
                        $exp_chain_count,
                    )
                );
            }

        } elsif ( $hc_type eq 'unexpected_nulls' ) {
            check_for_null_characters($temp_merged_chain_file_path);
        } else {
            $self->die_no_retry("Healthcheck type '$hc_type' not recognised");
        }
    }
}


1;
