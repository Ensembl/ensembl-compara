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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::HMMOverlapParser_conf

=head1 DESCRIPTION

Pipeline to recursively parse and reduce the output of the HMMER searches
to extract overlap between clusters. The actual overlep is computed in a
separate script.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::HMMOverlapParser_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'read_file',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMOverlapFactory',
            -parameters => {
                'chunk_list'    => $self->o('chunk_list'),
                'work_dir'      => $self->o('work_dir'),
                'output_dir'    => $self->o('output_dir'),
                'n'             => $self->o('n'),
                'anaysis_name_recursive'    => 'run_cmd',
            },
            -input_ids  => [
                {
                    'label'         => $self->o('label'),
                },
            ],
            -flow_into => {
                99 => 'run_cmd',
            },
        },

        {   -logic_name    => 'run_cmd',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMOverlapSystemCmd',
            -parameters    => {
                'script' => $self->o('script'),
                'script_args'   => [],
            },
        },

    ];
}

1;

