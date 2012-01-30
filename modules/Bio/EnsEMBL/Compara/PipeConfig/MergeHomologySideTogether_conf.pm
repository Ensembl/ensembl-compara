
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::MergeHomologySideTogether_conf

=head1 SYNOPSIS

    #1. update all databases' names and locations

    #2. initialize the pipeline:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MergeHomologySideTogether_conf -password <your_password>

    #3. run the beekeeper.pl

=head1 DESCRIPTION  

    A pipeline to merge together the "homology side" of the Compara release: gene_trees, families and ncrna_trees.
    (Took 2.7h to execute for release 63)
    (Took 10h to execute for release 65)

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MergeHomologySideTogether_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

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

        'pipeline_name' => 'mp12_compara_homology_merged_66_test',    # name used by the beekeeper to prefix job names on the farm

        'pipeline_db' => {                                  # connection parameters
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                        # a rule where a previously undefined parameter is used (which makes either of them obligatory)
            -dbname => $self->o('ENV', 'USER').'_'.$self->o('pipeline_name'),    # a rule where a previously defined parameter is used (which makes both of them optional)
        },

            'master_db' => 'mysql://ensro@compara1/sf5_ensembl_compara_master',

#         'master_db' => {
#             -host   => 'compara1',
#             -port   => 3306,
#             -user   => 'ensro',
#             -pass   => '',
#             -dbname => 'sf5_ensembl_compara_master',
#         },

        'master_copy_tables' => [ 'genome_db', 'species_set', 'method_link', 'method_link_species_set', 'mapping_session', 'ncbi_taxa_name', 'ncbi_taxa_node', 'species_set_tag' ],

            'prevrel_db' => 'mysql://ensro@compara4/kb3_ensembl_compara_65',
#         'prevrel_db' => {
#             -host   => 'compara4',
#             -port   => 3306,
#             -user   => 'ensro',
#             -pass   => '',
#             -dbname => 'kb3_ensembl_compara_65',
#         },

        'prevrel_merge_tables' => [ 'stable_id_history' ],

            'genetrees_db' => 'mysql://ensro@compara2/mm14_compara_homology_66',
#         'genetrees_db' => {
#             -host   => 'compara2',
#             -port   => 3306,
#             -user   => 'ensadmin',
#             -pass   => $self->o('password'),
#             -dbname => 'mm14_compara_homology_66',
#         },

        'genetrees_copy_tables'  => [ 'sequence_cds', 'sequence_exon_bounded', 'subset', 'subset_member', 'protein_tree_hmmprofile', 'protein_tree_member_score' ],
        'genetrees_merge_tables' => [ 'stable_id_history', 'homology', 'homology_member' ],

            'families_db' => 'mysql://ensro@compara1/lg4_compara_families_66',
#         'families_db' => {
#             -host   => 'compara1',
#             -port   => 3306,
#             -user   => 'ensadmin',
#             -pass   => $self->o('password'),
#             -dbname => 'lg4_compara_families_66',
#         },
        'families_copy_tables'  => [ 'family', 'family_member' ],
        'families_merge_tables' => [ 'member', 'sequence', 'stable_id_history' ],

            'nctrees_db' => 'mysql://ensro@compara4/mp12_compara_nctrees_66c',
#         'nctrees_db' => {
#             -host   => 'compara4',
#             -port   => 3306,
#             -user   => 'ensadmin',
#             -pass   => $self->o('password'),
#             -dbname => 'mp12_compara_nctrees_66c',
#         },
        'nctrees_copy_tables'  => [ 'nc_profile' ],
        'nctrees_merge_tables' => [ 'member', 'sequence', 'homology', 'homology_member' ],

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
                  Here it defines four analyses:

                    * 'lr_index_offset_correction'  removes unused entries from lr_index_offset table, to simplify the merger

                    * 'generate_job_list'           generates a list of tables to be copied from master_db

                    * 'copy_table'                  dumps tables from source_db and re-creates them in pipeline_db

                    * 'merge_table'                 dumps tables from source_db and merges them into pipeline_db

=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
#         {   -logic_name => 'lr_index_offset_correction',
#             -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
#             -parameters => {
#                 'sql' => 'DELETE FROM lr_index_offset WHERE lr_index=0',
#             },
#             -input_ids => [
#                 { 'db_conn' => $self->o('pipeline_db') },
#                 { 'db_conn' => $self->o('genetrees_db') },
#                 { 'db_conn' => $self->o('nctrees_db') },
#             ],
#         },

        {   -logic_name => 'generate_job_list',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'column_names' => [ 'table' ],
                'input_id'     => { 'src_db_conn' => '#db_conn#', 'table' => '#table#' },
            },
            -input_ids => [
                { 'fan_branch_code' => 2, 'db_conn' => $self->o('master_db'),    'inputlist'  => $self->o('master_copy_tables') },
                { 'fan_branch_code' => 4, 'db_conn' => $self->o('prevrel_db'),   'inputlist'  => $self->o('prevrel_merge_tables') },

                { 'fan_branch_code' => 2, 'db_conn' => $self->o('families_db'),  'inputlist'  => $self->o('families_copy_tables') },
                { 'fan_branch_code' => 4, 'db_conn' => $self->o('families_db'),  'inputlist'  => $self->o('families_merge_tables') },

                { 'fan_branch_code' => 2, 'db_conn' => $self->o('genetrees_db'), 'inputquery' => "SHOW TABLES LIKE 'peptide\_align\_feature\_%'" },
                { 'fan_branch_code' => 2, 'db_conn' => $self->o('genetrees_db'), 'inputlist'  => $self->o('genetrees_copy_tables') },
                { 'fan_branch_code' => 4, 'db_conn' => $self->o('genetrees_db'), 'inputlist'  => $self->o('genetrees_merge_tables') },
                { 'fan_branch_code' => 4, 'db_conn' => $self->o('genetrees_db'), 'inputquery' => "SHOW TABLES LIKE 'gene\_tree\_%'" },

                { 'fan_branch_code' => 2, 'db_conn' => $self->o('nctrees_db'),   'inputlist'  => $self->o('nctrees_copy_tables') },
                { 'fan_branch_code' => 4, 'db_conn' => $self->o('nctrees_db'),   'inputlist'  => $self->o('nctrees_merge_tables') },
                { 'fan_branch_code' => 4, 'db_conn' => $self->o('nctrees_db'),   'inputquery' => "SHOW TABLES LIKE 'gene\_tree\_%'" },
            ],
#            -wait_for => [ 'lr_index_offset_correction' ],
            -flow_into => {
                2 => [ 'copy_table'  ],
                4 => [ 'merge_table' ],
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=InnoDB/ENGINE=MyISAM/"',
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
        },

        {   -logic_name    => 'merge_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'mode'          => 'topup',
            },
            -hive_capacity => 1,    # prevent several workers from updating the same table (brute force)
            -flow_into => {
                           1 => { 'myisamize_table' => { 'table' => '#table#' } },
            },
        },

        {   -logic_name    => 'myisamize_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SQLCmd',
            -parameters    => {
                               'sql' => 'ALTER TABLE #table# ENGINE=MyISAM',
                               },
            -wait_for => [ 'merge_table' ],
        },
    ];
}

1;

