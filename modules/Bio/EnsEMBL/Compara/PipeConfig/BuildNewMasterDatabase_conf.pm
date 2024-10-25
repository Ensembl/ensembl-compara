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

Bio::EnsEMBL::Compara::PipeConfig::BuildNewMasterDatabase_conf

=head1 SYNOPSIS

    Usage for non-test divisions:
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::BuildNewMasterDatabase_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

    #1. Create a new master database
    #2. Populate it through PrepareMasterDatabaseForRelease pipeline

    For citest division, see Bio::EnsEMBL::Compara::PipeConfig::CITest::BuildCITestMasterDatabase_conf

=head1 DESCRIPTION

Create a new master database from scratch via a predefined registry
configuration file with the desired core database(s) from where the species/
genome information will be copied.

WARNING: the previous reports and backups will be removed if the pipeline is
initialised again for the same division and release.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::BuildNewMasterDatabase_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::PrepareMasterDatabaseForRelease;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub no_compara_schema {};

sub default_options {
    my ($self) = @_;
    return {
        # Inherit the generic default options
        %{$self->SUPER::default_options},

        'pipeline_name' => 'build_new_' . $self->o('division') . '_master_for_rel_' . $self->o('rel_with_suffix'),
        'work_dir'      => $self->o('pipeline_dir'),
        'backups_dir'   => $self->o('work_dir') . '/backups/',

        'master_db'         => 'compara_master',
        'schema_file'       => $self->check_file_in_ensembl('ensembl-compara/sql/table.sql'),
        'method_link_dump'  => $self->check_file_in_ensembl('ensembl-compara/sql/method_link.txt'),
        'clone_core_db_exe' => $self->check_exe_in_ensembl('ensembl-test/scripts/clone_core_database.pl'),

        'init_reg_conf' => $self->o('reg_conf'), # needed to create the new master database
        # Parameters required for citest division only
        'reg_conf_tmpl' => undef,
        'dst_host'      => undef,
        'dst_port'      => undef,
        
        'do_clone_species' => 0,

        # PrepareMasterDatabaseForRelease pipeline configuration:
        'taxonomy_db'             => 'ncbi_taxonomy',
        'incl_components'         => 1, # let's default this to 1 - will have no real effect if there are no component genomes (e.g. in vertebrates)
        'create_all_mlss_exe'     => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/create_all_mlss.pl'),
        'xml_file'                => $self->o('config_dir') . '/mlss_conf.xml',
        'report_file'             => $self->o('work_dir') . '/mlss_ids_' . $self->o('division') . '.list',
        'annotation_file'         => undef,
        'master_backup_file'      => $self->o('backups_dir') . '/new_master_' . $self->o('division') . '.sql',
        'patch_dir'               => $self->check_dir_in_ensembl('ensembl-compara/sql/'),
        'alias_file'              => $self->check_file_in_ensembl('ensembl-compara/scripts/taxonomy/ensembl_aliases.sql'),
        'list_genomes_script'     => undef, # required but not used: do_update_from_metadata = 0
        'report_genomes_script'   => undef, # required but not used: do_update_from_metadata = 0
        'update_metadata_script'  => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/update_master_db.pl'),
        'assembly_patch_species'  => [], # by default, skip this step
        'additional_species'      => {}, # by default, skip this step
        'do_update_from_metadata' => 0,
        'do_load_timetree'        => 0,
        'meta_host'               => undef, # required but not used: do_update_from_metadata = 0
        'perc_threshold'          => undef, # required but not used: do_update_from_metadata = 0
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

        'master_db'     => $self->o('master_db'),
        'division'      => $self->o('division'),
        'release'       => $self->o('ensembl_release'),
        'hc_version'    => 1,
        
        'init_reg_conf'    => $self->o('init_reg_conf'),
        'do_clone_species' => $self->o('do_clone_species'),
        
        # Define the flags so they can be seen by Parts::PrepareMasterDatabaseForRelease
        'do_update_from_metadata' => $self->o('do_update_from_metadata'),
        'do_load_timetree'        => $self->o('do_load_timetree'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'create_new_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -input_ids  => [{}],
            -parameters => {
                'cmd'          => 'db_cmd.pl -reg_conf #init_reg_conf# -reg_type compara -reg_alias #master_db# -sql "CREATE DATABASE"',
            },
            -flow_into  => ['load_schema_master'],
        },

        {   -logic_name => 'load_schema_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'schema_file'   => $self->o('schema_file'),
                'cmd'           => 'db_cmd.pl -reg_conf #init_reg_conf# -reg_type compara -reg_alias #master_db# < #schema_file#',
            },
            -flow_into  => ['add_division_to_meta_table'],
        },

        {   -logic_name => 'add_division_to_meta_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'sql' => 'INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, "division", "#division#")',
                'cmd' => ['db_cmd.pl', -reg_conf => '#init_reg_conf#', -reg_type => 'compara', -reg_alias => '#master_db#', -sql => '#sql#']
            },
            -flow_into  => ['init_method_link_table'],
        },

        {   -logic_name => 'init_method_link_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'method_link_dump' => $self->o('method_link_dump'),
                'cmd'              => 'db_cmd.pl -reg_conf #init_reg_conf# -reg_type compara -reg_alias #master_db# -executable mysqlimport -append "--local" #method_link_dump#',
            },
            -flow_into  => WHEN(
                '#do_clone_species#' => 'seed_species_to_clone',
                ELSE 'patch_master_db'
            ),
        },

        {   -logic_name => 'seed_species_to_clone',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'config_dir' => $self->o('config_dir'),
                'inputcmd'   => 'find #config_dir#/core -type f -name "*.json"',
            },
            -flow_into  => {
                '2->A' => {'clone_core_regions' => {'json_file' => '#_0#'}},
                'A->1' => ['reconfigure_pipeline'],
            },
        },

        {   -logic_name        => 'clone_core_regions',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::CloneCoreRegions',
            -parameters        => {
                'clone_core_db_exe' => $self->o('clone_core_db_exe'),
                'dst_host'          => $self->o('dst_host'),
                # Get species name from JSON file path
                'species'           => '#expr( substr(#json_file#, rindex(#json_file#, "/") + 1, -5) )expr#',
            },
            -flow_into         => ['?accu_name=cloned_dbs&accu_address={species}'],
            # Restrict the number of running workers to one at a time to avoid overload the server
            -analysis_capacity => 4,
        },

        {   -logic_name => 'reconfigure_pipeline',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::ReconfigPipeline',
            -parameters => {
                'reg_conf'        => $self->o('reg_conf'),
                'reg_conf_tmpl'   => $self->o('reg_conf_tmpl'),
                'dst_host'        => $self->o('dst_host'),
                'dst_port'        => $self->o('dst_port'),
            },
            -flow_into  => [ 'patch_master_db' ],
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::PrepareMasterDatabaseForRelease::pipeline_analyses_prep_master_db_for_release($self) },
    ];
}

1;
