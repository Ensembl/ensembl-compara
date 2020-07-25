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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::OrthologQMAlignment

=head1 DESCRIPTION

This pipeline uses whole genome alignments to calculate the
coverage of homologous pairs.
The coverage is calculated on both exonic and intronic regions
seperately and summarised using a quality_score calculation.
The average quality_score between both members of the homology
will be written to the homology table.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::OrthologQMAlignment;


use strict;
use warnings;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub pipeline_analyses_ortholog_qm_alignment {
    my ($self) = @_;
    return [
        {   -logic_name => 'pair_species',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection',
            -flow_into  => {
                '2->B' => [ 'select_mlss' ],
                'B->1' => [ 'ortholog_mlss_factory' ],
                '3'    => [ 'reset_mlss' ],
            },
            -parameters => {
                'species_set_name' => $self->o('species_set_name'),
                'species_set_id'   => $self->o('species_set_id'),
                'ref_species'      => $self->o('ref_species'),
                'species1'         => $self->o('species1'),
                'species2'         => $self->o('species2'),
                'master_db'        => $self->o('master_db'),
            },
        },

        {   -logic_name => 'reset_mlss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => 'DELETE FROM ortholog_quality WHERE alignment_mlss = #aln_mlss_id#',
            },
            -analysis_capacity => 3,
        },

        {   -logic_name => 'select_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS',
            -parameters => {
                'current_release' => $self->o('ensembl_release'),
                'master_db'       => $self->o('master_db'),
            },
            -flow_into  => {
                1 => [ '?accu_name=alignment_mlsses&accu_address=[]&accu_input_variable=accu_dataflow' ],
                2 => [ '?accu_name=mlss_db_mapping&accu_address={mlss_id}&accu_input_variable=mlss_db' ],
            },
            -rc_name => '500Mb_job',
            -analysis_capacity => 50,
        },

        {   -logic_name => 'ortholog_mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologMLSSFactory',
            -parameters => {
                'method_link_types' => $self->o('homology_method_link_types'),
            },
            -flow_into  => {
                '2->A' => { 'prepare_orthologs' => INPUT_PLUS() },
                'A->1' => [ 'check_file_copy' ],
            }
        },

        {   -logic_name => 'prepare_orthologs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs',
            -parameters => {
                'hashed_mlss_id'            => '#expr(dir_revhash(#orth_mlss_id#))expr#',
                'homology_flatfile'         => '#homology_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.homologies.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.homology_id_map.tsv',
            },
            -analysis_capacity  =>  50,  # use per-analysis limiter
            -flow_into => {
                # these analyses will write to the same file, so a semaphore is required to prevent clashes
                '3->A' => [ 'reuse_wga_score' ],
                'A->2' => { 'calculate_wga_coverage' => INPUT_PLUS() },
            },
            -rc_name  => '2Gb_job',
        },

        {   -logic_name => 'calculate_wga_coverage',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage',
            -hive_capacity => 30,
            -batch_size => 10,
            -flow_into  => {
                3 => [ '?table_name=ortholog_quality' ],
                2 => [ 'assign_wga_coverage_score' ],
            },
            -rc_name => '2Gb_job',
        },

        {   -logic_name => 'assign_wga_coverage_score',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore',
            -parameters => {
                'hashed_mlss_id' => '#expr(dir_revhash(#orth_mlss_id#))expr#',
                'output_file'    => '#wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga.tsv',
                'reuse_file'     => '#wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga_reuse.tsv',
            },
            -rc_name    => '500Mb_job',
            -hive_capacity => 400,
        },

        {   -logic_name => 'reuse_wga_score',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ReuseWGAScore',
            -parameters => {
                'hashed_mlss_id'            => '#expr(dir_revhash(#orth_mlss_id#))expr#',
                'previous_wga_file'         => '#prev_wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.homology_id_map.tsv',
                'output_file'               => '#wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga_reuse.tsv',
            },
            -hive_capacity => 400,
        },

        {   -logic_name  => 'check_file_copy',
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters  => {
                'sql' => [ 'UPDATE pipeline_wide_parameters SET param_value = 1 WHERE param_name = "orth_wga_complete"' ],
            },
            -flow_into   => {
                1 => [
                    WHEN( '#homology_dumps_shared_dir#' => 'copy_files_to_shared_loc' ),
                ],
            },
        },

        {   -logic_name => 'copy_files_to_shared_loc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => q(/bin/bash -c "mkdir -p #homology_dumps_shared_dir# && rsync -rtOp --exclude '*.wga_reuse.tsv' #wga_dumps_dir#/ #homology_dumps_shared_dir#"),
            },
            -rc_name    => '500Mb_job',
        },

    ];
}

1;
