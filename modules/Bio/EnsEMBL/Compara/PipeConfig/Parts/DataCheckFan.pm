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

Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFan

=head1 DESCRIPTION

    This PipeConfig part runs datachecks in parallel

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFan;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # For WHEN and INPUT_PLUS

sub pipeline_analyses_datacheck_fan {
    my ($self) = @_;

    return [
        {
            -logic_name        => 'datacheck_fan',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -analysis_capacity => 100,
            -max_retry_count   => 0,
            -rc_name           => '1Gb_24_hour_job',
            -flow_into         => {
                '1'  => [ '?accu_name=results&accu_address=[]' ],
                '-1' => [ 'datacheck_fan_high_mem' ],
                '2'  => [
                    WHEN( '#do_jira_ticket_creation#' => 'jira_ticket_creation' )
                ],
            },
            -rc_name           => '1Gb_24_hour_job',
        },

        {
            -logic_name        => 'datacheck_fan_high_mem',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -analysis_capacity => 100,
            -max_retry_count   => 0,
            -rc_name           => '8Gb_24_hour_job',
            -flow_into         => {
                '1' => [ '?accu_name=results&accu_address=[]' ],
                '2' => [
                    WHEN( '#do_jira_ticket_creation#' => 'jira_ticket_creation' )
                ],
            },
        },

        {
            -logic_name        => 'jira_ticket_creation',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::CreateDCJiraTickets',
            -parameters        => {
                release                      => '#ensembl_release#',
                update                       => 1,
                create_datacheck_tickets_exe => $self->o('create_datacheck_tickets_exe'),
            },
            -analysis_capacity => 1,
            -max_retry_count   => 0,
        },
    ];
}

1;
