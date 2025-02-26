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

Bio::EnsEMBL::Compara::RunnableDB::CreateDCJiraTickets

=head1 DESCRIPTION

A compara runnable to run the create_datacheck_tickets.pl in a pipeline

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CreateDCJiraTickets;

use warnings;
use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'merge_ticket_key' => undef,
        'test_mode' => 0,
        'csv_mode' => 0,
    }
}

sub run {
    my $self = shift;

    my $jira_exe = $self->param_required('create_datacheck_tickets_exe');
    my $tap_file = $self->param_required('output_results');

    my $command = join(" ", (
        $jira_exe, $tap_file, "--update",
        "--division", $self->param_required('division'),
        ( $self->param('datacheck_type') ? '--label ' . $self->param('datacheck_type') : '' ),
        ( $self->param('dry_run') ? '--dry_run' : ''),
    ));

    if ($self->param_is_defined('merge_ticket_key')) {
        $command .= ' ' . sprintf('--merge_ticket_key %s', $self->param('merge_ticket_key'));
    }

    if ($self->param('csv_mode')) {
        $command .= ' ' . sprintf('--csv %s.csv', $tap_file);
    }

    $self->warning( "Command: " . $command );

    return if $self->param('test_mode');

    if (defined $ENV{'JIRA_AUTH_TOKEN'} || $self->param('csv_mode')) {
        $self->run_command($command, { die_on_failure => 1, });
    }
    else {
        $self->die_no_retry( "ERROR: ENV variable not defined: \$JIRA_AUTH_TOKEN. Define with:\nexport JIRA_AUTH_TOKEN=$(echo -n 'user:pass' | openssl base64)" );
    }

}

1;
