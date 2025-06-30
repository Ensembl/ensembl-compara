
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

Bio::EnsEMBL::Compara::PipeConfig::DumpCactus_conf

=head1 DESCRIPTION

This pipeline makes use of various software tools for processing alignments in HAL or MAF format,
including Cactus ( Armstrong et al. 2020; https://doi.org/10.1038/s41586-020-2871-y ),
hal2maf ( Hickey et al. 2013; https://doi.org/10.1093/bioinformatics/btt128 ),
taffy ( https://github.com/ComparativeGenomicsToolkit/taffy ),
mafDuplicateFilter ( Earl et al. 2014; https://doi.org/10.1101/gr.174920.114 ),
Biopython ( Cock et al. 2009; https://doi.org/10.1093/bioinformatics/btp163 ),
and NumPy ( Harris et al. 2020; https://doi.org/10.1038/s41586-020-2649-2 ).

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpCactus_conf;

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

    die "Pipeline parameter 'hal_file' is undefined, but must be specified" unless $self->o('hal_file');
    die "Pipeline parameter 'ref_hal_genome' is undefined, but must be specified" unless $self->o('ref_hal_genome');
    die "Pipeline parameter 'target_genomes' is undefined, but must be specified" unless $self->o('target_genomes');
    die "Pipeline parameter 'output_file' is undefined, but must be specified" unless $self->o('output_file');
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
        'output_file'            => $self->o('output_file'),

        'hal2maf_exe'            => $self->o('hal2maf_exe'),
        'halStats_exe'           => $self->o('halStats_exe'),
        'mafDuplicateFilter_exe' => $self->o('mafDuplicateFilter_exe'),
        'process_cactus_maf_exe' => $self->o('process_cactus_maf_exe'),
        'taffy_exe'              => $self->o('taffy_exe'),
    };
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my %dump_maf_params = (
        'hashed_chunk_index' => '#expr(dir_revhash(#hal_chunk_index#))expr#',
        'maf_parent_dir'     => '#dump_dir#/maf/#hal_genome_name#/#hashed_chunk_index#',
        'maf_file'           => '#maf_parent_dir#/#hal_chunk_index#.dumped.maf',
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
                1 => WHEN( '#dumped_maf_block_count# > 0' => 'process_maf' ),
            },
        },

        {   -logic_name => 'process_maf',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::ProcessCactusMaf',
            -analysis_capacity => 700,
            -rc_name    => '1Gb_job',
            -parameters => {
                'processed_maf_file'        => '#maf_parent_dir#/#hal_chunk_index#.processed.maf',
                'max_block_length_to_merge' => 200,
                'max_gap_length'            => 30,
            },
            -flow_into  => {
                2 => WHEN(
                    '#maf_block_count# > 0' => [
                        '?accu_name=chunked_maf_files&accu_address=[hal_chunk_index]&accu_input_variable=processed_maf_file',
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
