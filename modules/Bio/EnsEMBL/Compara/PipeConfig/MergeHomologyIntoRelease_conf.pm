
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::MergeHomologyIntoRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MergeHomologyIntoRelease_conf -password <your_password>

=head1 DESCRIPTION  

    A pipeline to merge the "homology side" of the Compara release into the main release database
    (Took 2h10m to execute for release 60)

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MergeHomologyIntoRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

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

        'rel'           => 71,
        'pipeline_name' => 'compara_full_merge_'.$self->o('rel'),         # name used by the beekeeper to prefix job names on the farm

        'pipeline_db' => {
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_'.$self->o('pipeline_name'),
        },

        'merged_homology_db' => {
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => sprintf('%s_compara_homology_merged_%s', 'kb3', $self->o('rel')),
        },

        'rel_db' => {
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => sprintf('%s_ensembl_compara_%s', $self->o('ENV', 'USER'), $self->o('rel')),
        },

        # Please make sure that all the "merged_tables" also appear in "skipped_tables"
        'merged_tables'     => [ 'method_link_species_set_tag' ],
        'skipped_tables'    => [ 'meta', 'ncbi_taxa_name', 'ncbi_taxa_node', 'species_set', 'species_set_tag', 'genome_db', 'method_link', 'method_link_species_set',
                              'analysis', 'analysis_data', 'job', 'job_file', 'job_message', 'analysis_stats', 'analysis_stats_monitor', 'analysis_ctrl_rule',
                              'dataflow_rule', 'worker', 'monitor', 'resource_description', 'resource_class', 'log_message', 'analysis_base', 'method_link_species_set_tag' ],

        'copying_capacity'  => 10,                                  # how many tables can be dumped and re-created in parallel (too many will slow the process down)
    };
}

=head2 pipeline_create_commands

    Description : Implements pipeline_create_commands() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that lists the commands that will create and set up the Hive database.
                  In addition to the standard creation of the database and populating it with Hive tables and procedures it also creates a directory for storing the output.

=cut

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
    ];
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
                'fan_branch_code' => 2,
            },
            -input_ids => [
                { 'inputquery' => 'SELECT table_name AS `table` FROM information_schema.tables WHERE table_schema ="#mysql_dbname:db_conn#" AND table_name NOT IN (#csvq:skipped_tables#) AND table_rows' },
            ],
            -flow_into => {
                2 => [ 'copy_table'  ],
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
                'fan_branch_code' => 2,
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

