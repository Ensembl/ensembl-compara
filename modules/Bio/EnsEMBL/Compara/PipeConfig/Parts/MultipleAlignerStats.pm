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

Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats

=head1 DESCRIPTION

Set of analyses to compute statistics on a multiple-alignment database.
It is supposed to be embedded in pipelines.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN
 
sub pipeline_analyses_multiple_aligner_stats {
    my ($self) = @_;
    return [
        {   -logic_name => 'multiplealigner_stats_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                '2->A' => { 'multiplealigner_stats' => INPUT_PLUS() },
                'A->1' => [ 'block_size_distribution' ],
                    1  => [ 'gab_factory' ],
            },
        },

        {   -logic_name => 'multiplealigner_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerStats',
            -parameters => {
                'dump_features'     => $self->o('dump_features_exe'),
                'compare_beds'      => $self->o('compare_beds_exe'),
                'bed_dir'           => $self->o('bed_dir'),
                'ensembl_release'   => $self->o('ensembl_release'),
                'output_dir'        => $self->o('output_dir'),
            },
            -rc_name => '4Gb_job',
            -hive_capacity  => 100,
        },

        {   -logic_name => 'block_size_distribution',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerBlockSize',
            -flow_into  => [ 'generate_msa_stats_report' ],
        },

        {   -logic_name => 'generate_msa_stats_report',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::StatsReport',
            -parameters => {
                'stats_exe'            => $self->o('msa_stats_report_exe'),
                'msa_stats_shared_dir' => $self->o('msa_stats_shared_dir'),
            },
        },

        {   -logic_name => 'gab_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'contiguous'  => 0,
                            'step'        => 50,
                            'inputquery'  => 'SELECT DISTINCT genomic_align_block_id FROM genomic_align WHERE method_link_species_set_id = #mlss_id# AND dnafrag_id < 10000000000',
                        },
            -rc_name    => '4Gb_job',
            -flow_into  => {
                '2->A' => { 'per_block_stats' => { 'genomic_align_block_ids' => '#_range_list#' } },
                '1->A' => ['genome_db_factory'],
                'A->1' => ['block_stats_aggregator']
                },
        },

        {   -logic_name => 'genome_db_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT genome_db_id, method_link_species_set_id FROM method_link_species_set JOIN species_set USING (species_set_id) WHERE method_link_species_set_id = #mlss_id#',
            },
            -flow_into  => {
                2 => [ 'genome_length_fetcher' ],
            },
        },

        {   -logic_name => 'genome_length_fetcher',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT SUM(length) AS genome_length FROM dnafrag WHERE genome_db_id = #genome_db_id# AND is_reference = 1',
            },
            -flow_into  => {
                2 => [ '?accu_name=genome_length&accu_address={genome_db_id}' ],
            },
            -hive_capacity  => 1000,
        },

        {   -logic_name =>  'per_block_stats',
            -module     =>  'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::CalculateBlockStats',
            -rc_name    => '2Gb_job',
            -flow_into  => {
                2 => [
                    '?accu_name=num_of_positions&accu_address={genome_db_id}[]',
                    '?accu_name=num_of_aligned_positions&accu_address={genome_db_id}[]',
                    '?accu_name=num_of_other_seq_positions&accu_address={genome_db_id}[]',
                ],
                3 => [
                    '?accu_name=depth_by_genome&accu_address={genome_db_id}{depth}[]&accu_input_variable=num_of_positions',
                ],
                4 => [
                    '?accu_name=pairwise_coverage&accu_address={from_genome_db_id}{to_genome_db_id}[]&accu_input_variable=num_of_aligned_positions',
                ],
            },
            -hive_capacity  => 1000,
        },

        {   -logic_name => 'block_stats_aggregator',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::BlockStatsAggregator',
            -rc_name    => '8Gb_job',
        },

    ];
}

1;
