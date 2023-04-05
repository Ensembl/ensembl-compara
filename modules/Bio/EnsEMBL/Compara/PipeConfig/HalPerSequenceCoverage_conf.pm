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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::HalPerSequenceCoverage_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::HalPerSequenceCoverage_conf \
        -host mysql-ens-compara-prod-X -port XXXX -division $COMPARA_DIV -mlss_id <mlss_id>

=head1 DESCRIPTION

Pipeline to calculate per-sequence genomic coverage of sequences in a HAL file.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::HalPerSequenceCoverage_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        'compara_db' => 'compara_curr',
    };
}


sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'compara_db' => $self->o('compara_db'),
        'mlss_id'   => $self->o('mlss_id'),
    };
}


sub pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'fire_hal_alignment_stats',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -rc_name    => '4Gb_job',
            -input_ids  => [ {} ],
            -flow_into  => {
                '1->A' => [ 'hal_genomedb_factory' ],
                'A->1' => [ 'pipeline_finished' ],
            },
        },

        {   -logic_name => 'hal_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halGenomeDBFactory',
            -rc_name    => '4Gb_job',
            -flow_into  => {
                2 => [ 'hal_sequence_factory' ],
            },
        },

        {   -logic_name => 'hal_sequence_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halSequenceFactory',
            -rc_name    => '4Gb_job',
            -flow_into  => {
                2 => [ 'calculate_hal_sequence_coverage' ],
            },
        },

        {   -logic_name        => 'calculate_hal_sequence_coverage',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::CalculateHalSequenceCoverage',
            -rc_name           => '4Gb_job',
            -analysis_capacity => 200,
            -parameters        => {
                'hal_cov_one_seq_exe' => $self->o('hal_cov_one_seq_exe'),
                'hal_alignment_depth_exe' => $self->o('halAlignmentDepth_exe'),
                'hal_stats_exe' => $self->o('halStats_exe'),
            },
            -flow_into => {
                2 => [
                    '?accu_name=num_aligned_positions_in_sequence&accu_address={hal_genome_name}{hal_sequence_name}[]&accu_input_variable=num_aligned_positions',
                    '?accu_name=num_positions_in_sequence&accu_address={hal_genome_name}{hal_sequence_name}[]&accu_input_variable=num_positions',
                ],
            },
        },

        {   -logic_name => 'pipeline_finished',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

     ];
}


1;
