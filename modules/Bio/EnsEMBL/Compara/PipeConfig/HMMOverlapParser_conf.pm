
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

