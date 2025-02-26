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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::InitDumpRegistry

=head1 DESCRIPTION

A small runnable to initialise a static Compara FTP dump registry,
then log its contents.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::InitDumpRegistry;

use strict;
use warnings;

use JSON;

use base ('Bio::EnsEMBL::Compara::RunnableDB::LogRegistry');


sub run {
    my $self = shift;

    my @cmd_args = (
        $self->param_required('init_dump_registry_exe'),
        '--division',
        $self->param_required('division'),
        '--release',
        $self->param_required('curr_release'),
        '--outfile',
        $self->param_required('reg_conf'),
    );

    my @optional_param_names = (
        'compara_db',
        'ancestral_db',
        'compara_dump_host',
        'ancestral_dump_host',
        'core_dump_hosts',
    );

    foreach my $param_name (@optional_param_names) {
        if ($self->param_is_defined($param_name)) {
            push(@cmd_args, ('--' . $param_name, $self->param($param_name)));
        }
    }

    $self->run_command(\@cmd_args, { die_on_failure => 1 });
}


1;
