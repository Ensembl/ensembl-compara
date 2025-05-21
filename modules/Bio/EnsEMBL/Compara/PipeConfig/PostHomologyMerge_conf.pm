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

Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION

This pipeline combines a few steps that are run after having merged the
homology-side of things from each gene-tree pipeline into the release database:
    - Generate the MLSS tag 'perc_orth_above_wga_thresh' combining the WGA stats
      from both gene-tree pipelines
    - Update the 'gene_member_hom_stats' table

=cut


package Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf;

use strict;
use warnings;


use Bio::EnsEMBL::Hive::Version v2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'master_db'       => 'compara_master',
        'compara_db'      => 'compara_curr',

        'homology_method_types'      => ['ENSEMBL_ORTHOLOGUES', 'ENSEMBL_PARALOGUES', 'ENSEMBL_HOMOEOLOGUES'],
        'per_mlss_homology_dump_dir' => $self->o('pipeline_dir') . '/' . 'homologies',

        # Datacheck parameters
        'db_type'         => 'compara',
        'output_dir_path' => $self->o('pipeline_dir') . '/' . 'datachecks',
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}

sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},

        $self->pipeline_create_commands_rm_mkdir(['output_dir_path', 'per_mlss_homology_dump_dir']),
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'master_db'             => $self->o('master_db'),
        'compara_db'            => $self->o('compara_db'),
        'db_conn'               => $self->o('compara_db'),

        'homology_method_types'      => $self->o('homology_method_types'),
        'per_mlss_homology_dump_dir' => $self->o('per_mlss_homology_dump_dir'),

        # Datacheck parameters
        'db_type'         => $self->o('db_type'),
        'output_dir_path' => $self->o('output_dir_path'),
    }
}

sub core_pipeline_analyses {
    my ($self) = @_;

    return [
        {   -logic_name => 'summarise_wga_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SummariseWGAStats',
            -input_ids  => [ {} ],
            -flow_into  => 'check_homology_ranges',
        },

        {   -logic_name => 'check_homology_ranges',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -parameters => {
                'datacheck_names' => [ 'HomologyRanges' ],
                'registry_file'   => $self->o('reg_conf'),
            },
            -flow_into  => 'homology_dumps_mlss_id_factory',
        },

        {   -logic_name => 'homology_dumps_mlss_id_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory',
            -parameters => {
                'methods' => {
                    'ENSEMBL_HOMOEOLOGUES' => 2,
                    'ENSEMBL_ORTHOLOGUES' => 2,
                    'ENSEMBL_PARALOGUES' => 2,
                },
                'line_count' => 1,
            },
            -flow_into => {
                '2->A' => ['dump_per_mlss_homologies_tsv'],
                'A->1' => ['homology_dump_funnel_check'],
            },
        },

        {   -logic_name => 'dump_per_mlss_homologies_tsv',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpHomologiesTSV',
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'hashed_id'   => '#expr(dir_revhash(#mlss_id#))expr#',
                'output_file' => '#per_mlss_homology_dump_dir#/#hashed_id#/#mlss_id#.homologies.tsv',
                'input_query' => q/
                    SELECT
                        hm1.gene_member_id,
                        hm2.gene_member_id AS homology_gene_member_id
                    FROM
                        homology h
                    JOIN
                        homology_member hm1 USING (homology_id)
                    JOIN
                        homology_member hm2 USING (homology_id)
                    WHERE
                        hm1.gene_member_id < hm2.gene_member_id
                        #extra_filter#
                /,
                'healthcheck_list' => [
                    'line_count',
                    'unexpected_nulls',
                ],
            },
            -hive_capacity => 50,
        },

        {   -logic_name => 'homology_dump_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => 'hom_stats_genome_factory',
        },

        {   -logic_name => 'hom_stats_genome_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'all_in_current_gene_trees' => 1,
            },
            -rc_name    => '4Gb_job',
            -flow_into  => { 2 => 'update_genome_hom_stats' },
        },

        {   -logic_name => 'update_genome_hom_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::UpdateGenomeHomologyStats',
            -hive_capacity => 5,
        },
    ];
}

1;
