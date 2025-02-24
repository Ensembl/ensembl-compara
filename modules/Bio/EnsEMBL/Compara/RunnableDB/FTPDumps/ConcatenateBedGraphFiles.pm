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

Bio::EnsEMBL::Hive::RunnableDB::FTPDumps::ConcatenateBedGraphFiles

=head1 SYNOPSIS

This Runnable concatenates as many bedGraph files as requested into one.
It takes care of removing the track headers from the second file onwards.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConcatenateBedGraphFiles;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(check_for_null_characters check_line_counts get_line_count);
use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Hive::Process');


sub param_defaults {
    return {
        'healthcheck_list' => [],
    };
}

sub fetch_input {
    my $self = shift;

    # for some reason, all_bedgraph_files can contain undefs - filter them out
    my @input_bedgraph_files = grep { defined $_ } @{$self->param_required('all_bedgraph_files')};

    my $healthcheck_list = destringify($self->param_required('healthcheck_list'));
    if (grep { $_ eq 'line_count' } @{$healthcheck_list}) {

        my $exp_line_count = 0;
        foreach my $input_bedgraph_file ( @input_bedgraph_files ) {
            $exp_line_count += get_line_count($input_bedgraph_file) - 1  # excl header line
        }

        $self->param('exp_line_count', $exp_line_count);
    }

    $self->param('input_bedgraph_files', \@input_bedgraph_files);
}

sub run {
    my $self = shift;

    my $output_file = $self->param_required('bedgraph_file');
    unlink $output_file;

    my @all_bedgraph_files = @{$self->param_required('input_bedgraph_files')};

    $self->run_system_command(['cp', shift @all_bedgraph_files, $output_file], { die_on_failure => 1 });

    foreach my $input_file ( @all_bedgraph_files ) {
        $self->run_system_command("tail -n+2 '$input_file' >> '$output_file'", { die_on_failure => 1 });
    }

    if ($self->param_is_defined('healthcheck_list')) {
        $self->_healthcheck();
    }
}

sub _healthcheck {
    my $self = shift;

    my $healthcheck_list = destringify($self->param('healthcheck_list'));
    my $output_file = $self->param('bedgraph_file');

    foreach my $hc_type (@{$healthcheck_list}) {
        if ( $hc_type eq 'line_count' ) {
            my $exp_line_count = $self->param_required('exp_line_count') + 1; # incl header line
            check_line_counts($output_file, $exp_line_count);
        } elsif ( $hc_type eq 'unexpected_nulls' ) {
            check_for_null_characters($output_file);
        } else {
            $self->die_no_retry("Healthcheck type '$hc_type' not recognised");
        }
    }
}


1;
