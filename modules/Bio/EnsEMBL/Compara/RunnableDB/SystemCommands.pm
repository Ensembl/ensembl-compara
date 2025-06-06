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

Bio::EnsEMBL::Compara::RunnableDB::SystemCommands

=head1 DESCRIPTION

A runnable inheriting from SystemCmd, with two key differences:
1) it takes an arrayref of commands instead of a string; and
2) it does pre-cleanup of the dataflow file, if specified.

As in SystemCmd, parameters are shared across all commands.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SystemCommands;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');


sub pre_cleanup {
    my $self = shift;

    if ($self->param_is_defined('dataflow_file')) {
        my $cmd = sprintf('rm -f %s', $self->param('dataflow_file'));
        $self->run_system_command($cmd, { die_on_failure => 1 });
    }
}


sub run {
    my $self = shift;

    my $commands = $self->param_required('commands');

    my %transferred_options = map {$_ => $self->param($_)} qw(use_bash_pipefail use_bash_errexit timeout);

    my ($return_value, $stderr, $flat_cmd, $stdout, $runtime_msec);
    foreach my $command (@{$commands}) {
        ($return_value, $stderr, $flat_cmd, $stdout, $runtime_msec) = $self->run_system_command($command, \%transferred_options);
        last if $return_value;
    }

    # To be used in write_output()
    $self->param('return_value', $return_value);
    $self->param('stderr', $stderr);
    $self->param('flat_cmd', $flat_cmd);
    $self->param('stdout', $stdout);
    $self->param('runtime_msec', $runtime_msec);
}


1;
