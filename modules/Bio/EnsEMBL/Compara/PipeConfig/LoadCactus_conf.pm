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

Bio::EnsEMBL::Compara::PipeConfig::LoadCactus_conf

=cut

package Bio::EnsEMBL::Compara::PipeConfig::LoadCactus_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'master_db' => 'compara_master',

        'collection'    => undef,
        'method_type'   => 'CACTUS_DB',
        'pipeline_name' => $self->o('collection') . '_' . $self->o('division') . '_load_cactus_' . $self->o('rel_with_suffix'),

        # pipeline settings
        'chunk_size'        => 500_000,
        'do_alt_mlss'       => 1,
        'maf_dump_capacity' => 150,
        'species_name_mapping' => undef,

         # data directories:
        'work_dir'          => $self->o('pipeline_dir'),
        'dump_dir'          => $self->o('work_dir') . '/' . 'dumps',
        'jobstore_root_dir' => $self->o('work_dir') . '/' . 'jobstores',
        'scratch_dir'       => $ENV{'SCRATCH_PROD'},

        # msa stats options
        'bed_dir'              => $self->o('work_dir').'/bed',
        'feature_dir'          => $self->o('work_dir').'/feature_dump',
        'msa_stats_shared_dir' => $self->o('msa_stats_shared_basedir') . '/' . $self->o('collection') . '/' . $self->o('ensembl_release'),
        'skip_multiplealigner_stats' => 0,
    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},
    };
}


sub pipeline_checks_pre_init {
    my ($self) = @_;

    die "Pipeline parameter 'collection' is undefined, but must be specified" unless $self->o('collection');
}


sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},

        $self->pipeline_create_commands_rm_mkdir(['bed_dir', 'dump_dir', 'feature_dir', 'jobstore_root_dir', 'work_dir']),
        $self->pipeline_create_commands_rm_mkdir(['msa_stats_shared_dir'], undef, 'do not rm'),
    ];
}


sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'bed_dir'                => $self->o('bed_dir'),
        'bedtools_exe'           => $self->o('bedtools_exe'),
        'cactus_hal2maf_exe'     => $self->o('cactus_hal2maf_exe'),
        'do_alt_mlss'            => $self->o('do_alt_mlss'),
        'dump_dir'               => $self->o('dump_dir'),
        'feature_dir'            => $self->o('feature_dir'),
        'halStats_exe'           => $self->o('halStats_exe'),
        'jobstore_root_dir'      => $self->o('jobstore_root_dir'),
        'master_db'              => $self->o('master_db'),
        'msa_stats_shared_dir'   => $self->o('msa_stats_shared_dir'),
        'process_cactus_maf_exe' => $self->o('process_cactus_maf_exe'),
        'scratch_dir'            => $self->o('scratch_dir'),
    };
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my %dump_maf_params = (
        'chunk_id'              => '#hal_sequence_index#_#chunk_offset#_#chunk_length#',
        'hashed_sequence_index' => '#expr(dir_revhash(#hal_sequence_index#))expr#',
        'jobstore_parent_dir'   => '#jobstore_root_dir#/#hal_genome_name#/#hashed_sequence_index#',
        'jobstore'              => '#jobstore_parent_dir#/#chunk_id#',
        'maf_parent_dir'        => '#dump_dir#/maf/#hal_genome_name#/#hashed_sequence_index#/#chunk_id#',
        'maf_file'              => '#maf_parent_dir#/#chunk_id#.dumped.maf',
    );

    my %msa_stats_params = (
        'dump_features'     => $self->o('dump_features_exe'),
        'compare_beds'      => $self->o('compare_beds_exe'),
        'ensembl_release'   => $self->o('ensembl_release'),
        'bed_dir'           => $self->o('bed_dir'),
        'output_dir'        => '#feature_dir#',
    );

    return [

        {   -logic_name => 'fire_db_prepare',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions',
            -input_ids  => [ { } ],
            -flow_into  => {
                '1->A'  => [ 'load_mlss_id' ],
                'A->1'  => [ 'fire_hal_registration' ],
            },
        },

        {   -logic_name => 'load_mlss_id',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',
            -parameters => {
                'method_type'      => $self->o('method_type'),
                'species_set_name' => $self->o('collection'),
                'release'          => $self->o('ensembl_release'),
            },
            -flow_into  => [ 'copy_mlss' ],
        },

        {   -logic_name => 'copy_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithFK',
            -parameters => {
                'db_conn'                    => '#master_db#',
                'method_link_species_set_id' => '#mlss_id#',
            },
            -flow_into => [ 'load_component_genomedb_factory' ],
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
            -flow_into  => { 2 => 'genome_dnafrag_copy' },
        },

        {   -logic_name => 'genome_dnafrag_copy',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDnaFragsByGenomeDB',
        },

        {   -logic_name => 'fire_hal_registration',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => {
                '1->A' => [ 'hal_registration_entry_point' ],
                'A->1' => [ 'fire_load_cactus' ],
            },
        },

        {   -logic_name => 'hal_registration_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => [
                    'load_hal_mapping',
            ]
        },

        {   -logic_name => 'load_hal_mapping',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadHalMapping',
            -parameters => {
                'species_name_mapping' => $self->o('species_name_mapping'),
            },
            -rc_name    => '8Gb_job',
            -flow_into  => [ 'hc_hal_sequences', 'load_species_tree' ],
        },

        {   -logic_name => 'hc_hal_sequences',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::HealthcheckHalSequences',
            -parameters => {
                'hal_stats_exe' => $self->o('halStats_exe'),
            },
        },

        {   -logic_name => 'load_species_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSpeciesTree',
            -flow_into  => {
                2 => { 'hc_species_tree' => { 'mlss_id' => '#mlss_id#', 'species_tree_root_id' => '#species_tree_root_id#' } },
            },
        },

        {   -logic_name => 'hc_species_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MSA::SqlHealthChecks',
            -parameters => {
                'mode'                      => 'species_tree',
                'binary'                    => 0,
                'n_missing_species_in_tree' => 0,
            },
        },

        {   -logic_name => 'fire_load_cactus',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => {
                '1->A' => [ 'init_load_cactus' ],
                'A->1' => [ 'fire_post_load_processing' ],
            },
        },

        {   -logic_name => 'init_load_cactus',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::InitLoadCactus',
            -flow_into => { 2 => 'select_ref_genomedb' },
        },

        {   -logic_name => 'select_ref_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::SelectMafRefGenomeDB',
            -flow_into => { 3 => 'fire_load_genomedb' }
        },

        {   -logic_name => 'fire_load_genomedb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => 'init_load_genomedb',
        },

        {   -logic_name => 'init_load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::InitLoadGenomeDB',
            -flow_into  => { 2 => 'select_ref_hal_genome' },
        },

        {   -logic_name => 'select_ref_hal_genome',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::SelectMafRefHalGenome',
            -flow_into  => { 3 => 'fire_load_hal_genome' },
        },

        {   -logic_name => 'fire_load_hal_genome',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => { 1 => { 'hal_load_seq_chunk_factory' => INPUT_PLUS( { 'hal_genome_name' => '#ref_hal_genome#' } ) } },
        },

        {   -logic_name => 'hal_load_seq_chunk_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halSeqChunkFactory',
            -rc_name    => '4Gb_job',
            -parameters => {
                'hal_stats_exe' => $self->o('halStats_exe'),
                'chunk_size'    => $self->o('chunk_size'),
            },
            -flow_into  => {
                2 => { 'dump_maf' => INPUT_PLUS() },
            },
        },

        {   -logic_name => 'dump_maf',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::DumpCactusMaf',
            -hive_capacity => $self->o('maf_dump_capacity'),
            -rc_name    => '8Gb_24_hour_job',
            -parameters => { %dump_maf_params },
            -flow_into => {
               -1 => 'dump_maf_himem',
                2 => 'maf_processing_decision',
            },
        },

        {   -logic_name => 'dump_maf_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::DumpCactusMaf',
            -hive_capacity => $self->o('maf_dump_capacity'),
            -rc_name    => '16Gb_24_hour_job',
            -parameters => { %dump_maf_params },
            -flow_into => {
               -1 => 'dump_maf_hugemem',
                2 => 'maf_processing_decision',
            },
        },

        {   -logic_name => 'dump_maf_hugemem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::DumpCactusMaf',
            -hive_capacity => $self->o('maf_dump_capacity'),
            -rc_name    => '32Gb_24_hour_job',
            -parameters => { %dump_maf_params },
            -flow_into  => {
                2 => 'maf_processing_decision',
            },
        },

        {   -logic_name => 'maf_processing_decision',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                1 => WHEN( '#dumped_maf_block_count# > 0' => 'process_maf' ),
            },
        },

        {   -logic_name => 'process_maf',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -analysis_capacity => 700,
            -rc_name    => '1Gb_job',
            -parameters => {
                'processed_maf_file' => '#maf_parent_dir#/processed.maf',
                'dataflow_file'     => '#maf_parent_dir#/processed_maf_dataflow.json',
                'cmd'   => join(' ', (
                    '#process_cactus_maf_exe#',
                    '#dumped_maf_file#',
                    '#processed_maf_file#',
                    '--expected-block-count',
                    '#dumped_maf_block_count#',
                    '--dataflow-file',
                    '#dataflow_file#',
                )),
            },
            -flow_into  => {
                2 => WHEN( '#maf_block_count# > 0' => 'load_maf' ),
            },
        },

        {   -logic_name => 'load_maf',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadCactusMaf',
            -analysis_capacity => 20,
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'fire_post_load_processing',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => 'update_max_alignment_length',
        },

        {   -logic_name => 'update_max_alignment_length',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
            -rc_name    => '2Gb_job',
            -parameters => {
                'method_link_species_set_id' => '#mlss_id#',
            },
            -flow_into  => 'multiplealigner_stats_decision',
        },

        {   -logic_name => 'multiplealigner_stats_decision',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into => {
                1 => WHEN( 'not #skip_multiplealigner_stats#' => 'set_multiplealigner_stats_table', ELSE 'end_pipeline' ),
            },
        },

        {   -logic_name => 'set_multiplealigner_stats_table',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::SetMultipleAlignerStatsTable',
            -flow_into  => 'multiplealigner_stats_factory',
        },

        {   -logic_name => 'multiplealigner_stats_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                '2->A' => { 'multiplealigner_stats' => INPUT_PLUS() },
                'A->1' => [ 'block_size_distribution' ],
            },
        },

        {   -logic_name => 'multiplealigner_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerStats',
            -parameters => { %msa_stats_params },
            -rc_name => '8Gb_job',
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

        {   -logic_name  => 'end_pipeline',
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

     ];
}



1;
