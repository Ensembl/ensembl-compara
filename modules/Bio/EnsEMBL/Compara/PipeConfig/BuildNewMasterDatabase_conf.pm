=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::BuildNewMasterDatabase_conf

=head1 DESCRIPTION

    Create a new master database from scratch


=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::BuildNewMasterDatabase_conf -input <path_to_regions_file(s)> -dst_host <host_master_db> -dst_port <host_port> -division <division>

    #1. clone data regions from JSON file(s) (one per species)
    #2. create a new master_db

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

=cut

package Bio::EnsEMBL::Compara::PipeConfig::BuildNewMasterDatabase_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub no_compara_schema {};

sub default_options {
    my ($self) = @_;
    return {
        # Inherit the generic default options
        %{$self->SUPER::default_options},

        'pipeline_name' => 'build_master_for_' . $self->o('division'),
        'work_dir'      => $self->o('pipeline_dir'),
        'backups_dir'   => $self->o('work_dir') . '/backups/',
        'dst_host'      => $self->o('dst_host'),
        'dst_port'      => $self->o('dst_port'),

        'master_db'   => 'compara_master',
        # 'taxonomy_db' => 'ncbi_taxonomy',

        'schema_file' => $self->check_file_in_ensembl('ensembl-compara/sql/table.sql'),
        # 'java_hc_dir' => $self->check_dir_in_ensembl('ensj-healthcheck/'),

        'clone_core_db' => $self->check_exe_in_ensembl('ensembl-test/scripts/clone_core_database.pl'),
        'rename_db' => '/nfs/software/ensembl/mysql-cmds/ensembl/bin/rename_db',
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        # Inherit creation of database, hive tables and compara tables
        @{$self->SUPER::pipeline_create_commands},

        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'backups_dir']),
    ];
}

sub pipeline_wide_parameters {
    # These parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        # Inherit anything from the base class
        %{$self->SUPER::pipeline_wide_parameters},

        'master_db'  => $self->o('master_db'),
        'division'   => $self->o('division'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'seed_species_to_clone',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -input_ids  => [{
                'input' => $self->o('input'),
            }],
            -parameters => {
                'inputcmd' => 'find #input# -type f -name "*.json"',
            },
            -flow_into  => {
                '2->A' => { 'clone_core_regions' => {'json_file' => '#_0#'} },
                            # 'create_new_master' => {} },
                'A->1' => [ 'rename_test_databases' ],
            },
        },

        {   -logic_name => 'clone_core_regions',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::CloneCoreRegions',
            -parameters => {
                'clone_core_db' => $self->o('clone_core_db'),
                'reg_conf'      => $self->o('reg_conf'),
                'dst_host'      => $self->o('dst_host'),
                'dst_port'      => $self->o('dst_port'),
                # Get the species name from JSON file path
                'species'       => '#expr( substr(#json_file#, rindex(#json_file#, "/") + 1, -5) )expr#',
            },
            # Restrict the number of running workers to one at a time to avoid overload the server
            -analysis_capacity => 1,
            -rc_name   => '500Mb_job',
            -flow_into => [ '?accu_name=cloned_dbs&accu_address={species}&accu_input_variable=dbname' ],
        },

        # {   -logic_name => 'create_new_master',
        #     -module => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        #     -parameters => {
        #         'cmd' => 'db_cmd.pl $COMPARA_REG #master_db# -sql "CREATE DATABASE"',
        #     },
        #     -flow_into => [ 'load_schema_master' ],
        # },

        # {   -logic_name => 'load_schema_master',
        #     -module => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        #     -parameters => {
        #         'schema_file'  => $self->o('schema_file'),
        #         'cmd' => 'db_cmd.pl $COMPARA_REG #master_db# < #schema_file#',
        #     },
        # },

        {   -logic_name => 'rename_test_databases',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::RenameTestDatabases',
            -parameters => {
                'rename_db' => $self->o('rename_db'),
                'reg_conf'  => $self->o('reg_conf'),
            },
            # -flow_into  => [ 'populate_master' ],
        },

        # {   -logic_name => 'populate_master',
        #     -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::PopulateMasterDatabase',
        #     -parameters => {
        #         'reg_conf'  => $self->o('reg_conf'),
        #     },
        #     # -flow_into  => [ 'rm_empty_tables_master' ],
        # },

        # {   -logic_name => 'rm_empty_tables_master',
        #     -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        #     # -flow_into  => [ 'hc_master' ],
        # },

        # {   -logic_name => 'hc_master',
        #     -module     => 'Bio::EnsEMBL::Compara::RunnableDB::RunJavaHealthCheck',
        #     -parameters => {
        #         'compara_db'  => $self->o('master_db'),
        #         'work_dir'    => $self->o('work_dir'),
        #         'testgroup'   => 'ComparaMaster',
        #         'output_file' => '#work_dir#/healthcheck.#testgroup#.out',
        #         'java_hc_dir' => $self->o('java_hc_dir'),
        #     },
        #     -rc_name         => '1Gb_job',
        #     -max_retry_count => 0,
        #     # -flow_into       => ['backup_master_again'],
        # },

        # {   -logic_name => 'backup_master',
        #     -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
        #     -parameters => {
        #         'src_db_conn' => $self->o('master_db'),
        #         'backups_dir' => $self->o('backups_dir'),
        #         'output_file' => '#backups_dir#/compara_#division#_master.sql',
        #     },
        #     -rc_name => '500Mb_job',
        # },
    ];
}

1;
