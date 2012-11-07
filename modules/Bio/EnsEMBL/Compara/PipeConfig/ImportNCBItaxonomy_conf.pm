
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::ImportNCBItaxonomy_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ImportNCBItaxonomy_conf -password <your_password> -ensembl_cvs_root_dir <path_to_your_ensembl_cvs_root>
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ImportNCBItaxonomy_conf -password <your_password>

=head1 DESCRIPTION  

    A pipeline to import NCBI taxonomy database into ncbi_taxonomy@ens-livemirror database

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ImportNCBItaxonomy_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');      # we want to treat it as a 'pure' Hive pipeline


=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.
                
                  There are rules dependent on two options that do not have defaults (this makes them mandatory):
                    o('password')       your read-write password for creation and maintenance of the hive database

=cut

sub default_options {
    my ($self) = @_;
    return {
         %{$self->SUPER::default_options},

        'pipeline_name' => 'ncbi_taxonomy',            # name used by the beekeeper to prefix job names on the farm

        'name_prefix'   => $self->o('ENV', 'USER').'_', # use a non-empty value if you want to test the pipeline
        'name_suffix'   => '_66c',                      # use a non-empty value if you want to test the pipeline

        'pipeline_db' => {
#            -host   => 'ens-livemirror',
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('name_prefix').$self->o('pipeline_name').$self->o('name_suffix'),
        },

        'taxdump_loc'   => 'ftp://ftp.ncbi.nih.gov/pub/taxonomy',   # the original location of the dump
        'taxdump_file'  => 'taxdump.tar.gz',                        # the filename of the dump

        'work_dir'      => $ENV{'HOME'}.'/ncbi_taxonomy_loading',
    };
}

=head2 pipeline_create_commands

    Description : Implements pipeline_create_commands() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that lists the commands that will create and set up the Hive database.
                  In addition to the standard creation of the database and populating it with Hive tables and procedures it also creates a working directory to store intermediate files.

=cut

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

            # additional tables that we use here (taken from ensembl-compara schema):

        $self->db_execute_command('pipeline_db', qq{
            CREATE TABLE ncbi_taxa_node (
              taxon_id                        INT(10) UNSIGNED NOT NULL,
              parent_id                       INT(10) UNSIGNED NOT NULL,

              rank                            CHAR(32) DEFAULT \"\" NOT NULL,
              genbank_hidden_flag             TINYINT(1) DEFAULT 0 NOT NULL,

              left_index                      INT(10) DEFAULT 0 NOT NULL,
              right_index                     INT(10) DEFAULT 0 NOT NULL,
              root_id                         INT(10) DEFAULT 1 NOT NULL,

              PRIMARY KEY (taxon_id),
              KEY (parent_id),
              KEY (rank),
              KEY (left_index),
              KEY (right_index)
            )
        }),

        $self->db_execute_command('pipeline_db', qq{
            CREATE TABLE ncbi_taxa_name (
              taxon_id                    INT(10) UNSIGNED NOT NULL,

              name                        VARCHAR(255),
              name_class                  VARCHAR(50),

              KEY (taxon_id),
              KEY (name),
              KEY (name_class)
            )
        }),

        'mkdir '.$self->o('work_dir'),
    ];
}

sub resource_classes {
    my ($self) = @_;
    return {
         'default' => {'LSF' => '-q yesterday' },
         'highmem' => {'LSF' => '-q yesterday -R"select[mem>3000] rusage[mem=3000]" -M3000000' },
    };
}


=head2 pipeline_analyses

    Description : Implements pipeline_analyses() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that defines the structure of the pipeline: analyses, jobs, rules, etc.


=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name    => 'download_tarball',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'cmd'       => 'curl '.$self->o('taxdump_loc').'/'.$self->o('taxdump_file').' > #work_dir#/'.$self->o('taxdump_file'),
            },
            -input_ids     => [
                { 'work_dir' => $self->o('work_dir') }
            ],
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'untar' ],
            },
        },

        {   -logic_name    => 'untar',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'cmd'       => 'cd #work_dir# ; tar -xzf #work_dir#/'.$self->o('taxdump_file'),
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'load_nodes', 'load_names' ],
            },
        },

        {   -logic_name => 'load_nodes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputfile'       => '#work_dir#/nodes.dmp',
                'delimiter'       => "\t\Q|\E\t?",
                'input_id'        => { 'taxon_id' => '#_0#', 'parent_id' => '#_1#', 'rank' => '#_2#', 'genbank_hidden_flag' => '#_10#'},
                'fan_branch_code' => 2,
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'zero_parent_id' ],
                2 => [ ':////ncbi_taxa_node' ],
            },
            -rc_name => 'highmem',
        },

        {   -logic_name    => 'zero_parent_id',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => "update ncbi_taxa_node set parent_id=0 where parent_id=taxon_id",
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'build_left_right_indices' ],
            },
        },

        {   -logic_name    => 'build_left_right_indices',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'cmd'       => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/taxonomy/taxonTreeTool.pl -url '.$self->dbconn_2_url('pipeline_db').' -index',
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -wait_for => ['load_names'],
            -rc_name => 'highmem',
        },



        {   -logic_name => 'load_names',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputfile'       => '#work_dir#/names.dmp',
                'delimiter'       => "\t\Q|\E\t?",
                'input_id'        => { 'taxon_id' => '#_0#', 'name' => '#_1#', 'name_class' => '#_3#'},
                'fan_branch_code' => 2,
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'load_merged_names' ],
                2 => [ ':////ncbi_taxa_name' ],
            },
            -rc_name => 'highmem',
        },

        {   -logic_name => 'load_merged_names',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputfile'       => '#work_dir#/merged.dmp',
                'delimiter'       => "\t\Q|\E\t?",
                'input_id'        => { 'name' => '#_0#', 'taxon_id' => '#_1#', 'name_class' => 'merged_taxon_id'},
                'fan_branch_code' => 2,
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'web_name_patches' ],
                2 => [ ':////ncbi_taxa_name' ],
            },
        },

        {   -logic_name    => 'web_name_patches',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'cmd'       => 'mysql '.$self->dbconn_2_mysql('pipeline_db', 1).' <'.$self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/taxonomy/web_name_patches.sql',
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'add_import_date' ],
            },
        },

        {   -logic_name => 'add_import_date',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => 'select distinct taxon_id, CURRENT_TIMESTAMP this_moment from ncbi_taxa_node where parent_id=0',
                'input_id'        => { 'taxon_id' => '#taxon_id#', 'name' => '#this_moment#', 'name_class' => 'import date' },
                'fan_branch_code' => 2,
            },
            -wait_for => [ 'build_left_right_indices' ],
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'cleanup' ],
                2 => [ ':////ncbi_taxa_name' ],
            },
        },

        {   -logic_name    => 'cleanup',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'work_dir'  => '/tmp/not_so_important', # make sure $self->param('work_dir') contains something by default, or else.
                'cmd'       => 'rm -rf #work_dir#',
            },
            -hive_capacity  => 10,  # to allow parallel branches
        },

    ];
}

1;

