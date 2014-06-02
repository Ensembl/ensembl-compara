=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::ImportNCBItaxonomy_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ImportNCBItaxonomy_conf -password <your_password> -ensembl_cvs_root_dir <path_to_your_ensembl_cvs_root>
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ImportNCBItaxonomy_conf -password <your_password>

=head1 DESCRIPTION  

    A pipeline to import NCBI taxonomy database into ncbi_taxonomy@ens-livemirror database

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

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

        # name used by the beekeeper for the database, and to prefix job names on the farm
        'pipeline_name' => 'ncbi_taxonomy'.$self->o('ensembl_release'),

        # 'pipeline_db' is defined in HiveGeneric_conf. We only need to redefine a few parameters
        'host' => 'compara3',

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

        $self->db_cmd(qq{
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

        $self->db_cmd(qq{
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
         'highmem' => {'LSF' => '-q yesterday -R"select[mem>4000] rusage[mem=4000]" -M4000' },
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
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'zero_parent_id' ],
                2 => { ':////ncbi_taxa_node' => { 'taxon_id' => '#_0#', 'parent_id' => '#_1#', 'rank' => '#_2#', 'genbank_hidden_flag' => '#_10#'} },
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
                'cmd'       => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/taxonomy/taxonTreeTool.pl -url '.$self->pipeline_url().' -index',
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
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'load_merged_names' ],
                2 => { ':////ncbi_taxa_name' => { 'taxon_id' => '#_0#', 'name' => '#_1#', 'name_class' => '#_3#'} },
            },
            -rc_name => 'highmem',
        },

        {   -logic_name => 'load_merged_names',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputfile'       => '#work_dir#/merged.dmp',
                'delimiter'       => "\t\Q|\E\t?",
            },
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'web_name_patches' ],
                2 => { ':////ncbi_taxa_name' => { 'name' => '#_0#', 'taxon_id' => '#_1#', 'name_class' => 'merged_taxon_id'} },
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
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => 'INSERT INTO ncbi_taxa_name (taxon_id, name_class, name) SELECT taxon_id, "import date", CURRENT_TIMESTAMP FROM ncbi_taxa_node WHERE parent_id=0 GROUP BY taxon_id',
            },
            -wait_for => [ 'build_left_right_indices' ],
            -hive_capacity  => 10,  # to allow parallel branches
            -flow_into => {
                1 => [ 'cleanup' ],
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

