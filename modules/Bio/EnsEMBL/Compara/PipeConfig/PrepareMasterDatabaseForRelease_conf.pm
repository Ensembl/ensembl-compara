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

Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesIntoMaster_conf

=head1 DESCRIPTION

    Add/update all species to master database


=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PrepareMasterDatabaseForRelease_conf -password <your_password> -inputfile file_new_species_production_names.txt

    #1. fetch species from text file
    #2. add all to master_db

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

=cut

package Bio::EnsEMBL::Compara::PipeConfig::PrepareMasterDatabaseForRelease_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub no_compara_schema {};

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'host'                => 'mysql-ens-compara-prod-4:4401',
        'pipeline_name'       => 'prep_' . $self->o('division') . '_master_for_rel_' . $self->o('release'),
        #'host'               => 'mysql-ens-compara-prod-1:4485',
        'work_dir'    => '/hps/nobackup2/production/ensembl/' . $self->o( 'ENV', 'USER' ) . '/'.$self->o('pipeline_name'),
        'backups_dir' => $self->o('work_dir') . '/master_backups/',

        'reg_conf'            => $self->o( 'ENV', 'ENSEMBL_CVS_ROOT_DIR' ) .'/ensembl-compara/scripts/pipeline/production_reg_' . $self->o('division') . '_conf.pl',
        'master_db'           => 'compara_master',
        'taxonomy_db'         => 'ncbi_taxonomy',
        'release'             => $self->o( 'ENV', 'CURR_ENSEMBL_RELEASE' ),
        'division'            => $self->o( 'ENV', 'COMPARA_DIV' ),
        'incl_components'     => 1, # let's default this to 1 - will have no real effect if there are no component genomes (e.g. in vertebrates)
        'create_all_mlss_exe' => $self->o( 'ENV', 'ENSEMBL_CVS_ROOT_DIR' ) . '/ensembl-compara/scripts/pipeline/create_all_mlss.pl',
        'xml_file'            => $self->o( 'ENV', 'ENSEMBL_CVS_ROOT_DIR' ) . '/ensembl-compara/scripts/pipeline/compara_' . $self->o('division') . '.xml',
        'report_file'         => $self->o( 'work_dir' ) . '/mlss_ids_' . $self->o('division') . '.list',

        'patch_dir'   => $self->o( 'ENV', 'ENSEMBL_CVS_ROOT_DIR' ) . '/ensembl-compara/sql/',
        'schema_file' => $self->o('patch_dir') . '/table.sql',
        'alias_file'  => $self->o( 'ENV', 'ENSEMBL_CVS_ROOT_DIR' ) . '/ensembl-compara/scripts/taxonomy/ensembl_aliases.sql',
        'java_hc_dir' => $self->o('ENV', 'ENSEMBL_CVS_ROOT_DIR') . '/ensj-healthcheck/',

        'list_genomes_script'    => $self->o('ENV', 'ENSEMBL_CVS_ROOT_DIR') . '/ensembl-metadata/misc_scripts/get_list_genomes_for_division.pl',
        'report_genomes_script'  => $self->o('ENV', 'ENSEMBL_CVS_ROOT_DIR') . '/ensembl-metadata/misc_scripts/report_genomes.pl',
        'update_metadata_script' => $self->o('ENV', 'ENSEMBL_CVS_ROOT_DIR') . '/ensembl-compara/scripts/pipeline/update_master_db.pl',
        'assembly_patch_species' => undef,
        'additional_species'     => undef,
    };
}

# This section has to be filled in any derived class
sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         'default'  => {'LSF' => ['-C0 -M250 -R"select[mem>250] rusage[mem=250]"',       $reg_requirement] },
         '1Gb_job'  => {'LSF' => ['-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"',    $reg_requirement] },
         '2Gb_job'  => {'LSF' => ['-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"',    $reg_requirement] },
         '4Gb_job'  => {'LSF' => ['-C0 -M4000 -R"select[mem>4000] rusage[mem=4000]"',    $reg_requirement] },
         '16Gb_job' => {'LSF' => ['-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"', $reg_requirement] },
    };
}



sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        'mkdir -p ' . $self->o('work_dir'),
        'mkdir -p ' . $self->o('backups_dir'),
    ];
}


sub pipeline_wide_parameters {
# these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'master_db'  => $self->o('master_db'),
        'division'   => $self->o('division'),
        'release'    => $self->o('release'),
        'hc_version' => 1,
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'backup_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -input_ids  => [{
                'division'    => $self->o('division'),
                'release'     => $self->o('release'),
            }],
            -parameters => {
                'src_db_conn' => $self->o('master_db'),
                'backups_dir' => $self->o('backups_dir'),
                'output_file' => '#backups_dir#/compara_master_#division#.pre#release#.sql'
            },
            -flow_into => [ 'patch_master_db' ],
            -rc_name   => '1Gb_job'
        },

        {   -logic_name => 'patch_master_db',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::PatchMasterDB',
            -parameters => {
                'schema_file'  => $self->o('schema_file'),
                'patch_dir'    => $self->o('patch_dir'),
                'prev_release' => '#expr( #release# - 1 )expr#',
                'patch_names'  => '#patch_dir#/patch_#prev_release#_#release#_*.sql',
            },
            -flow_into => ['load_ncbi_node'],
        },

        {   -logic_name => 'load_ncbi_node',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'  => $self->o('taxonomy_db'),
                'dest_db_conn' => $self->o('master_db'),
                'mode'         => 'overwrite',
                'filter_cmd'   => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/g"',
                'table'        => 'ncbi_taxa_node',
            },
            -flow_into => ['load_ncbi_name']
        },

        {   -logic_name => 'load_ncbi_name',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'  => $self->o('taxonomy_db'),
                'dest_db_conn' => $self->o('master_db'),
                'mode'         => 'overwrite',
                'filter_cmd'   => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/g"',
                'table'        => 'ncbi_taxa_name',
            },
            -flow_into => WHEN(
                '#division# eq "vertebrates"' => 'import_aliases',
                ELSE 'hc_taxon_names',
            ),
        },

        {   -logic_name => 'import_aliases',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PatchDB',
            -parameters => {
                'db_conn'    => $self->o('master_db'),
                'patch_file' => $self->o('alias_file'),
                'ignore_failure' => 1,
                'record_output'  => 1,
            },
            -flow_into => ['hc_taxon_names'],
        },

        {   -logic_name => 'hc_taxon_names',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::SqlHealthChecks',
            -parameters => {
                'mode'    => 'taxonomy',
                'db_conn' => $self->o('master_db'),
            },
            -flow_into => [ 'update_genome_factory' ],
        },

        {   -logic_name => 'update_genome_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFactory',
            -parameters => {
                'list_genomes_script'   => $self->o('list_genomes_script'),
                'report_genomes_script' => $self->o('report_genomes_script'),
                'additional_species'    => $self->o('additional_species'),
            },
            -flow_into => {
                '2->A' => [ 'add_species_into_master' ],
                '3->A' => [ 'retire_species_from_master' ],
                '4->A' => [ 'rename_genome' ],
                'A->1' => [ 'sync_metadata' ],
            },
            -rc_name => '4Gb_job',
        },

        {   -logic_name     => 'add_species_into_master',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::AddSpeciesToMaster',
            -parameters     => { 'release' => 1 },
            -hive_capacity  => 10,
            -rc_name        => '16Gb_job',
        },

        {   -logic_name => 'retire_species_from_master',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::RetireSpeciesFromMaster',
        },

        {   -logic_name => 'rename_genome',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'db_conn' => $self->o('master_db'),
            },
        },

        {   -logic_name => 'sync_metadata',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'update_metadata_script' => $self->o('update_metadata_script'),
                'reg_conf'               => $self->o('reg_conf'),
                'master_db'              => $self->o('master_db'),
                'division'               => $self->o('division'),
                'cmd' => 'perl #update_metadata_script# --reg_conf #reg_conf# --compara #master_db# --division #division#'
            },
            -flow_into  => ['load_lrg_dnafrags'],
        },

        {   -logic_name => 'load_lrg_dnafrags',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::LoadLRGDnaFrags',
            -parameters => {
                'compara_db' => $self->o('master_db'),
            },
            -flow_into => ['assembly_patch_factory'],
        },

         {  -logic_name => 'assembly_patch_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'  => $self->o('assembly_patch_species'),
                'column_names' => ['species_name'],
            },
            -flow_into => {
                '2->A' => [ 'load_assembly_patches' ],
                'A->1' => [ 'update_collection' ],
            },
        },

        {   -logic_name => 'load_assembly_patches',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::LoadAssemblyPatches',
            -parameters => {
                'compara_db' => $self->o('master_db'),
                'work_dir'   => $self->o('work_dir'),
            },
        },

        {   -logic_name => 'update_collection',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CreateReleaseCollection',
            -parameters => {
                    'collection_name'   => $self->o('division'),
                    'incl_components'   => $self->o('incl_components'),
                    # 'release'           => $self->o('release'),
            },
            -flow_into  => [ 'add_mlss_to_master' ],
        },

        {   -logic_name => 'add_mlss_to_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'create_all_mlss_exe'   => $self->o('create_all_mlss_exe'),
                'reg_conf'              => $self->o('reg_conf'),
                'master_db'             => $self->o('master_db'),
                'xml_file'              => $self->o('xml_file'),
                'report_file'           => $self->o('report_file'),
                'cmd'                   => 'perl #create_all_mlss_exe# --reg_conf #reg_conf# --compara #master_db# -xml #xml_file# --release --output_file #report_file# --verbose',
            },
            -rc_name        => '2Gb_job',
            -flow_into => WHEN(
                '#division# eq "vertebrates"' => 'load_timetree',
                ELSE 'reset_master_urls',
            ),
        },

        {   -logic_name => 'load_timetree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::LoadTimeTree',
            -parameters => {
                  'compara_db' => $self->o('master_db'),
            },
            -flow_into => ['reset_master_urls'],
        },

        {   -logic_name => 'reset_master_urls',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
               'db_conn' => '#master_db#',
               'input_query' => 'UPDATE method_link_species_set SET url = "" WHERE source = "ensembl"',
             },
             -flow_into => ['hc_master'],
        },

        {   -logic_name => 'hc_master',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::RunJavaHealthCheck',
            -parameters => {
                'compara_db'  => $self->o('master_db'),
                'work_dir'    => $self->o('work_dir'),
                'testgroup'   => 'ComparaMaster',
                'output_file' => '#work_dir#/healthcheck.#testgroup#.out',
                'java_hc_dir' => $self->o('java_hc_dir'),
            },
            -rc_name         => '2Gb_job',
            -max_retry_count => 0,
            -flow_into       => ['backup_master_again']
        },

        {   -logic_name => 'backup_master_again',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'src_db_conn' => $self->o('master_db'),
                'backups_dir' => $self->o('backups_dir'),
                'output_file' => '#backups_dir#/compara_master_#division#.post#release#.sql'
            },
            -rc_name => '1Gb_job',
        },

        # {   -logic_name => 'backbone_pipeline_finished',
        #     -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        # },

    ];
}

1;
