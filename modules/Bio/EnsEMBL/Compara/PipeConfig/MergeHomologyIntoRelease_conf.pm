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

Bio::EnsEMBL::Compara::PipeConfig::MergeHomologyIntoRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MergeHomologyIntoRelease_conf -password <your_password>

=head1 DESCRIPTION  

    A pipeline to merge the "homology side" of the Compara release into the main release database
    (Took 2h10m to execute for release 60)

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MergeHomologyIntoRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.
                  In addition to the standard things it defines four options:
                    o('copying_capacity')   defines how many tables can be dumped and zipped in parallel
                
                  There are rules dependent on two options that do not have defaults (this makes them mandatory):
                    o('password')       your read-write password for creation and maintenance of the hive database

=cut

sub default_options {
    my ($self) = @_;

    return {

            %{$self->SUPER::default_options},

        'pipeline_name' => 'compara_full_merge_'.$self->o('ensembl_release'),         # name used by the beekeeper to prefix job names on the farm

        'pipeline_db' => {
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_'.$self->o('pipeline_name'),
        },

        'merged_homology_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => sprintf('%s_compara_homology_merged_%s', $self->o('ENV', 'USER'), $self->o('ensembl_release')),
        },

        'rel_db' => {
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => sprintf('%s_ensembl_compara_%s', $self->o('ENV', 'USER'), $self->o('ensembl_release')),
        },

        'merged_tables'     => [ 'method_link_species_set_tag','method_link_species_set_attr',
                                 'species_tree_node', 'species_tree_root' ],
        'skipped_tables'    => [ 'dnafrag', 'genome_db', 'meta', 'ktreedist_score',
                                 'method_link', 'method_link_species_set',
                                 'ncbi_taxa_name', 'ncbi_taxa_node',
                                 'species_set', 'species_set_header', 'species_set_tag',
                                 'accu', 'analysis_base', 'analysis_ctrl_rule',
                                 'analysis_data', 'analysis_stats',
                                 'analysis_stats_monitor', 'dataflow_rule',
                                 'hive_meta', 'job', 'job_file', 'log_message',
                                 'resource_class', 'resource_description',
                                 'role', 'pipeline_wide_parameters',
                                 'worker', 'worker_resource_usage',
                               ],

        'copying_capacity'  => 10,                                  # how many tables can be dumped and re-created in parallel (too many will slow the process down)
    };
}


=head2 pipeline_analyses

    Description : Implements pipeline_analyses() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that defines the structure of the pipeline: analyses, jobs, rules, etc.
                  Here it defines two analyses:

                    * 'generate_job_list'   generates a list of tables to be copied from master_db

                    * 'copy_table'          dumps tables from source_db and re-creates them in pipeline_db

=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'generate_job_list_copy',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'         => $self->o('merged_homology_db'),
                'skipped_tables'  => $self->o('skipped_tables'),
                'merged_tables'   => $self->o('merged_tables'),
                'inputquery'      => 'SHOW TABLE STATUS WHERE Name NOT IN (#csvq:skipped_tables#) AND Name NOT IN (#csvq:merged_tables#) AND Rows',
            },
            -input_ids => [ {} ],
            -flow_into => {
                2 => { 'copy_table' => { 'table' => '#Name#' } },
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('merged_homology_db'),
                'dest_db_conn'  => $self->o('rel_db'),
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=InnoDB/ENGINE=MyISAM/"',
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
        },

        {   -logic_name => 'generate_job_list_topup',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'merged_tables' => $self->o('merged_tables'),
            },
            -input_ids => [
                { 'inputlist' => '#merged_tables#', 'column_names' => ['table'] },
            ],
            -flow_into => {
                2 => [ 'merge_table'  ],
            },
        },
        {   -logic_name    => 'merge_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('merged_homology_db'),
                'dest_db_conn'  => $self->o('rel_db'),
                'mode'          => 'topup',
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
        },
    ];
}

1;

