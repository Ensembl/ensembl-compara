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

Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers

=head1 DESCRIPTION

The PipeConfig file for the pipeline that loads the ncbi tables and core
genome_dbs

=cut


package Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub pipeline_analyses_copy_ncbi_and_core_genome_db {
    my ($self) = @_;

    my %hc_analysis_params = (
            -analysis_capacity  => 150,
            -priority           => -10,
            -batch_size         => 20,
    );

    return [
        {   -logic_name => 'copy_ncbi_tables_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name' ],
                'column_names' => [ 'table' ],
            },
            -flow_into  => {
                '2->A' => [ 'copy_ncbi_table'  ],
                'A->1' => [ 'locate_and_add_genomes' ],
            },
        },

        {   -logic_name    => 'copy_ncbi_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => '#ncbi_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
        },

        {   -logic_name    => 'locate_and_add_genomes',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::AddRapidSpecies',
            -hive_capacity => 10,
            -rc_name       => '16Gb_job',
            -flow_into     => {
                1 => [ 'load_query_genomedb_factory', 'insert_method_link' ],
                2 => { 'create_homology_mlss' => { 'species_set_name' => '#species_name#', 'genome_db_id' => '#genome_db_id#' } },
            },
        },

        {   -logic_name    => 'insert_method_link',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql' => "INSERT INTO method_link VALUES ('204', 'ENSEMBL_HOMOLOGUES', 'Homology.homology', 'homologues')"
            },
        },

        {   -logic_name    => 'create_homology_mlss',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'create_mlss_exe' => $self->o('create_mlss_exe'),
                'cmd'             => 'printf "\ny\n" | perl #create_mlss_exe# --compara #master_db# --url #master_db# --method_link_type ENSEMBL_HOMOLOGUES --species_set_name #species_set_name# --name "#species_set_name# homologues" --genome_db_id #genome_db_id# --source ensembl',
            },
            -wait_for      => [ 'insert_method_link' ],
        },

        {   -logic_name => 'load_query_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => $self->o('master_db'),   # that's where genome_db_ids come from
                'all_current'       => 1,
                'extra_parameters'  => [ 'locator' ],
            },
            -rc_name    => '4Gb_job',
            -flow_into  => {
                '2->A' => {
                    'load_genomedb' => { 'genome_db_id' => '#genome_db_id#', 'locator' => '#locator#', 'master_dbID' => '#genome_db_id#' },
                },
                'A->1' => [ 'hc_members_globally' ],
            },
        },

        {   -logic_name    => 'load_genomedb',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters    => {
                'db_version'      => $self->o('ensembl_release'),
                'registry_files'  => $self->o('curr_file_sources_locs'),
            },
            -flow_into     => {
                1 => [ 'load_fresh_members_from_db' ],
            },
            -hive_capacity => 30,
            -rc_name       => '2Gb_job',
        },

        {   -logic_name    => 'load_fresh_members_from_db',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters    => {
                'include_reference'           => $self->o('include_reference'),
                'include_nonreference'        => $self->o('include_nonreference'),
                'include_patches'             => $self->o('include_patches'),
                'store_coding'                => $self->o('store_coding'),
                'store_ncrna'                 => $self->o('store_ncrna'),
                'store_others'                => $self->o('store_others'),
                'store_exon_coordinates'      => $self->o('store_exon_coordinates'),
                'store_related_pep_sequences' => $self->o('store_related_pep_sequences'),
                'compara_db'                  => $self->o('compara_db'),
                'master_db'                   => $self->o('master_db'),
                'skip_dna'                    => $self->o('skip_dna'),
            },
            -hive_capacity => 10,
            -rc_name       => '4Gb_job',
            -flow_into     => ['hc_members_per_genome'],
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                'mode'                          => 'members_per_genome',
                'allow_ambiguity_codes'         => $self->o('allow_ambiguity_codes'),
                'only_canonical'                => $self->o('only_canonical'),
                'allow_missing_cds_seqs'        => $self->o('allow_missing_cds_seqs'),
                'allow_missing_coordinates'     => $self->o('allow_missing_coordinates'),
                'allow_missing_exon_boundaries' => $self->o('allow_missing_exon_boundaries'),
            },
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_members_globally',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode   => 'members_globally',
            },
            -flow_into          => [ 'insert_member_projections' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'insert_member_projections',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::InsertMemberProjections',
            -parameters => {
                'source_species_names'  => $self->o('projection_source_species_names'),
            },
        },

    ];
}

1;
