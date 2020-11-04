=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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
                -flow_into => {
                    '2->A' => [ 'copy_ncbi_table'  ],
                    #'A->1' => [ 'load_query_genomedb_factory', 'load_reference_genomedb_factory' ],
                    'A->1' => [ 'load_query_genomedb_factory' ],
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

            {   -logic_name => 'load_query_genomedb_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
                -parameters => {
                    'compara_db'        => $self->o('master_db'),   # that's where genome_db_ids come from
                    'species_set_id'    => $self->o('species_set_id'),
                    # Add the locators coming from member_db
                    'extra_parameters'  => [ 'locator' ],
                },
                -rc_name   => '4Gb_job',
                -flow_into => {
                    '2->A' => {
                        'load_genomedb' => { 'genome_db_id' => '#genome_db_id#', 'locator' => '#locator#', 'master_dbID' => '#genome_db_id#' },
                    },
                    'A->1' => [ 'hc_members_globally' ],
                },
            },

            {   -logic_name => 'load_genomedb',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
                -parameters => {
                    'db_version'      => $self->o('ensembl_release'),
                    'registry_files'  => $self->o('curr_file_sources_locs'),
                },
                -flow_into     => {
                    1 => { 'load_fresh_members_from_db' => INPUT_PLUS(), 'populate_method_links_from_db' },
                },
                -hive_capacity => 30,
                -rc_name       => '2Gb_job',
            },

            {   -logic_name    => 'populate_method_links_from_db',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
                -parameters    => {
                    'src_db_conn'   => '#master_db#',
                    'mode'          => 'overwrite',
                    'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                    'table'         => 'method_link',
                },
                -flow_into      => [ 'copy_mlss_ss' ],
            },

            {   -logic_name => 'copy_mlss_ss',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
                -rc_name    => '2Gb_job',
                -parameters => {
                    'master_db'          => $self->o('master_db'),
                    'whole_method_links' => ['ENSEMBL_HOMOLOGUES'],
                },
            },

            {   -logic_name => 'load_fresh_members_from_db',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
                -parameters => {
                    'store_related_pep_sequences' => $self->o('store_related_pep_sequences'),
                    'allow_ambiguity_codes'       => $self->o('allow_ambiguity_codes'),
                    'store_coding'                => $self->o('store_coding'),
                    'store_ncrna'                 => $self->o('store_ncrna'),
                    'store_others'                => $self->o('store_others'),
                    'store_missing_dnafrags'      => $self->o('store_missing_dnafrags'),
                    'compara_db'                  => $self->pipeline_url(),
                    'master_db'                   => undef,
                },
                -hive_capacity => 10,
                -rc_name       => '4Gb_job',
            },

            {   -logic_name         => 'hc_members_globally',
                -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
                -parameters         => {
                    mode            => 'members_globally',
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