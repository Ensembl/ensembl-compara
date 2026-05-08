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

The DumpCactusVariation pipeline generates a pair of bigChain files representing
a reciprocal alignment between two genome sequences: one corresponding to a
reference haplotype, and the other corresponding to an alternative haplotype.

The pipeline takes as input:
- hal_file          : path of an input HAL file containing the reference and alternative genomes
- ref_hal_genome    : name of the reference haplotype genome in the HAL file
- alt_hal_genome    : name of the alternative haplotype genome in the HAL file
- hal_mapping_dir   : path of a directory containing HAL mapping TSV files, allowing mapping between
                      the identifiers of a genome sequence in the input HAL file (identified by
                      'hal_genome_name' and hal_sequence_name') and its name in Ensembl resources
                      (identified by 'assembly_uuid' and 'assembly_sequence')
- ref_bigchain_file : bigChain file in which the target genome is the reference haplotype,
                      and the query genome is the alternative haplotype
- alt_bigchain_file : bigChain file in which the target genome is the alternative haplotype,
                      and the query genome is the reference haplotype

=head2 Workflow

The main steps of the DumpCactusVariation pipeline are as follows:

1. halStats is used to fetch chrom.sizes data of the reference genome in order to generate,
   for each reference sequence, coordinates of chunk regions up to 500 kb in length.

2. hal2maf is used to dump a MAF alignment file for each chunk region. Option '--refGenome' is set
   to the reference haplotype genome, while '--targetGenomes' is set to the alternative haplotype
   genome. Other command-line arguments are as follows: '--maxBlockLen 48000000 --noAncestors --unique'

3. Each nonempty MAF file is used to prepare a chain file. It is first processed to remove gap-only and
   overhang columns, and to filter out alignment blocks having only one sequence. taffy is used to sanitise
   haplotype genome names in the MAF file, mafDuplicateFilter is used (with option '--keep-first')
   to deduplicate the alignment per haplotype, and taffy is used again in order to restore the original
   haplotype genome names. The deduplicated MAF file is processed as before, to remove alignment blocks and
   columns with fewer than two sequences. The MAF is further processed to left-align gaps in the alternative
   haplotype with respect to the reference, remove the genome name from the MAF src field, and split MAF
   blocks on gaps so that the final MAF file contains only ungapped alignment blocks. maf-convert reads
   this final MAF file to generate a chain file.

4. Nonempty chain files are merged into a single file in order of reference haplotype position.

5. Taking the merged chain file in which the reference haplotype is the target genome
   and the alternative haplotype is the query genome, chainSwap creates a swapped chain
   file in which the alternative is the target genome and the reference is the query genome.

6. The original and swapped chain files are each converted to a bigChain file.
   In line with the process described on the UCSC webpage, "bigChain Track Format"
   ( https://genome.ucsc.edu/goldenpath/help/bigChain.html ), chainToBigChain converts
   each chain file to a pre-bigChain file.

7. With a chrom.sizes file generated for the chain target genome using halStats, and a bigChain autoSql
   file ( downloaded from https://genome.ucsc.edu/goldenpath/help/examples/bigChain.as ), the pre-bigChain
   file is input to bedToBigBed to generate to an output bigChain file.

8. Finally, validateFiles validates each output bigChain file.

=head2 Software/references

This pipeline makes use of various tools for processing alignments, including:
- bedToBigBed v. 2.8 ( Kent et al. 2010; https://doi.org/10.1093/bioinformatics/btq351 )
- Biopython 1.81 ( Cock et al. 2009; https://doi.org/10.1093/bioinformatics/btp163 )
- Cactus 3.0.0 ( Armstrong et al. 2020; https://doi.org/10.1038/s41586-020-2871-y )
- chainSwap, part of kent v415 (Casper et al. 2025; https://doi.org/10.1093/nar/gkaf1250 )
- chainToBigChain, part of kent v479 (Casper et al. 2025; https://doi.org/10.1093/nar/gkaf1250 )
- hal2maf v2.2 ( Hickey et al. 2013; https://doi.org/10.1093/bioinformatics/btt128 )
- halStats v2.2 ( Hickey et al. 2013; https://doi.org/10.1093/bioinformatics/btt128 )
- maf-convert, part of LAST 1642 ( Kielbasa et al. 2011; https://doi.org/10.1101/gr.113985.110 )
- mafDuplicateFilter, commit c101dedb2c1c8339bc284e3a16000bc4523f5da3 ( Earl et al. 2014; https://doi.org/10.1101/gr.174920.114 )
- NumPy 1.24.3 ( Harris et al. 2020; https://doi.org/10.1038/s41586-020-2649-2 )
- taffy, commit 1329d999948ad4acc10116276fa7a9752a749595 ( https://github.com/ComparativeGenomicsToolkit/taffy )
- validateFiles v4.7 ( Casper et al. 2025; https://doi.org/10.1093/nar/gkaf1250 )

Additionally, the pipeline implements variant normalisation along the lines
described in Tan et al. 2015 ( https://doi.org/10.1093/bioinformatics/btv112 ).

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

        # pipeline settings
        'chunk_size'        => 500_000,
        'maf_dump_capacity' => 150,

         # data directories:
        'work_dir'          => $self->o('pipeline_dir'),
        'dump_dir'          => $self->o('work_dir') . '/' . 'dumps',
        'chain_dir'         => $self->o('work_dir') . '/' . 'chains',
    };
}


sub no_compara_schema {}


sub pipeline_checks_pre_init {
    my ($self) = @_;

    my @required_params = ('alt_bigchain_file', 'alt_hal_genome', 'hal_file', 'ref_bigchain_file', 'ref_hal_genome');

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
        'chain_dir'              => $self->o('chain_dir'),
        'dump_dir'               => $self->o('dump_dir'),
        'work_dir'               => $self->o('work_dir'),

        'hal_file'               => $self->o('hal_file'),
        'ref_hal_genome'         => $self->o('ref_hal_genome'),
        'alt_hal_genome'         => $self->o('alt_hal_genome'),
        'hal_mapping_dir'        => $self->o('hal_mapping_dir'),
        'ref_bigchain_file'      => $self->o('ref_bigchain_file'),
        'alt_bigchain_file'      => $self->o('alt_bigchain_file'),

        'big_bed_exe'            => $self->o('big_bed_exe'),
        'chainSwap_exe'          => $self->o('chainSwap_exe'),
        'chainToBigChain_exe'    => $self->o('chainToBigChain_exe'),
        'hal2maf_exe'            => $self->o('hal2maf_exe'),
        'halStats_exe'           => $self->o('halStats_exe'),
        'left_align_maf_exe'     => $self->o('left_align_maf_exe'),
        'mafDuplicateFilter_exe' => $self->o('mafDuplicateFilter_exe'),
        "maf_convert_exe"        => $self->o('maf_convert_exe'),
        'map_maf_src_field_exe'  => $self->o('map_maf_src_field_exe'),
        'merge_chain_files_exe'  => $self->o('merge_chain_files_exe'),
        'process_cactus_maf_exe' => $self->o('process_cactus_maf_exe'),
        'split_maf_on_gaps_exe'  => $self->o('split_maf_on_gaps_exe'),
        'taffy_exe'              => $self->o('taffy_exe'),
        'validateFiles_exe'      => $self->o('validateFiles_exe'),
    };
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my %dump_maf_params = (
        'hashed_chunk_index'       => '#expr(dir_revhash(#hal_chunk_index#))expr#',
        'maf_parent_dir'           => '#dump_dir#/maf/#hal_genome_name#/#hashed_chunk_index#',
        'maf_file'                 => '#maf_parent_dir#/#hal_chunk_index#.dumped.maf',
        'max_block_length_to_dump' => 48_000_000,
        'target_genomes'           => '#alt_hal_genome#',
    );

    return [

        {   -logic_name => 'fire_dump_cactus',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids  => [ { } ],
            -flow_into  => {
                '1->A' => { 'hal_seq_chunk_factory' => INPUT_PLUS( { 'hal_genome_name' => '#ref_hal_genome#' } ) },
                'A->1' => [ 'merge_chains' ],
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
                2 => 'maf_processing_decision',
            },
        },

        {   -logic_name => 'maf_processing_decision',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                1 => WHEN( '#dumped_maf_block_count# > 0' => 'prep_variation_chain' ),
            },
        },

        {   -logic_name => 'prep_variation_chain',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::PrepVariationChain',
            -analysis_capacity => 700,
            -rc_name    => '1Gb_job',
            -parameters => {
                'healthcheck_list' => ['chain_count', 'unexpected_nulls'],
                'prepped_chain_file' => '#maf_parent_dir#/#hal_chunk_index#.prepped.chain',
            },
            -flow_into  => {
                2 => WHEN(
                    '#maf_block_count# > 0' => [
                        '?accu_name=chunked_chain_files&accu_address=[hal_chunk_index]&accu_input_variable=prepped_chain_file',
                        '?accu_name=chain_counts&accu_address=[hal_chunk_index]&accu_input_variable=chain_count',
                    ],
                ),
            },
        },

        {   -logic_name => 'merge_chains',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::MergeChains',
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'healthcheck_list' => ['chain_count', 'unexpected_nulls'],
                'merged_chain_file' => '#chain_dir#/merged.chain',
            },
            -flow_into  => {
                1 => {
                    'chain_to_bigchain' => {
                        'chain_file' => '#merged_chain_file#',
                        'chain_target_hal_genome' => '#ref_hal_genome#',
                        'bigchain_file' => '#ref_bigchain_file#',
                    },
                    'swap_chain' => {
                        'chain_file' => '#merged_chain_file#',
                    },
                },
            },
        },

        {   -logic_name => 'swap_chain',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => '#chainSwap_exe# #chain_file# #swapped_chain_file#',
                'swapped_chain_file' => '#chain_dir#/swapped.chain',
            },
            -flow_into  => {
                1 => {
                    'chain_to_bigchain' => {
                        'chain_file' => '#swapped_chain_file#',
                        'chain_target_hal_genome' => '#alt_hal_genome#',
                        'bigchain_file' => '#alt_bigchain_file#',
                    },
                },
            },
        },

        {   -logic_name => 'chain_to_bigchain',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::ChainToBigChain',
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'bigchain_autosql' => 'https://genome.ucsc.edu/goldenpath/help/examples/bigChain.as',
            },
        },
    ];
}


sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    my @unguarded_funnels = (
        'merge_chains',
    );

    foreach my $logic_name (@unguarded_funnels) {
        $analyses_by_name->{$logic_name}->{'-analysis_capacity'} = 0;
    }
}


1;
