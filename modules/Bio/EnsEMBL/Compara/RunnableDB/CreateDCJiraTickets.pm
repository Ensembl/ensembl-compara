=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

sub run {
    my $self = shift;

    my $jira_exe = $self->param_required('create_datacheck_tickets_exe');

    my $command = $jira_exe . ' ' . $self->param_required('output_results') . " --update";
    $self->warning( "Command: " . $command );

    unless ( $self->param('dry_run') ) {
        if (defined $ENV{'USERPW'}) {
            $self->run_command($command, { die_on_failure => 1, });
        }
        else {
            $self->warning( "ENV variable not defined: \$USERPW" );
        }
    }

}

1;
