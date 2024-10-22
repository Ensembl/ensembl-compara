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

Bio::EnsEMBL::Compara::PipeConfig::Parts::PrepareMasterDatabaseForRelease

=head1 DESCRIPTION

    This is a partial PipeConfig for most part of the PrepareMasterDatabaseForRelease
    pipeline. This will update the NCBI taxonomy, add/update all species to master
    database, update master database's metadata, and update collections and mlss.
    Finally, it will run the datachecks and perform a backup of the updated master
    database.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::PrepareMasterDatabaseForRelease;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub pipeline_analyses_prep_master_db_for_release {
    my ($self) = @_;
    return [
        {   -logic_name => 'patch_master_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => [$self->o('patch_db_exe'), '--reg_conf', $self->o('reg_conf'), '--reg_alias', '#master_db#', '--fix', '--oldest', '#oldest_patch_release#', '--nointeractive'],
                'oldest_patch_release' => $self->o('rel_with_suffix'),
            },
            -flow_into  => ['check_ncbi_taxa_consistency'],
        },

        {   -logic_name => 'check_ncbi_taxa_consistency',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'ncbi_taxa_hosts' => 'mysql-ens-sta-1,mysql-ens-sta-1-b,mysql-ens-sta-3,mysql-ens-sta-3-b,mysql-ens-sta-4',
                'cmd'             => join(' ', (
                    $self->o('check_ncbi_taxa_exe'),
                    '--release',
                    $self->o('ensembl_release'),
                    '--hosts',
                    '#ncbi_taxa_hosts#',
                )),
            },
            -flow_into  => ['load_ncbi_node']
        },

        {   -logic_name => 'load_ncbi_node',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'  => $self->o('taxonomy_db'),
                'dest_db_conn' => '#master_db#',
                'mode'         => 'overwrite',
                'filter_cmd'   => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/g"',
                'table'        => 'ncbi_taxa_node',
            },
            -flow_into  => ['load_ncbi_name']
        },

        {   -logic_name => 'load_ncbi_name',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'  => $self->o('taxonomy_db'),
                'dest_db_conn' => '#master_db#',
                'mode'         => 'overwrite',
                'filter_cmd'   => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/g"',
                'table'        => 'ncbi_taxa_name',
            },
            -flow_into  => ['import_aliases'],
        },

        {   -logic_name => 'import_aliases',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PatchDB',
            -parameters => {
                'db_conn'        => '#master_db#',
                'patch_file'     => $self->o('alias_file'),
                'ignore_failure' => 1,
                'record_output'  => 1,
            },
            -flow_into  => ['hc_taxon_names'],
        },

        {   -logic_name => 'hc_taxon_names',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::SqlHealthChecks',
            -parameters => {
                'mode'    => 'taxonomy',
                'db_conn' => '#master_db#',
            },
            -flow_into  => ['assembly_patch_factory'],
        },

        {   -logic_name => 'assembly_patch_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => $self->o('assembly_patch_species'),
                'column_names' => ['species_name'],
            },
            -flow_into  => {
                '2->A' => [ 'list_assembly_patches' ],
                'A->1' => WHEN(
                    '#do_update_from_metadata#' => 'update_genome_from_metadata_factory',
                    ELSE 'update_genome_from_registry_factory',
                ),
            },
        },

        {   -logic_name => 'list_assembly_patches',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::ListChangedAssemblyPatches',
            -parameters => {
                'compara_db' => '#master_db#',
                'work_dir'   => $self->o('work_dir'),
            },
        },

        {   -logic_name => 'update_genome_from_metadata_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromMetadataFactory',
            -parameters => {
                'list_genomes_script'   => $self->o('list_genomes_script'),
                'report_genomes_script' => $self->o('report_genomes_script'),
                'work_dir'              => $self->o('work_dir'),
                'annotation_file'       => $self->o('annotation_file'),
                'meta_host'             => $self->o('meta_host'),
                'allowed_species_file'  => $self->o('config_dir') . '/allowed_species.json',
                'perc_threshold'        => $self->o('perc_threshold'),
            },
            -flow_into  => {
                '2->A' => [ 'add_species_into_master' ],
                '3->A' => [ 'retire_species_from_master' ],
                '4->A' => [ 'rename_genome' ],
                '5->A' => [ 'verify_genome' ],
                'A->1' => [ 'sync_metadata' ],
            },
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'update_genome_from_registry_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromRegFactory',
            -parameters => {
                'master_db' => $self->o('master_db'),
            },
            -flow_into  => {
                '2->A' => [ 'add_species_into_master' ],
                '3->A' => [ 'retire_species_from_master' ],
                '5->A' => [ 'verify_genome' ],
                'A->1' => [ 'sync_metadata' ],
            },
            -rc_name    => '2Gb_job',
        },

        {   -logic_name    => 'add_species_into_master',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::AddSpeciesToMaster',
            -parameters    => { 'release' => 1 },
            -hive_capacity => 10,
            -rc_name       => '2Gb_job',
        },

        {   -logic_name => 'retire_species_from_master',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::RetireSpeciesFromMaster',
        },

        {   -logic_name => 'rename_genome',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::RenameGenome',
            -parameters => {
                'prev_dbs'          => $self->o('prev_dbs'),
                'xml_file'          => $self->o('xml_file'),
                'species_trees'     => $self->o('species_trees'),
                'genome_dumps_dir'  => $self->o('genome_dumps_dir'),
                'sketch_dir'        => $self->o('sketch_dir'),
            },
        },

        {   -logic_name    => 'verify_genome',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::VerifyGenome',
            -parameters => {
                'compara_db'        => $self->o('master_db'),
            },
            -hive_capacity => 10,
            -rc_name       => '4Gb_job',
        },

        {   -logic_name => 'sync_metadata',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'update_metadata_script' => $self->o('update_metadata_script'),
                'reg_conf'               => $self->o('reg_conf'),
                'cmd'                    => 'perl #update_metadata_script# --reg_conf #reg_conf# --compara #master_db#',
            },
            -flow_into  => [ 'update_collection' ],
        },

        {   -logic_name => 'update_collection',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CreateReleaseCollection',
            -parameters => {
                'collection_name' => '#division#',
                'incl_components' => $self->o('incl_components'),
            },
            -flow_into  => [ 'add_mlss_to_master' ],
        },

        {   -logic_name => 'add_mlss_to_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'create_all_mlss_exe' => $self->o('create_all_mlss_exe'),
                'reg_conf'            => $self->o('reg_conf'),
                'xml_file'            => $self->o('xml_file'),
                'report_file'         => $self->o('report_file'),
                'cmd'                 => 'perl #create_all_mlss_exe# --reg_conf #reg_conf# --compara #master_db# -xml #xml_file# --release --output_file #report_file# --verbose --retire_unmatched_of_type ENSEMBL_ORTHOLOGUES',
            },
            -flow_into  => [ 'tag_alignments_being_patched' ],
        },

        {   -logic_name => 'tag_alignments_being_patched',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::TagAlignmentsBeingPatched',
            -parameters => {
                'work_dir' => $self->o('work_dir'),
            },
            -flow_into  => [ 'retire_old_species_sets' ],
        },

        {   -logic_name => 'retire_old_species_sets',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                'db_conn'     => '#master_db#',
                'input_query' => 'UPDATE species_set_header JOIN (SELECT species_set_id, MAX(method_link_species_set.last_release) AS highest_last_release FROM species_set_header JOIN method_link_species_set USING (species_set_id) WHERE species_set_header.first_release IS NOT NULL AND species_set_header.last_release IS NULL GROUP BY species_set_id HAVING SUM(method_link_species_set.first_release IS NOT NULL AND method_link_species_set.last_release IS NULL) = 0) _t USING (species_set_id) SET last_release = highest_last_release;',
             },
            -flow_into  => WHEN(
                '#do_load_timetree#' => 'load_timetree',
                ELSE 'reset_master_urls',
            ),
        },

        {   -logic_name => 'load_timetree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::LoadTimeTree',
            -parameters => {
                'compara_db' => '#master_db#',
            },
            -flow_into  => [ 'reset_master_urls' ],
        },

        {   -logic_name => 'reset_master_urls',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                'db_conn'     => '#master_db#',
                'input_query' => 'UPDATE method_link_species_set SET url = "" WHERE source = "ensembl" AND method_link_id NOT IN (22, 23, 26)',
            },
            -flow_into  => [ 'dc_master' ],
        },

        {   -logic_name      => 'dc_master',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::RunDataChecks',
            -parameters      => {
                'datacheck_groups' => ['compara_master'],
                'work_dir'         => $self->o('work_dir'),
                'history_file'     => '#work_dir#/datacheck.compara_master.history.json',
                'output_file'      => '#work_dir#/datacheck.compara_master.tap.txt',
                'failures_fatal'   => 1,
                'datacheck_types'  => ['critical'],
                'registry_file'    => $self->o('reg_conf'),
                'compara_db'       => '#master_db#',
            },
            -flow_into      => {
                1 => { 'backup_master' => {} },
            },
            -max_retry_count => 0,
            -rc_name         => '1Gb_job',
        },

        {   -logic_name => 'backup_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'src_db_conn' => '#master_db#',
                'output_file' => $self->o('master_backup_file'),
            },
            -flow_into  => [ 'copy_pre_backup_to_warehouse' ],
            -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'copy_pre_backup_to_warehouse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'backups_dir'   => $self->o('backups_dir'),
                'warehouse_dir' => $self->o('warehouse_dir'),
                'cmd'           => 'cp #backups_dir#/compara_master_#division#.pre#release#.sql #warehouse_dir#/master_db_dumps/ensembl_compara_master_#division#.$(date "+%Y%m%d").pre#release#.sql',
            },
            -flow_into  => [ 'copy_post_backup_to_warehouse' ],
        },

        {   -logic_name => 'copy_post_backup_to_warehouse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'backups_dir'   => $self->o('backups_dir'),
                'warehouse_dir' => $self->o('warehouse_dir'),
                'cmd'           => 'cp #backups_dir#/compara_master_#division#.post#release#.sql #warehouse_dir#/master_db_dumps/ensembl_compara_master_#division#.$(date "+%Y%m%d").during#release#.sql',
            },
            -flow_into  => WHEN(
                '#do_update_from_metadata#' => 'copy_annotations_to_shared_loc'
            ),
        },

        {   -logic_name => 'copy_annotations_to_shared_loc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'annotation_file' => $self->o('annotation_file'),
                'shared_hps_dir'  => $self->o('shared_hps_dir'),
                'cmd'             => 'install -C --mode=664 #annotation_file# #shared_hps_dir#/genome_reports/',
            },
	    -flow_into  => [ 'copy_json_reports_to_shared_loc' ],
        },

        {   -logic_name => 'copy_json_reports_to_shared_loc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'work_dir'        => $self->o('work_dir'),
                'shared_hps_dir'  => $self->o('shared_hps_dir'),
                'cmd'             => 'install -C --mode=664 -t #shared_hps_dir#/genome_reports/ #work_dir#/report_updates.*.json',
            },
        },
    ];
}

1;
