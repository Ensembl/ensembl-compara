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

Bio::EnsEMBL::Compara::PipeConfig::UpdateReferenceDatabase_conf

=head1 DESCRIPTION

    PipeConfig to update the reference database.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::UpdateReferenceDatabase_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpFastaDatabases;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub no_compara_schema {};

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'     => 'aqua-faang',
        'ref_db'       => 'compara_references',
        'taxonomy_db'  => 'ncbi_taxonomy',

        # how many parts should per-genome files be split into?
        'num_fasta_parts'  => 100,
        # at which id should genome_db start?
        'genome_db_offset' => 101,

        'pipeline_name' => 'aqua-faang_references_' . $self->o('rel_with_suffix'),
        'backups_dir'   => $self->o('pipeline_dir') . '/reference_db_backups/',

        # shared location to symlink to fastas for orthofinder
        'shared_fasta_dir' => $self->o('shared_hps_dir') . '/aqua-faang_fasta_symlinks/',

        # orthofinder executable
        # 'orthofinder_exe' => $self->o('orthofinder_exe'),

        # update from metadata options
        'list_genomes_script'    => $self->check_exe_in_ensembl('ensembl-metadata/misc_scripts/get_list_genomes_for_division.pl'),
        'report_genomes_script'  => $self->check_exe_in_ensembl('ensembl-metadata/misc_scripts/report_genomes.pl'),
        'update_metadata_script' => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/update_master_db.pl'),
        'meta_host' => 'mysql-ens-meta-prod-1',
        'rr_meta_name' => 'ensembl_metadata_qrp',
        'perc_threshold' => 20,

        # member loading options
        'include_reference'           => 1,
        'include_nonreference'        => 0,
        'include_patches'             => 1,
        'store_coding'                => 1,
        'store_ncrna'                 => 0,
        'store_others'                => 0,
        'store_exon_coordinates'      => 0,
        'store_related_pep_sequences' => 0, # do we want CDS sequences as well as protein sequences?
        'offset_ids'                  => 1, # offset member ids by the genome_db_id?

        # member HC options
        'allow_ambiguity_codes'         => 1,
        'only_canonical'                => 0,
        'allow_missing_cds_seqs'        => 1, # set to 0 if we store CDS (see above)
        'allow_missing_coordinates'     => 0,
        'allow_missing_exon_boundaries' => 1, # set to 0 if exon boundaries are loaded (see above)

        # member dump options
        'dump_only_canonical'   => 1,

        # create species sets options
        'create_all_mlss_exe' => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/create_all_mlss.pl'),
        'allowed_species_file'  => $self->check_file_in_ensembl('ensembl-compara/conf/' . $self->o('division') . '/allowed_species.json'),
        'xml_file'            => $self->check_file_in_ensembl('ensembl-compara/conf/' . $self->o('division') . '/mlss_conf.xml'),

        # whole dc options
        'datacheck_groups' => ['compara_references'],
        'db_type'          => ['compara'],
        'dc_type'          => ['critical'],
        'output_dir_path'  => $self->o('pipeline_dir') . '/datachecks/',
        'overwrite_files'  => 1,
        'failures_fatal'   => 1, # no DC failure tolerance
        'ref_dbname'       => 'cristig_aqua_faang_references', # to be manually passed in init if differs

        # individual dc options
        'dc_names' => ['CheckMemberIDRange'],
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},  # inherit the standard resource classes, incl. multi-threaded
    };
}

sub pipeline_create_commands {
    my ($self) = @_;

    my $results_table_sql = q/
        CREATE TABLE datacheck_results (
            submission_job_id INT,
            dbname VARCHAR(255) NOT NULL,
            passed INT,
            failed INT,
            skipped INT,
            INDEX submission_job_id_idx (submission_job_id)
        );
    /;

    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        $self->pipeline_create_commands_rm_mkdir(['pipeline_dir', 'backups_dir', 'output_dir_path']),

        # In case it doesn't exist yet
        'mkdir -p ' . $self->o('ref_member_dumps_dir'),
        'mkdir -p ' . $self->o('shared_fasta_dir'),
        'mkdir -p ' . $self->o('warehouse_dir') . '/reference_db_backups',
        # To store the Datachecks results
        $self->db_cmd($results_table_sql),
    ];
}


sub pipeline_wide_parameters {
# these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'division' => $self->o('division'),
        'ref_db'   => $self->o('ref_db'),
        'release'  => $self->o('ensembl_release'),
        'reg_conf' => $self->o('reg_conf'),

        'backups_dir'       => $self->o('backups_dir'),
        'members_dumps_dir' => $self->o('ref_member_dumps_dir'),

        'output_dir_path'  => $self->o('output_dir_path'),
        'overwrite_files'  => $self->o('overwrite_files'),
        'failures_fatal'   => $self->o('failures_fatal'),

        'email' => $self->o('email'),

    };
}

sub core_pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'backup_ref_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -input_ids  => [{ }],
            -parameters => {
                'src_db_conn' => '#ref_db#',
                'output_file' => '#backups_dir#/compara_references.pre#release#.sql'
            },
            -flow_into => [ 'load_ncbi_node' ],
            -rc_name   => '1Gb_job'
        },

        {   -logic_name => 'load_ncbi_node',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'  => $self->o('taxonomy_db'),
                'dest_db_conn' => '#ref_db#',
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
                'dest_db_conn' => '#ref_db#',
                'mode'         => 'overwrite',
                'filter_cmd'   => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/g"',
                'table'        => 'ncbi_taxa_name',
            },
            -flow_into  => ['hc_taxon_names'],
        },

        {   -logic_name => 'hc_taxon_names',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::SqlHealthChecks',
            -parameters => {
                'mode'    => 'taxonomy',
                'db_conn' => '#ref_db#',
            },
            -flow_into  => ['offset_table'],
        },

        {   -logic_name => 'offset_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'genome_db_offset' => $self->o('genome_db_offset'),
                'db_conn'          => '#ref_db#',
                'sql'              => [ 'ALTER TABLE genome_db AUTO_INCREMENT=#genome_db_offset#' ],
            },
            -flow_into      => [ 'update_genome_from_metadata_factory' ],
        },

        {   -logic_name => 'update_genome_from_metadata_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromMetadataFactory',
            -parameters => {
                'list_genomes_script'   => $self->o('list_genomes_script'),
                'report_genomes_script' => $self->o('report_genomes_script'),
                'work_dir'              => $self->o('pipeline_dir'),
                'meta_host'             => $self->o('meta_host'),
                'rr_meta_name'          => $self->o('rr_meta_name'),
                'allowed_species_file'  => $self->o('config_dir') . '/allowed_species.json',
                'perc_threshold'        => $self->o('perc_threshold'),
                'division'              => undef,  # our references cover every division
                'master_db'             => '#ref_db#',
            },
            -rc_name    => '1Gb_job',
            -flow_into  => {
                '2->A' => [ 'update_reference_genome' ],
                '3->A' => [ 'retire_reference' ],
                '4->A' => [ 'rename_reference_genome' ],
                '5->A' => [ 'verify_genome' ],
                'A->1' => [ 'flow_pre_collection_dcs' ],
            },
        },

        {   -logic_name    => 'update_reference_genome',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ReferenceGenomes::UpdateReferenceGenome',
            -parameters    => {
                'compara_db' => '#ref_db#',
            },
            -hive_capacity => 10,
            -rc_name       => '500Mb_job',
            -flow_into     => ['load_members'],
        },

        {   -logic_name => 'load_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {
                'compara_db'                  => '#ref_db#',
                'store_related_pep_sequences' => $self->o('store_related_pep_sequences'),
                'include_reference'           => $self->o('include_reference'),
                'include_nonreference'        => $self->o('include_nonreference'),
                'include_patches'             => $self->o('include_patches'),
                'store_coding'                => $self->o('store_coding'),
                'store_ncrna'                 => $self->o('store_ncrna'),
                'store_others'                => $self->o('store_others'),
                'store_exon_coordinates'      => $self->o('store_exon_coordinates'),
                'offset_ids'                  => $self->o('offset_ids'),
            },
            -hive_capacity => 10,
            -rc_name => '4Gb_job',
            -flow_into  => ['hc_members_per_genome'],
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                'db_conn'                       => '#ref_db#',
                'mode'                          => 'members_per_genome',
                'allow_ambiguity_codes'         => $self->o('allow_ambiguity_codes'),
                'only_canonical'                => $self->o('only_canonical'),
                'allow_missing_cds_seqs'        => $self->o('allow_missing_cds_seqs'),
                'allow_missing_coordinates'     => $self->o('allow_missing_coordinates'),
                'allow_missing_exon_boundaries' => $self->o('allow_missing_exon_boundaries')
            },
            -rc_name   => '1Gb_job',
            -flow_into => ['dump_full_fasta'],
        },

        {   -logic_name => 'retire_reference',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::RetireSpecies',
            -parameters => {
                'compara_db' => '#ref_db#',
            }
        },

        {   -logic_name    => 'rename_reference_genome',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ReferenceGenomes::RenameReferenceGenome',
            -parameters    => {
                'compara_db'            => '#ref_db#',
                'allowed_species_file'  => $self->o('allowed_species_file'),
                'xml_file'              => $self->o('xml_file'),
            },
            -hive_capacity => 10,
        },

        {   -logic_name    => 'verify_genome',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::VerifyGenome',
            -parameters => {
                'compara_db' => '#ref_db#',
            },
            -hive_capacity => 10,
            -rc_name       => '16Gb_job',
        },

        {   -logic_name    => 'flow_pre_collection_dcs',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into     => {
                '1->A' =>  { 'datacheck_fan' => { 'db_type' => $self->o('db_type'), 'compara_db' => '#ref_db#', 'registry_file' => undef, 'datacheck_names' => $self->o('offset_ids') ? $self->o('dc_names') : [] } },
                'A->1' => [ 'update_collection' ],
            }
        },

        {   -logic_name => 'update_collection',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CreateReleaseCollection',
            -parameters => {
                'collection_name' => '#division#',
                'master_db'       => '#ref_db#',
                'incl_components' => 0,
            },
            -flow_into  => [ 'create_reference_sets' ],
        },

        {   -logic_name => 'create_reference_sets',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'create_all_mlss_exe' => $self->o('create_all_mlss_exe'),
                'reg_conf'            => $self->o('reg_conf'),
                'xml_file'            => $self->o('xml_file'),
                'cmd'                 => 'perl #create_all_mlss_exe# --reg_conf #reg_conf# --compara #ref_db# -xml #xml_file# --release --verbose',
            },
            -flow_into  => {
                '1->A'  => { 'datacheck_factory' => { 'datacheck_groups' => $self->o('datacheck_groups'), 'db_type' => $self->o('db_type'), 'compara_db' => '#ref_db#', 'registry_file' => undef, 'datacheck_types' => $self->o('dc_type') }},
                'A->1'  => [ 'backup_ref_db_again' ],
                1       => [ 'fasta_dumps_per_collection_factory' ],

            },
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'fasta_dumps_per_collection_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PassFastaDumpsPerCollection',
            -parameters => {
                'symlink_dir'          => $self->o('shared_fasta_dir'),
                'ref_member_dumps_dir' => $self->o('ref_member_dumps_dir'),
                'compara_db'           => '#ref_db#',
            },
            -flow_into  => {
                1 => [ 'symlink_fasta_to_shared_loc' ],
            },
        },

        {   -logic_name => 'symlink_fasta_to_shared_loc',
            -module     => 'ensembl.compara.runnable.SymlinkFasta',
            -language   => 'python3',
            -parameters => {
                'symlink_fasta_exe' => $self->o('symlink_fasta_exe'),
            },
        },

        {   -logic_name => 'backup_ref_db_again',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'src_db_conn' => '#ref_db#',
                'output_file' => '#backups_dir#/compara_references.post#release#.sql'
            },
            -flow_into  => [ 'copy_backups_to_warehouse' ],
            -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'copy_backups_to_warehouse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'warehouse_dir' => $self->o('warehouse_dir'),
                'cmd'           => 'rsync -aW #backups_dir#/*.sql #warehouse_dir#/reference_db_backups/',
            },
            -flow_into => {
                1 => [ 'notify_done_by_email' ],
            },
        },

        {   -logic_name => 'notify_done_by_email',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::NotifyByEmail',
            -parameters => {
                'text'  => 'The rapid release references pipeline has completed.',
            },
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpFastaDatabases::pipeline_analyses_dump_fasta_dbs($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory::pipeline_analyses_datacheck_factory($self) },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'dump_full_fasta'}->{'-parameters'}->{'compara_db'} = '#ref_db#';
    $analyses_by_name->{'dump_full_fasta'}->{'-parameters'}->{'only_canonical'} = $self->o('dump_only_canonical');
    delete $analyses_by_name->{'datacheck_fan'}->{'-flow_into'}->{2};
    delete $analyses_by_name->{'datacheck_fan_high_mem'}->{'-flow_into'}->{2};
    $analyses_by_name->{'datacheck_factory'}->{'-parameters'}->{'compara_db'} = '#ref_db#';
    $analyses_by_name->{'datacheck_fan'}->{'-parameters'}->{'compara_db'} = '#ref_db#';
    $analyses_by_name->{'datacheck_fan'}->{'-parameters'}->{'old_server_uri'} = ['#ref_db#'];
    $analyses_by_name->{'datacheck_fan'}->{'-flow_into'}->{0} = ['jira_ticket_creation'];
    $analyses_by_name->{'datacheck_fan_high_mem'}->{'-flow_into'}->{0} = ['jira_ticket_creation'];
    $analyses_by_name->{'store_results'}->{'-parameters'}->{'dbname'} = $self->o('ref_dbname');

}
1;
