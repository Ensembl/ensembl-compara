
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::MergeHomologySideForRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MergeHomologySideForRelease_conf -password <your_password>

=head1 DESCRIPTION  

    A pipeline to merge together the "homology side" of the Compara release: gene_trees, families and ncrna_trees.

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MergeHomologySideForRelease_conf;

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
        'ensembl_cvs_root_dir' => $ENV{'HOME'}.'/work',     # some Compara developers might prefer $ENV{'HOME'}.'/ensembl_main'

        'pipeline_name' => 'compara_homology_merged',       # name used by the beekeeper to prefix job names on the farm

        'pipeline_db' => {                                  # connection parameters
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                        # a rule where a previously undefined parameter is used (which makes either of them obligatory)
            -dbname => $ENV{USER}.'_'.$self->o('pipeline_name'),    # a rule where a previously defined parameter is used (which makes both of them optional)
        },

        'master_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_master',
        },
        'master_copy_tables' => [ 'genome_db', 'species_set', 'method_link', 'method_link_species_set', 'mapping_session', 'ncbi_taxa_name', 'ncbi_taxa_node', 'species_set_tag' ],

        'prevrel_db' => {
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'ensembl_compara_58',
        },
        'prevrel_merge_tables' => [ 'stable_id_history' ],
        
        'genetrees_db' => {
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'lg4_compara_homology_59',
        },
        'genetrees_copy_tables'  => [ 'lr_index_offset', 'sequence_cds', 'sequence_exon_bounded', 'subset', 'subset_member' ],
        'genetrees_merge_tables' => [ 'member', 'sequence', 'stable_id_history', 'homology', 'homology_member' ],

        'families_db' => {
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'lg4_compara_families_59',
        },
        'families_copy_tables'  => [ 'family', 'family_member' ],
        'families_merge_tables' => [ 'member', 'sequence', 'stable_id_history' ],

        'nctrees_db' => {
            -host   => 'ens-research',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'avilella_compara_nc_59b',
        },
        'nctrees_copy_tables'  => [ 'nc_profile', 'nc_tree_member', 'nc_tree_node', 'nc_tree_tag' ],
        'nctrees_merge_tables' => [ 'member', 'sequence', 'homology', 'homology_member' ],

        'copying_capacity'  => 10,                                  # how many tables can be dumped and re-created in parallel
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

                    * 'merge_table'         dumps tables from source_db and merges them into pipeline_db

=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'generate_job_list',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'input_id' => { 'source_myconn' => '#mysql_conn:db_conn#', 'table_name' => '#_range_start#' },
            },
            -input_ids => [
                { fan_branch_code => 2, 'db_conn' => $self->o('master_db'),    'inputlist' => $self->o('master_copy_tables') },
                { fan_branch_code => 4, 'db_conn' => $self->o('prevrel_db'),   'inputlist' => $self->o('prevrel_merge_tables') },

                { fan_branch_code => 2, 'db_conn' => $self->o('families_db'),  'inputlist' => $self->o('families_copy_tables') },
                { fan_branch_code => 4, 'db_conn' => $self->o('families_db'),  'inputlist' => $self->o('families_merge_tables') },

                { fan_branch_code => 2, 'db_conn' => $self->o('genetrees_db'), 'inputquery' => "SHOW TABLES LIKE 'protein\_tree\_%'" },
                { fan_branch_code => 2, 'db_conn' => $self->o('genetrees_db'), 'inputquery' => "SHOW TABLES LIKE 'super\_protein\_tree\_%'" },
                { fan_branch_code => 2, 'db_conn' => $self->o('genetrees_db'), 'inputquery' => "SHOW TABLES LIKE 'peptide\_align\_feature\_%'" },
                { fan_branch_code => 2, 'db_conn' => $self->o('genetrees_db'), 'inputlist' => $self->o('genetrees_copy_tables') },
                { fan_branch_code => 4, 'db_conn' => $self->o('genetrees_db'), 'inputlist' => $self->o('genetrees_merge_tables') },

                { fan_branch_code => 2, 'db_conn' => $self->o('nctrees_db'),   'inputlist' => $self->o('nctrees_copy_tables') },
                { fan_branch_code => 4, 'db_conn' => $self->o('nctrees_db'),   'inputlist' => $self->o('nctrees_merge_tables') },
            ],
            -flow_into => {
                2 => [ 'copy_table'  ],
                4 => [ 'merge_table' ],
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'dest_myconn' => $self->dbconn_2_mysql('pipeline_db', 1),
                'cmd'         => 'mysqldump #source_myconn# #table_name# | mysql #dest_myconn#',
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
        },

        {   -logic_name    => 'merge_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'dest_myconn' => $self->dbconn_2_mysql('pipeline_db', 1),
                'cmd'         => 'mysqldump #source_myconn# --no-create-info --insert-ignore #table_name# | mysql #dest_myconn#',
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
        },
    ];
}

1;

