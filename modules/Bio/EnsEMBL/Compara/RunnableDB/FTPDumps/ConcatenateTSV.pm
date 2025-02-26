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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConcatenateTSV

=head1 DESCRIPTION

This runnable concatenates many TSV files into one,
keeping the header from the first input TSV file only.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConcatenateTSV;

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Copy qw(move);
use File::Path qw(make_path);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(check_for_null_characters check_line_counts);
use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $input_tsv_files = $self->param_required('tsv_files');

    my ($first_input_tsv_file, @other_input_tsv_files) = grep { defined $_ } @{$input_tsv_files};
    my $cat_tsv_file_path = $self->param_required('output_file');

    my($cat_tsv_file_name, $cat_tsv_parent_dir) = fileparse($cat_tsv_file_path);

    my $temp_dir = tempdir( CLEANUP => 1, DIR => $self->worker_temp_directory );
    my $temp_cat_tsv_file_path = catfile($temp_dir, $cat_tsv_file_name);

    my $cmd1 = "cp $first_input_tsv_file $temp_cat_tsv_file_path";
    $self->run_command($cmd1, { die_on_failure => 1 });

    foreach my $other_input_tsv_file (@other_input_tsv_files) {
        my $cmd2 = "tail -n +2 $other_input_tsv_file >> $temp_cat_tsv_file_path";
        $self->run_command($cmd2, { die_on_failure => 1 });
    }

    $self->param('temp_cat_tsv_file_path', $temp_cat_tsv_file_path);
    $self->param('cat_tsv_parent_dir', $cat_tsv_parent_dir);
}


sub write_output {
    my $self = shift;

    my $temp_cat_tsv_file_path = $self->param_required('temp_cat_tsv_file_path');
    my $cat_tsv_parent_dir = $self->param_required('cat_tsv_parent_dir');
    my $cat_tsv_file_path = $self->param_required('output_file');

    if ( $self->param_is_defined('healthcheck') || $self->param_is_defined('healthcheck_list') ) {
        $self->_healthcheck();
    }

    make_path($cat_tsv_parent_dir);
    move($temp_cat_tsv_file_path, $cat_tsv_file_path);
}


sub _healthcheck {
    my $self = shift;

    my $temp_cat_csv_file_path = $self->param('temp_cat_tsv_file_path');

    my $healthcheck_list;
    if ( $self->param_is_defined('healthcheck') && $self->param_is_defined('healthcheck_list') ) {
        $self->throw("Only one of parameters 'healthcheck' or 'healthcheck_list' can be defined")
    } elsif ( $self->param_is_defined('healthcheck') ) {
        $healthcheck_list = [$self->param('healthcheck')];
    } elsif ( $self->param_is_defined('healthcheck_list') ) {
        $healthcheck_list = destringify($self->param('healthcheck_list'));
    } else {
        $self->throw("One of parameters 'healthcheck' or 'healthcheck_list' must be defined")
    }

    foreach my $hc_type (@{$healthcheck_list}) {
        if ( $hc_type eq 'line_count' ) {
            my $exp_line_count = $self->param_required('exp_line_count') + 1; # incl header line
            check_line_counts($temp_cat_csv_file_path, $exp_line_count);
        } elsif ( $hc_type eq 'unexpected_nulls' ) {
            check_for_null_characters($temp_cat_csv_file_path);
        } else {
            $self->die_no_retry("Healthcheck type '$hc_type' not recognised");
        }
    }
}


1;
