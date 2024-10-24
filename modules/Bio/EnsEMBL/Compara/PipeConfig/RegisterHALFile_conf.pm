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

Bio::EnsEMBL::Compara::PipeConfig::RegisterHALFile_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::RegisterHALFile_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -mlss_id <mlss_id> -species_name_mapping "{134 => 'C57B6J', ... }"

=head1 DESCRIPTION

Mini-pipeline to load the species-tree and the chromosome-name mapping from a HAL file.

NOTE: Alignments using the _method_ `CACTUS_HAL` or `CACTUS_HAL_PW` require extra
files to be downloaded from
<https://ftp.ensembl.org/pub/data_files/multi/hal_files/> in order to be fetched with the
API. The files must have the same name as on the FTP and must be placed
under `multi/hal_files/` within your directory of choice.
Finally, you need to define the environment variable `COMPARA_HAL_DIR` to
the latter.
export COMPARA_HAL_DIR="path_to_file/data_files/"

=head1 EXAMPLES

    # default execution for Vertebrates
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::RegisterHALFile_conf -host mysql-ens-compara-prod-1 -port 4485 \
        -division vertebrates -mlss_id 835 \
        -species_name_mapping "{134 => 'C57B6J', 155 => 'rn6',160 => '129S1_SvImJ',161 => 'A_J',162 => 'BALB_cJ',163 => 'C3H_HeJ',164 => 'C57BL_6NJ',165 => 'CAST_EiJ',166 => 'CBA_J',167 => 'DBA_2J',168 => 'FVB_NJ',169 => 'LP_J',170 => 'NOD_ShiLtJ',171 => 'NZO_HlLtJ',172 => 'PWK_PhJ',173 => 'WSB_EiJ',174 => 'SPRET_EiJ', 178 => 'AKR_J'}"

=cut

package Bio::EnsEMBL::Compara::PipeConfig::RegisterHALFile_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'master_db' => 'compara_master',

        'collection'    => undef,
        'method_type'   => 'CACTUS_HAL',
        'pipeline_name' => $self->o('collection') . '_' . $self->o('division') . '_register_halfile_' . $self->o('rel_with_suffix'),

        'do_alt_mlss'   => 1,

        'species_name_mapping' => undef,
    };
}



sub pipeline_checks_pre_init {
    my ($self) = @_;

    die "Pipeline parameter 'collection' is undefined, but must be specified" unless $self->o('collection');
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'master_db'     => $self->o('master_db'),
        'halStats_exe'  => $self->o('halStats_exe'),
        'do_alt_mlss'   => $self->o('do_alt_mlss'),
    };
}


sub pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'load_mlss_id',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',
            -input_ids  => [ {
                'method_type'      => $self->o('method_type'),
                'species_set_name' => $self->o('collection'),
                'release'          => $self->o('ensembl_release'),
            } ],
            -flow_into  => [ 'copy_mlss' ],
        },

        {   -logic_name => 'copy_mlss',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithFK',
            -parameters => {
                'db_conn'                       => '#master_db#',
                'method_link_species_set_id'    => '#mlss_id#',
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
            -flow_into  => {
                '2->A'  => [ 'genome_dnafrag_copy' ],
                'A->1'  => [ 'fire_hal_file_registration' ],
            },
        },

        {   -logic_name => 'genome_dnafrag_copy',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDnaFragsByGenomeDB',
        },

        {   -logic_name => 'fire_hal_file_registration',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => [ 'hal_registration_entry_point' ],
                'A->1' => [ 'fire_hal_coverage' ],
            },
        },

        {   -logic_name => 'hal_registration_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => [
                    WHEN('#do_alt_mlss#' => 'find_pairwise_mlss_ids'),
                    'load_hal_mapping',
            ]
        },

        {   -logic_name => 'find_pairwise_mlss_ids',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'       => '#master_db#',
                'inputquery'    => 'SELECT mlss.method_link_species_set_id AS pw_mlss_id FROM method_link_species_set mlss JOIN method_link USING (method_link_id) JOIN species_set ss USING (species_set_id) JOIN (species_set ss_ref JOIN method_link_species_set mlss_ref USING (species_set_id)) USING (genome_db_id) WHERE mlss_ref.method_link_species_set_id = #mlss_id# AND type = "CACTUS_HAL_PW" GROUP BY mlss.method_link_species_set_id HAVING COUNT(*) = 2',
            },
            -flow_into  => {
                2   => { 'copy_alt_mlss' => INPUT_PLUS() },
            },
        },

        {   -logic_name => 'copy_alt_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithFK',
            -parameters => {
                'db_conn'                       => '#master_db#',
                'method_link_species_set_id'    => '#pw_mlss_id#',
                'expand_tables'                 => 0,                   # Do not try to copy the ncbi_taxa_name table again (esp. because there is no UNIQUE key and the rows will be duplicated !)
            },
            -flow_into  => [ 'connect_alt_mlss' ],
            -analysis_capacity  => 1,
        },

        {   -logic_name => 'connect_alt_mlss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [
                    'UPDATE method_link_species_set alt_mlss JOIN method_link_species_set ref_mlss SET alt_mlss.url = ref_mlss.url WHERE alt_mlss.method_link_species_set_id = #pw_mlss_id# AND ref_mlss.method_link_species_set_id = #mlss_id#',
                    'INSERT IGNORE INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#pw_mlss_id#, "alt_hal_mlss", "#mlss_id#")',
                ],
            },
            -analysis_capacity  => 1,
        },

        {   -logic_name => 'load_hal_mapping',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadHalMapping',
            -parameters => {
                'species_name_mapping' => $self->o('species_name_mapping'),
            },
            -rc_name    => '4Gb_job',
            -flow_into  => [
                'load_species_tree',
                'synonyms_genome_factory'
            ],
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

        {   -logic_name => 'synonyms_genome_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halDualGenomeFactory',
             -flow_into => {
                '2->A' => { 'get_synonyms' => INPUT_PLUS() },
                'A->1' => [ 'aggregate_synonyms' ],
            },
        },

        {   -logic_name => 'get_synonyms',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSynonyms',
            -flow_into  => {
                2 => [ '?accu_name=e2u_synonyms&accu_input_variable=synonym&accu_address={genome_db_id}{name}' ],
            },
	    -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'aggregate_synonyms',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'e2u_synonyms'  => {},  # default value, in case the accu is empty
                'sql' => [ q/REPLACE INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#mlss_id#, "alt_synonyms", '#expr(stringify(#e2u_synonyms#))expr#')/ ],
            },
	    -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'fire_hal_coverage',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => [ 'pairwise_coverage_factory', 'per_genome_coverage_factory' ],
        },

        {   -logic_name => 'pairwise_coverage_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halDualGenomeFactory',
             -flow_into => {
                    3   => { 'generate_pairwise_coverage_stats' => INPUT_PLUS() },
            },
        },

        {
            -logic_name => 'generate_pairwise_coverage_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halCoverageStats',
            -rc_name    => '4Gb_job',
        },

        {   -logic_name => 'per_genome_coverage_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halDualGenomeFactory',
             -flow_into => {
                '3->A'  => { 'hal_seq_chunk_factory' => INPUT_PLUS() },
                'A->2'  => { 'aggregate_per_genome_coverage' => INPUT_PLUS() },
            },
        },

        {   -logic_name => 'hal_seq_chunk_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halSeqChunkFactory',
            -rc_name    => '4Gb_job',
            -parameters => {
                'hal_stats_exe' => $self->o('halStats_exe'),
            },
            -flow_into  => {
                2 => { 'calculate_seq_chunk_coverage' => INPUT_PLUS() },
                3 => [ '?accu_name=hal_sequence_names&accu_address=[]&accu_input_variable=hal_sequence_name' ],
            },
        },

        {   -logic_name        => 'calculate_seq_chunk_coverage',
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

        {   -logic_name => 'aggregate_per_genome_coverage',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::AggregateHalGenomicCoverage',
            -rc_name    => '4Gb_job',
        },

     ];
}

1;
