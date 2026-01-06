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

Bio::EnsEMBL::Compara::PipeConfig::DumpCactusVariation_conf

=head1 DESCRIPTION

This pipeline makes use of various software tools for processing alignments,
including Cactus ( Armstrong et al. 2020; https://doi.org/10.1038/s41586-020-2871-y ),
hal2maf ( Hickey et al. 2013; https://doi.org/10.1093/bioinformatics/btt128 ),
mafDuplicateFilter ( Earl et al. 2014; https://doi.org/10.1101/gr.174920.114 ),
Biopython ( Cock et al. 2009; https://doi.org/10.1093/bioinformatics/btp163 ),
and NumPy ( Harris et al. 2020; https://doi.org/10.1038/s41586-020-2649-2 ).

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpCactusVariation_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name'     => 'dump_cactus',

        # pipeline output
        'output_maf_file'      => undef,
        'output_bigchain1_file' => undef,
        'output_bigchain2_file' => undef,
        'output_bigmaf_file'   => undef,
        'output_taf_file'      => undef,

        # pipeline settings
        'chunk_size'        => 500_000,
        'maf_dump_capacity' => 150,

         # data directories:
        'work_dir'          => $self->o('pipeline_dir'),
        'dump_dir'          => $self->o('work_dir') . '/' . 'dumps',
    };
}


sub no_compara_schema {}


sub pipeline_checks_pre_init {
    my ($self) = @_;

    my @required_params = ('hal_file', 'ref_hal_genome', 'output_maf_file', 'target_genomes');

    foreach my $param_name (@required_params) {
        die "Pipeline parameter '$param_name' is undefined, but must be specified" unless $self->o($param_name);
    }
}


sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},

        $self->pipeline_create_commands_rm_mkdir(['dump_dir', 'work_dir']),
    ];
}


sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'dump_dir'               => $self->o('dump_dir'),
        'work_dir'               => $self->o('work_dir'),

        'hal_file'               => $self->o('hal_file'),
        'ref_hal_genome'         => $self->o('ref_hal_genome'),
        'target_genomes'         => $self->o('target_genomes'),
        'hal_mapping_dir'        => $self->o('hal_mapping_dir'),
        'output_maf_file'        => $self->o('output_maf_file'),
        'output_bigchain1_file'  => $self->o('output_bigchain1_file'),
        'output_bigchain2_file'  => $self->o('output_bigchain2_file'),
        'output_bigmaf_file'     => $self->o('output_bigmaf_file'),
        'output_taf_file'        => $self->o('output_taf_file'),

        'big_bed_exe'            => $self->o('big_bed_exe'),
        'chainToBigChain_exe'    => $self->o('chainToBigChain_exe'),
        'hal2maf_exe'            => $self->o('hal2maf_exe'),
        'halStats_exe'           => $self->o('halStats_exe'),
        'left_align_maf_exe'     => $self->o('left_align_maf_exe'),
        'mafDuplicateFilter_exe' => $self->o('mafDuplicateFilter_exe'),
        "mafToBigMaf_exe"        => $self->o('mafToBigMaf_exe'),
        "maf_convert_exe"        => $self->o('maf_convert_exe'),
        'map_maf_src_field_exe'  => $self->o('map_maf_src_field_exe'),
        'process_cactus_maf_exe' => $self->o('process_cactus_maf_exe'),
        'split_maf_on_gaps_exe'  => $self->o('split_maf_on_gaps_exe'),
        'taffy_exe'              => $self->o('taffy_exe'),
    };
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my %dump_maf_params = (
        'hashed_chunk_index'       => '#expr(dir_revhash(#hal_chunk_index#))expr#',
        'maf_parent_dir'           => '#dump_dir#/maf/#hal_genome_name#/#hashed_chunk_index#',
        'maf_file'                 => '#maf_parent_dir#/#hal_chunk_index#.dumped.maf',
        'max_block_length_to_dump' => 48_000_000,
    );

    return [

        {   -logic_name => 'fire_dump_cactus',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids  => [ { } ],
            -flow_into  => {
                '1->A' => { 'hal_seq_chunk_factory' => INPUT_PLUS( { 'hal_genome_name' => '#ref_hal_genome#' } ) },
                'A->1' => [ 'concatenate_maf' ],
            },
        },

        {   -logic_name => 'hal_seq_chunk_factory',
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
                1 => WHEN( '#dumped_maf_block_count# > 0' => 'prep_variation_maf' ),
            },
        },

        {   -logic_name => 'prep_variation_maf',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::PrepVariationMaf',
            -analysis_capacity => 700,
            -rc_name    => '1Gb_job',
            -parameters => {
                'prepped_maf_file' => '#maf_parent_dir#/#hal_chunk_index#.prepped.maf',
            },
            -flow_into  => {
                2 => WHEN(
                    '#maf_block_count# > 0' => [
                        '?accu_name=chunked_maf_files&accu_address=[hal_chunk_index]&accu_input_variable=prepped_maf_file',
                        '?accu_name=maf_block_counts&accu_address=[hal_chunk_index]&accu_input_variable=maf_block_count',
                    ],
                ),
            },
        },

        {   -logic_name => 'concatenate_maf',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::ConcatenateMaf',
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'healthcheck_list' => ['maf_block_count', 'unexpected_nulls'],
            },
            -flow_into  => {
                '1->A' => WHEN(
                    '#output_bigchain1_file#' => 'maf_to_bigchain',
                    '#output_bigmaf_file#' => 'maf_to_bigmaf',
                    '#output_taf_file#' => 'maf_to_taf',
                ),
                'A->1'  => [ 'archive_maf' ],
            },
        },

        {   -logic_name => 'maf_to_bigchain',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::MafToBigChain',
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'bigchain_autosql' => 'https://genome.ucsc.edu/goldenpath/help/examples/bigChain.as',
                'biglink_autosql' => 'https://genome.ucsc.edu/goldenpath/help/examples/bigLink.as',
                'chainSwap_exe' => $self->o('chainSwap_exe'),
            },
        },

        {   -logic_name => 'maf_to_bigmaf',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::MafToBigMaf',
            -rc_name    => '2Gb_24_hour_job',
            -parameters => {
                'bigmaf_autosql' => 'https://genome.ucsc.edu/goldenpath/help/examples/bigMaf.as',
            },
        },

        {   -logic_name => 'maf_to_taf',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::MafToTaf',
            -rc_name    => '1Gb_24_hour_job',
        },

        {   -logic_name => 'archive_maf',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => 'gzip -f #work_dir#/#output_maf_file#',
            },
        },
    ];
}


sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    my @unguarded_funnels = (
        'concatenate_maf',
    );

    foreach my $logic_name (@unguarded_funnels) {
        $analyses_by_name->{$logic_name}->{'-analysis_capacity'} = 0;
    }
}


1;
