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
            },
            -flow_into  => {
                1 => [ '?accu_name=alignment_mlsses&accu_address=[]&accu_input_variable=accu_dataflow' ],
                2 => [ '?accu_name=mlss_db_mapping&accu_address={mlss_id}&accu_input_variable=mlss_db' ],
            },
            -analysis_capacity => 50,
        },

        {   -logic_name => 'ortholog_mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologMLSSFactory',
            -parameters => {
                'method_link_types' => $self->o('homology_method_link_types'),
            },
            -flow_into  => {
                '2->A' => { 'calculate_wga_coverage' => INPUT_PLUS() },
                'A->1' => [ 'check_file_copy' ],
            }
        },

        {   -logic_name => 'calculate_wga_coverage',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::WGACoverage',
            -parameters => {
                'hashed_mlss_id'            => '#expr(dir_revhash(#orth_mlss_id#))expr#',
                'homology_flatfile'         => '#homology_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.homologies.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.homology_id_map.tsv',
                'previous_wga_file'         => '#prev_wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga.tsv',
                'reuse_file'                => '#wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga_reuse.tsv',
                'output_file'               => '#wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga.tsv',
            },
            -analysis_capacity  =>  140,  # use per-analysis limiter
            -flow_into  => {
                3 => [ '?table_name=ortholog_quality' ],
            },
            -rc_name => '2Gb_24_hour_job',
        },

        {   -logic_name  => 'check_file_copy',
            -module      => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into   => {
                1 => [
                    WHEN( '#homology_dumps_shared_dir#' => 'copy_files_to_shared_loc' ),
                ],
            },
        },

        {   -logic_name => 'copy_files_to_shared_loc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => q(/bin/bash -c "mkdir -p #homology_dumps_shared_dir# && rsync -rtO --exclude '*.wga_reuse.tsv' #wga_dumps_dir#/ #homology_dumps_shared_dir#"),
            },
        },

    ];
}

1;
