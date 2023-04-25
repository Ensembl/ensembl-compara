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

Bio::EnsEMBL::Compara::PipeConfig::HalPerSeqChunkCoverage_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::HalPerSeqChunkCoverage_conf \
        -host mysql-ens-compara-prod-X -port XXXX -division $COMPARA_DIV -mlss_id <mlss_id>

=head1 DESCRIPTION

Pipeline to calculate HAL genomic coverage by sequence chunk.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::HalPerSeqChunkCoverage_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        'master_db' => 'compara_master',
    };
}


sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'master_db' => $self->o('master_db'),
        'mlss_id'   => $self->o('mlss_id'),
    };
}


sub pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'copy_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithFK',
            -parameters => {
                'db_conn'                    => '#master_db#',
                'method_link_species_set_id' => '#mlss_id#',
            },
            -input_ids  => [ {
                'mlss_id' => $self->o('mlss_id')
            } ],
            -flow_into  => [ 'load_component_genomedb_factory' ],
        },

        {   -logic_name => 'load_component_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'                  => '#master_db#',
                'expand_polyploid_components' => 1,
                'component_genomes'           => 1,
                'normal_genomes'              => 0,
                'polyploid_genomes'           => 0,
            },
            -rc_name    => '4Gb_job',
            -flow_into  => {
                '2->A'  => {
                    'load_component_genomedb' => { 'master_dbID' => '#genome_db_id#' },
                },
                'A->1'  => [ 'copy_dnafrag_genomedb_factory' ],
            },
        },

        {   -logic_name      => 'load_component_genomedb',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -batch_size      => 10,
            -hive_capacity   => 30,
            -max_retry_count => 2,
        },

        {   -logic_name => 'copy_dnafrag_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -rc_name    => '4Gb_job',
            -flow_into  => {
                '2->A'  => [ 'genome_dnafrag_copy' ],
                'A->1'  => [ 'get_hal_mapping' ],
            },
        },

        {   -logic_name => 'genome_dnafrag_copy',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDnaFragsByGenomeDB',
        },

        {   -logic_name     => 'get_hal_mapping',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::GetHalMapping',
            -parameters     => {
                'compara_db' => 'compara_curr',
            },
            -flow_into  => [ 'get_hal_file_path' ],
        },

        {   -logic_name => 'get_hal_file_path',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::GetHalFilePath',
            -flow_into  => [ 'hal_dual_genome_factory' ],
        },

        {   -logic_name => 'hal_dual_genome_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halDualGenomeFactory',
             -flow_into => {
                '3->A'  => [ 'split_hal_genome_names' ],
                'A->2'  => [ 'aggregate_hal_genomic_coverage' ],
            },
        },

        {   -logic_name => 'split_hal_genome_names',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => '#hal_genome_names#',
                'column_names' => ['hal_genome_name'],
            },
            -flow_into  => {
                2 => [ 'hal_seq_chunk_factory' ],
            },
        },

        {   -logic_name => 'hal_seq_chunk_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halSeqChunkFactory',
            -rc_name    => '4Gb_job',
            -parameters => {
                'hal_stats_exe' => $self->o('halStats_exe'),
            },
            -flow_into  => {
                2 => { 'calculate_hal_seq_chunk_coverage' => INPUT_PLUS() },
                3 => [ '?accu_name=hal_sequence_names&accu_address=[]&accu_input_variable=hal_sequence_name' ],
            },
        },

        {   -logic_name        => 'calculate_hal_seq_chunk_coverage',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::CalculateHalSeqChunkCoverage',
            -rc_name           => '8Gb_job',
            -analysis_capacity => 700,
            -parameters        => {
                'hal_cov_one_seq_chunk_exe' => $self->o('hal_cov_one_seq_chunk_exe'),
                'hal_alignment_depth_exe'   => $self->o('halAlignmentDepth_exe'),
            },
            -flow_into => {
                3 => [
                    '?accu_name=num_aligned_positions_by_chunk&accu_address={hal_sequence_name}{chunk_offset}&accu_input_variable=num_aligned_positions',
                    '?accu_name=num_positions_by_chunk&accu_address={hal_sequence_name}{chunk_offset}&accu_input_variable=num_positions',
                ],
            },
        },

        {   -logic_name => 'aggregate_hal_genomic_coverage',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::AggregateHalGenomicCoverage',
            -rc_name    => '4Gb_job',
        },

     ];
}


1;
