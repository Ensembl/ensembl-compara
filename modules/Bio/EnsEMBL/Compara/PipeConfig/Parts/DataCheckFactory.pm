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

Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory

=head1 DESCRIPTION

    This is a part of the DataCheck pipeline containing the datacheck analyses

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # For WHEN and INPUT_PLUS
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFan;

sub pipeline_analyses_datacheck_factory {
    my ($self) = @_;

    return [

        {
            -logic_name        => 'datacheck_factory',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFactory',
            -analysis_capacity => 10,
            -max_retry_count   => 0,
            -flow_into         => {
                '2->A' => { 'datacheck_fan' => INPUT_PLUS() },
                'A->1' => [ 'datacheck_funnel' ],
            },
        },

        {
            -logic_name        => 'datacheck_funnel',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::DataCheckFunnel',
            -analysis_capacity => 1,
            -batch_size        => 100,
            -max_retry_count   => 0,
            -rc_name           => '2Gb_job',
            -flow_into         => [ 'store_results' ],
        },

        {
            -logic_name        => 'store_results',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::StoreResults',
            -analysis_capacity => 10,
            -max_retry_count   => 1,
            -flow_into         => {
                '3' => [ '?table_name=datacheck_results' ],
                '4' => [ 'email_report' ],
            },
        },

        {
            -logic_name        => 'email_report',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailReport',
            -analysis_capacity => 10,
            -batch_size        => 100,
            -max_retry_count   => 0,
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFan::pipeline_analyses_datacheck_fan($self) },

    ];
}

1;
