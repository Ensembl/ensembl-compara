=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Parts::GOC

=head1 DESCRIPTION

This file contains the main parts needed to run GOC in a pipeline.
It is used to form the main GOC pipeline, but is also embedded in
the ProteinTrees and NcRNATrees pipelines

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::GOC;


use strict;
use warnings;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;  

sub pipeline_analyses_goc {
    my ($self) = @_;
    return [

        {   -logic_name => 'goc_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => WHEN( '#goc_reuse_db#' => ['copy_prev_goc_score_table']),
                'A->1' => WHEN( '#goc_mlss_id#' => 'compute_goc',
                                ELSE 'goc_group_genomes_under_taxa' ),
            },
        },

        {   -logic_name => 'copy_prev_goc_score_table',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithJoin',
            -parameters => {
                'db_conn'       => '#goc_reuse_db#',
                'table'         => 'prev_ortholog_goc_metric',
                # This query will transform gene_member_id into stable_id
                'inputquery'    => 'SELECT method_link_species_set_id, homology_id, stable_id, goc_score, left1, left2, right1, right2 FROM ortholog_goc_metric JOIN gene_member USING (gene_member_id)',
            },
        },

        {   -logic_name => 'goc_group_genomes_under_taxa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupGenomesUnderTaxa',
            -parameters => {
                'taxlevels'             => $self->o('goc_taxlevels'),
                'filter_high_coverage'  => 0,
            },
            -flow_into => {
                '2' => [ 'goc_mlss_factory' ],
            },
        },

        {   -logic_name => 'goc_mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory',
            -parameters => {
                'methods'   => {
                    'ENSEMBL_ORTHOLOGUES'   => 2,
                },
            },
            -rc_name => '500Mb_job',
            -flow_into => {
                2 => {
                    #'get_orthologs' => { 'goc_mlss_id' => '#homo_mlss_id#' },
                    'compute_goc' => { 'goc_mlss_id' => '#homo_mlss_id#' },
                },
            },
        },

        {   -logic_name => 'compute_goc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GOCAllInOne',
            -flow_into => {
                1 => WHEN(
                    '#goc_threshold# and #calculate_goc_distribution#' => [ 'get_perc_above_threshold' ] ,
                    '!(#goc_threshold#) and #calculate_goc_distribution#' => [ 'get_genetic_distance' ],
                ),
            },
            -rc_name => '1Gb_job',
            -hive_capacity  =>  $self->o('goc_capacity'),
            -flow_into => {
                -1 => 'compute_goc_himem',
            },
        },

        {   -logic_name => 'compute_goc_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GOCAllInOne',
            -flow_into => {
                1 => WHEN(
                    '#goc_threshold# and #calculate_goc_distribution#' => [ 'get_perc_above_threshold' ] ,
                    '!(#goc_threshold#) and #calculate_goc_distribution#' => [ 'get_genetic_distance' ],
                ),
            },
            -rc_name => '4Gb_job',
            -hive_capacity  =>  $self->o('goc_capacity'),
        },

        {
            -logic_name => 'get_genetic_distance',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Fetch_genetic_distance',
            -flow_into => {
                1 =>    { 'threshold_calculator' => INPUT_PLUS },
                },
            -hive_capacity  =>  $self->o('goc_stats_capacity'),
        },

        {
            -logic_name => 'threshold_calculator',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_threshold',
            -flow_into => {
                1 =>    ['get_perc_above_threshold'],
                },
            -hive_capacity  =>  $self->o('goc_stats_capacity'),
        },

        {
            -logic_name => 'get_perc_above_threshold',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_perc_above_threshold',
            -flow_into => {
                1 =>    ['store_goc_dist_asTags'],
                },
            -hive_capacity  =>  $self->o('goc_stats_capacity'),
        },

        {
            -logic_name => 'store_goc_dist_asTags',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::StoreGocStatsAsMlssTags',
            -hive_capacity  =>  $self->o('goc_stats_capacity'),
        },

        
    ];
}

1;
