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

Bio::EnsEMBL::Compara::PipeConfig::Parts::CopyNCBIandGenomeDB

=head1 DESCRIPTION

    This is a partial PipeConfig for most part of the copying genomes and NCBI db

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::CopyNCBIandGenomeDB;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub pipeline_analyses_copy_ncbi_and_genome_db {
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
                'A->1' => [ 'check_member_db_is_same_version' ],
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

        {   -logic_name => 'check_member_db_is_same_version',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions',
            -parameters => {
                'db_conn'       => '#member_db#',
            },
            -flow_into => WHEN(
                '#master_db#' => 'populate_method_links_from_db',
                ELSE 'populate_method_links_from_file',
            ),
        },

        {   -logic_name     => 'populate_method_links_from_file',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters     => {
                'method_link_dump_file' => $self->o('method_link_dump_file'),
                'executable'            => 'mysqlimport',
                'append'                => [ '#method_link_dump_file#' ],
            },
            -flow_into      => {
                1 => {
                    'load_genomedb_factory' => INPUT_PLUS( { 'master_db' => '#member_db#', } ),
                }
            },
        },

        {   -logic_name    => 'populate_method_links_from_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => '#master_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                'table'         => 'method_link',
            },
            -flow_into      => [ 'offset_tables' ],
        },

        # CreateReuseSpeciesSets/PrepareSpeciesSetsMLSS may want to create new
        # entries. We need to make sure they don't collide with the master database
        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE species_set_header      AUTO_INCREMENT=10000001',
                    'ALTER TABLE method_link_species_set AUTO_INCREMENT=10000001',
                ],
            },
            -flow_into      => [ 'load_genomedb_factory' ],
        },

    # -------------------------------[load GenomeDB entries from member_db]----------------------------------

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => $self->o('master_db'),   # that's where genome_db_ids come from
                'species_set_id'    => $self->o('species_set_id'),
                # Add the locators coming from member_db
                'extra_parameters'  => [ 'locator' ],
                'genome_db_data_source' => '#member_db#',
            },
            -rc_name => '4Gb_job',
            -flow_into => {
                '2->A' => {
                    'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' },
                },
                'A->1' => [ 'member_copy_factory' ],
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters  => {
                'master_db' => $self->o('master_db'),
            },
            -batch_size => 10,
            -hive_capacity => 30,
            -max_retry_count => 2,
        },

        {   -logic_name => 'member_copy_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'species_set_id'    => $self->o('species_set_id'),
                'extra_parameters'  => [ 'is_polyploid' ],
                'compara_db'        => $self->o('master_db'),
            },
            -rc_name   => '4Gb_job',
            -flow_into => {
                '2->A' => [ 'genome_member_copy' ],
                'A->1' => [ 'create_mlss_ss' ],
            },
        },

    # --------------------[filter genome_db entries into reusable and non-reusable ones]---------------------

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -rc_name    => '2Gb_job',
            -parameters => {
                'whole_method_links' => ['ENSEMBL_HOMOLOGUES'],
            },
            -flow_into  => {
                1 => [ WHEN ( '#species_tree#' => 'make_treebest_species_tree' ), 'hc_members_globally' ],
            },
        },

    # --------------------------------------[load species tree]----------------------------------------------

        {   -logic_name    => 'make_treebest_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                               'species_tree_input_file' => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
            },
            -flow_into     => {
                2 => [ 'hc_species_tree' ],
            }
        },

        {   -logic_name         => 'hc_species_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'species_tree',
                binary          => 0,
                n_missing_species_in_tree   => 0,
            },
            -flow_into  => WHEN(
                '#use_notung# and  #binary_species_tree_input_file#' => 'load_binary_species_tree',
                '#use_notung# and !#binary_species_tree_input_file#' => 'make_binary_species_tree',

                '#use_treerecs# and  #binary_species_tree_input_file#' => 'load_binary_species_tree',
                '#use_treerecs# and !#binary_species_tree_input_file#' => 'make_binary_species_tree',
            ),
            %hc_analysis_params,
        },

         {   -logic_name    => 'load_binary_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                               'label' => 'binary',
                               'species_tree_input_file' => '#binary_species_tree_input_file#',
            },
            -flow_into     => {
                2 => [ 'hc_binary_species_tree' ],
            }
        },

        {   -logic_name    => 'make_binary_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFESpeciesTree',
            -parameters    => {
                'new_label'     => 'binary',
                'label'         => 'default',
                'use_timetree_times' => $self->o('use_timetree_times'),
            },
            -flow_into     => {
                2 => [ 'hc_binary_species_tree' ],
            }
        },

        {   -logic_name         => 'hc_binary_species_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'species_tree',
                binary          => 1,
                n_missing_species_in_tree   => 0,
            },
            %hc_analysis_params,
        },

    # ----------------------------------------[reuse members]------------------------------------------------

        {   -logic_name => 'genome_member_copy',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyCanonRefMembersByGenomeDB',
            -parameters => {
                'reuse_db'              => '#member_db#',
                'biotype_filter'        => 'biotype_group = "coding"',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => WHEN( '#is_polyploid#' => 'check_reusability',
                                ELSE                'hc_members_per_genome' ),
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_per_genome',
                allow_ambiguity_codes => $self->o('allow_ambiguity_codes'),
                allow_missing_coordinates   => $self->o('allow_missing_coordinates'),
                allow_missing_cds_seqs      => $self->o('allow_missing_cds_seqs'),
                only_canonical              => 1,
            },
            -flow_into => [ 'check_reusability' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckCanonMembersReusability',
            -parameters => {
                'do_not_reuse_list' => $self->o('do_not_reuse_list'),
            },
            -batch_size => 5,
            -hive_capacity => 30,
            -flow_into => {
                2 => '?accu_name=reused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
                3 => '?accu_name=nonreused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
            },
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
            -flow_into  => WHEN('#dbID_range_index#' => 'offset_homology_tables' ),
        },

        {   -logic_name => 'offset_homology_tables',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OffsetTables',
            -parameters => {
                'range_index'   => '#dbID_range_index#',
            },
        },

    ];
}

1;
