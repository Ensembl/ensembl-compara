=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf -password <your_password>

=head1 DESCRIPTION  

  This is the Ensembl PipeConfig for the ncRNAtree pipeline.
  An example of use can be found in the Example folder.

=head1 AUTHORSHIP

  Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

  The rest of the documentation details each of the object methods.
  Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf ;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},


            # dependent parameters ('work_dir' should be defined)
            'rel_with_suffix'       => '',
            'pipeline_basename'     => 'NC',
            'pipeline_name'         => $self->o('pipeline_basename'),
            'dump_dir'              => $self->o('work_dir') . '/dumps',
            'ss_picts_dir'          => $self->o('work_dir') . '/ss_picts/',

            # dump parameters:
            'dump_table_list'       => '',  # probably either '#updated_tables#' or '' (to dump everything)
            'dump_exclude_ehive'    => 0,


            # tree break
            'treebreak_tags_to_copy'   => ['clustering_id', 'model_name'],

            # misc parameters
            'species_tree_input_file'  => '',  # empty value means 'create using genome_db+ncbi_taxonomy information'; can be overriden by a file with a tree in it
            'skip_epo'                 => 0,   # Never tried this one. It may fail


           };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
            @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

            'mkdir -p '.$self->o('work_dir'),
            'mkdir -p '.$self->o('dump_dir'),
            'mkdir -p '.$self->o('ss_picts_dir'),
    ];
}



sub pipeline_analyses {
    my ($self) = @_;
    return [

# --------------------------------------------- [ backbone ]-----------------------------------------------------------------------------
            {   -logic_name => 'backbone_fire_db_prepare',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -input_ids  => [ {
                                  'table_list'    => $self->o('dump_table_list'),
                                  'exclude_ehive' => $self->o('dump_exclude_ehive'),
                                 } ],
                -flow_into  => {
                                '1->A'  => [ 'copy_table_factory' ],
                                'A->1'  => [ 'backbone_fire_load' ],
                               },
                -meadow_type => 'LOCAL',
            },

            {   -logic_name => 'backbone_fire_load',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
                -parameters  => {
                                  'table_list'        => '',
                                  'output_file'          => 'snapshot_before_load.sql',
                                },
                -flow_into  => {
                               '1->A'   => [ 'load_genomedb_factory' ],
                               'A->1'   => [ 'backbone_fire_tree_building' ],
                              },
            },

            {   -logic_name => 'backbone_fire_tree_building',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
                -parameters  => {
                                  'table_list'        => '', 
                                  'output_file'          => 'snapshot_before_tree_building.sql',
                                 },
                -flow_into  => {
                                '1->A'  => [ 'rfam_classify' ],
                                'A->1'  => [ 'backbone_pipeline_finished' ],
                               },
            },

            {   -logic_name => 'backbone_pipeline_finished',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -meadow_type => 'LOCAL',
            },

# ---------------------------------------------[copy tables from master and fix the offsets]---------------------------------------------

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'   => $self->o('master_db'),
                'inputlist' => [ 'method_link', 'species_set', 'method_link_species_set', 'ncbi_taxa_name', 'ncbi_taxa_node' ],
                'column_names' => [ 'table' ],
                # 'fan_branch_code' => 2,
            },

            -flow_into => {
                           '2->A' => { 'copy_table' => { 'src_db_conn' => '#db_conn#', 'table' => '#table#' } },
                           'A->1' => [ 'offset_tables' ],
            },
        },

            {   -logic_name    => 'copy_table',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
                -parameters    => {
                                   'mode'          => 'overwrite',
                                   'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                                  },
                -hive_capacity => 10,
                -can_be_empty => 1,
            },

        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE member            AUTO_INCREMENT=100000001',
                    'ALTER TABLE sequence          AUTO_INCREMENT=100000001',
                    'ALTER TABLE homology          AUTO_INCREMENT=100000001',
                    'ALTER TABLE gene_align        AUTO_INCREMENT=100000001',
                    'ALTER TABLE gene_tree_node    AUTO_INCREMENT=100000001',
                    'ALTER TABLE CAFE_gene_family  AUTO_INCREMENT=100000001',
                    'ALTER TABLE CAFE_species_gene AUTO_INCREMENT=100000001',
                ],
            },
#            -wait_for => [ 'copy_table' ],    # have to wait until the tables have been copied
            -flow_into => {
                1 => [ 'innodbise_table_factory' ],
            },
        },

# ---------------------------------------------[turn all tables except 'genome_db' to InnoDB]---------------------------------------------

        {   -logic_name => 'innodbise_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='".$self->o('pipeline_db','-dbname')."' AND table_name!='meta' AND engine='MyISAM' ",
                # 'fan_branch_code' => 2,
            },
            -flow_into => {
                2 => [ 'innodbise_table'  ],
            },
        },

        {   -logic_name    => 'innodbise_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => "ALTER TABLE #table_name# ENGINE=InnoDB",
            },
            -hive_capacity => 10,
            -can_be_empty => 1,
        },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

            {   -logic_name => 'load_genomedb_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
                -parameters => {
                                'compara_db'            => $self->o('master_db'),   # that's where genome_db_ids come from
                                'mlss_id'               => $self->o('mlss_id'),
                                'call_list'             => [ 'compara_dba', 'get_MethodLinkSpeciesSetAdaptor', ['fetch_by_dbID', '#mlss_id#'], 'species_set_obj', 'genome_dbs' ],
                                'column_names2getters'  => { 'genome_db_id' => 'dbID', 'species_name' => 'name', 'assembly_name' => 'assembly', 'genebuild' => 'genebuild', 'locator' => 'locator' },
                               },
                -flow_into => {
                               '2->A' => [ 'load_genomedb' ], # fan
                               'A->1' => [ 'load_genomedb_funnel' ],
                               1      => [ 'load_rfam_models' ],
                              },
            },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                            'registry_dbs'   => [ $self->o('reg1'), $self->o('reg2') ],
            },
            -analysis_capacity => 10,    # they are all short jobs, no point doing them in parallel
            -flow_into => {
                '1->A' => [ 'load_members' ],   # each will flow into another one
                'A->1' => [ 'hc_members_per_genome' ],
            },
        },


        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_per_genome',
                hc_member_type  => 'ENSEMBLTRANS',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },


        {   -logic_name => 'load_genomedb_funnel',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                            # Removes the SS and the MLSS associated with non-valid genome_db_ids
                            'sql' => [ 'CREATE TEMPORARY TABLE tmp_ss SELECT species_set_id FROM species_set LEFT JOIN genome_db USING (genome_db_id) GROUP BY species_set_id HAVING COUNT(*) != COUNT(genome_db.genome_db_id)',
                                       'DELETE method_link_species_set FROM method_link_species_set JOIN tmp_ss USING (species_set_id)',
                                       'DELETE species_set FROM species_set JOIN tmp_ss USING (species_set_id)',
                                     ]
                           },
            -flow_into => {
                           1 => [ 'make_species_tree', 'create_lca_species_set', 'hc_members_globally' ],
            },
        },

        {   -logic_name         => 'hc_members_globally',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_globally',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

# ---------------------------------------------[load species tree]-------------------------------------------------------------------


        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                'species_tree_input_file'               => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
                'multifurcation_deletes_node'           => [ 129949, 314146 ], # 33316 has been removed from NCBI taxonomy
                'multifurcation_deletes_all_subnodes'   => [  9347, 186625,  32561 ],
                'mlss_id'                               => $self->o('mlss_id'),
                'for_gene_trees'                        => 1,
            },
            -hive_capacity => -1,   # to allow for parallelization
            # -flow_into  => {
            #     3 => { 'mysql:////method_link_species_set_tag' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'species_tree', 'value' => '#species_tree_string#' } },
            # },
        },


# ---------------------------------------------[create the low-coverage-assembly species set]-----------------------------------------

        {   -logic_name => 'create_lca_species_set',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore',
            -parameters => {
                            'object_type' => "SpeciesSet",
                            'arglist'     => [ -genome_dbs => [] ],
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                2 => {
                    'generate_pre_species_set'     => { 'lca_species_set_id' => '#dbID#' },     # pass it on to the query
                    'mysql:////species_set_tag' => { 'species_set_id' => '#dbID#', 'tag' => 'name', 'value' => 'low-coverage-assembly' },   # record the id in ss_tag table
                },
            },
        },

        {   -logic_name => 'generate_pre_species_set',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',    # another non-stardard use of JobFactory for iterative insertion
            -parameters => {
                'db_conn'         => $self->o('epo_db'),
                'inputquery'      => "SELECT #lca_species_set_id# as lca_species_set_id, GROUP_CONCAT(DISTINCT g.genome_db_id) as pre_species_set FROM genome_db g JOIN species_set ss USING(genome_db_id) JOIN method_link_species_set mlss USING(species_set_id) WHERE assembly_default AND mlss.name LIKE '%EPO_LOW_COVERAGE%' AND g.genome_db_id NOT IN (SELECT DISTINCT(g2.genome_db_id) FROM genome_db g2 JOIN species_set ss2 USING(genome_db_id) JOIN method_link_species_set mlss2 USING(species_set_id) WHERE assembly_default AND mlss2.name LIKE '%EPO')",
                # 'fan_branch_code' => 2,
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                           2 => [ 'store_lca_species_set' ],
            },
        },

        {   -logic_name => 'store_lca_species_set',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',    # another non-stardard use of JobFactory for iterative insertion
            -parameters => {
                'inputquery'      => "SELECT #lca_species_set_id# as species_set_id, genome_db_id FROM genome_db where genome_db_id in (#pre_species_set#)",
                # 'fan_branch_code' => 2,
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                2 => [ 'mysql:////species_set' ],
            },
        },

# ---------------------------------------------[load ncRNA and gene members]---------------------------------------------

        {   -logic_name    => 'load_members',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenomeStoreNCMembers',
            -hive_capacity => 10,
            # -flow_into => {
            #     2 => [ 'load_members' ],   # per-genome fan
            # },
            -rc_name => 'default',
        },

        # {   -logic_name    => 'load_members',
        #     -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GeneStoreNCMembers',
        #     -hive_capacity => $self->o('load_members_capacity'),
        #     -batch_size    => 100,

        #     -rc_name => 'default',
        # },

# ---------------------------------------------[load RFAM models]---------------------------------------------------------------------

        {   -logic_name    => 'load_rfam_models',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMLoadModels',
            -hive_capacity => -1,   # to allow for parallelization
            -parameters    => { },
            -rc_name => 'default',
        },

# ---------------------------------------------[run RFAM classification]--------------------------------------------------------------

            {   -logic_name    => 'rfam_classify',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMClassify',
                -parameters    => {
                                   'mlss_id' => $self->o('mlss_id'),
                                  },
                -flow_into     => {
                                   '1->A' => ['create_additional_clustersets'],
                                   'A->1' => ['clusters_factory'],
                                  },
                -rc_name       => 'default',
            },


            {   -logic_name    => 'create_additional_clustersets',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets',
                -parameters    => {
                                   'member_type'            => 'ncrna',
                                   'mlss_id'                => $self->o('mlss_id'),
                                   'additional_clustersets' => [qw(pg_it_nj ml_it_10 pg_it_phyml ss_it_s16 ss_it_s6a ss_it_s16a ss_it_s6b ss_it_s16b ss_it_s6c ss_it_s6d ss_it_s6e ss_it_s7a ss_it_s7b ss_it_s7c ss_it_s7d ss_it_s7e ss_it_s7f ft_it_ml ft_it_nj ftga_it_ml ftga_it_nj)],
                                  },
                -rc_name       => 'default',
            },

            {   -logic_name    => 'clusters_factory',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                                'inputquery'      => 'SELECT root_id AS gene_tree_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "tree" GROUP BY root_id ORDER BY COUNT(*) DESC, root_id ASC',
                               },
                -rc_name       => 'default',
                -flow_into     => {
                                   '2->A' => [ $self->o('skip_epo') ? 'msa_chooser' : 'recover_epo' ],
                                   'A->1' => [ 'hc_global_tree_set' ],
                                  },
                -meadow_type   => 'LOCAL',
            },

        {   -logic_name         => 'hc_global_tree_set',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },


        {   -logic_name    => 'recover_epo',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverEPO',
            -parameters    => {
                'mlss_id'        => $self->o('mlss_id'),
                'epo_db'         => $self->o('epo_db'),
            },
            -analysis_capacity => $self->o('recover_capacity'),
            -flow_into => {
                           1 => 'msa_chooser',
            },
            -rc_name => 'default',
        },

#         {   -logic_name    => 'recover_search',
#             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverSearch',
#             -batch_size    => 5,
#             -hive_capacity => -1,
#             -flow_into => {
#                 1 => [ 'infernal' ],
#             },
#         },


            {   -logic_name    => 'msa_chooser',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::MSAChooser',
                -parameters    => {
                                   'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                                  },
                -batch_size    => 10,
                -rc_name       => '1Gb_job',
                -priority      => 30,
                -analysis_capacity => $self->o('msa_chooser_capacity'),
                -flow_into     => {
                                   '1->A' => [ 'genomic_alignment', 'infernal' ],
                                   'A->1' => [ 'treebest_mmerge' ],
                                   '3->B' => [ 'aligner_for_tree_break' ],
                                   'B->4' => [ 'quick_tree_break' ],
                                  },
            },

            {   -logic_name    => 'aligner_for_tree_break',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -analysis_capacity => $self->o('aligner_for_tree_break_capacity'),
                -parameters => {
                                'cmbuild_exe' => $self->o('cmbuild_exe'),
                                'cmalign_exe' => $self->o('cmalign_exe'),
                               },
                -flow_into    => {
                                  1 => [ 'hc_alignment' ],
                                 },
                -rc_name => 'default',
            },


        {   -logic_name         => 'hc_alignment',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'alignment',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

            {   -logic_name => 'quick_tree_break',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak',
                -parameters => {
                                'mlss_id'           => $self->o('mlss_id'),
                                'quicktree_exe'     => $self->o('quicktree_exe'),
                                'tags_to_copy'      => $self->o('treebreak_tags_to_copy'),
                                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                               },
                -analysis_capacity  => $self->o('quick_tree_break_capacity'),
                -rc_name        => '4Gb_long_job',
                -priority       => 50,
                -flow_into      => [ 'other_paralogs' ],
            },

            {   -logic_name     => 'other_paralogs',
                -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
                -parameters     => {
                                    'dataflow_subclusters' => 1,
                                    'mlss_id'              => $self->o('mlss_id'),
                                   },
                -analysis_capacity  => $self->o('other_paralogs_capacity'),
                -rc_name            => '1Gb_job',
                -priority           => 40,
                -flow_into => {
                               '2->A' => [ 'genomic_alignment', 'infernal' ],
                               'A->2' => [ 'treebest_mmerge' ],
                              },
            },

            {   -logic_name    => 'infernal',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -analysis_capacity => $self->o('infernal_capacity'),
                -parameters    => {
                                   'cmbuild_exe' => $self->o('cmbuild_exe'),
                                   'cmalign_exe' => $self->o('cmalign_exe'),
                                  },
                -flow_into     => {
                                   1 => ['pre_sec_struct_tree', 'hc_alignment' ],
                                   3 => ['create_ss_picts'],
                                  },
                -rc_name       => 'default',
            },

            {   -logic_name    => 'create_ss_picts',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenerateSSPict',
                -analysis_capacity => $self->o('ss_picts_capacity'),
                -parameters    => {
                                   'ss_picts_dir'  => $self->o('ss_picts_dir'),
                                   'r2r_exe'       => $self->o('r2r_exe'),
                                  },
                -failed_job_tolerance =>  30,
                -rc_name       => 'default',
            },

            {
             -logic_name    => 'pre_sec_struct_tree', ## pre_sec_struct_tree
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels',  ## PrepareRAxMLSecModels -- rename
             -analysis_capacity => $self->o('raxml_capacity'),
             -parameters => {
                             'raxml_exe'             => $self->o('raxml_exe'),
                             'raxml_number_of_cores' => $self->o('raxml_number_of_cores'),
                             'mlss_id'               => $self->o('mlss_id'),
                            },
             -flow_into => {
                            2 => [ 'sec_struct_model_tree'],
                           },
             -rc_name => '2Gb_basement_ncores_job',
            },

        {   -logic_name    => 'sec_struct_model_tree', ## sec_struct_model_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree', ## SecStrucModels
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            'raxml_exe'             => $self->o('raxml_exe'),
                            'raxml_number_of_cores' => $self->o('raxml_number_of_cores'),
                            'mlss_id'               => $self->o('mlss_id'),
                           },
            -rc_name => '2Gb_basement_ncores_job',
        },

        {   -logic_name    => 'genomic_alignment',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment',
            -analysis_capacity => $self->o('genomic_alignment_capacity'),
            -parameters => {
                            'mafft_exe'             => $self->o('mafft_exe'),
                            'mafft_binaries'        => $self->o('mafft_binaries'),
                            'raxml_exe'             => $self->o('raxml_exe'),
                            'raxml_number_of_cores' => $self->o('raxml_number_of_cores'),
                            'prank_exe'             => $self->o('prank_exe'),
                           },
            -flow_into => {
                           -2 => ['genomic_alignment_long'],
                           -1 => ['genomic_alignment_long'],
                           1  => [ 'hc_alignment' ],
                           3  => ['fast_trees'],
                           2  => ['genomic_tree'],
                          },
            -rc_name => 'default_2cores',
        },

            {
             -logic_name => 'fast_trees',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees',
             -analysis_capacity => $self->o('fast_trees_capacity'),
             -parameters => {
                             'fasttree_exe'          => $self->o('fasttree_exe'),
                             'parsimonator_exe'      => $self->o('parsimonator_exe'),
                             'raxmlLight_exe'        => $self->o('raxmlLight_exe'),
                             'raxml_number_of_cores' => $self->o('raxml_number_of_cores'),
                             'mlss_id'               => $self->o('mlss_id'),
                            },
             -can_be_empty => 1,
             -rc_name => '8Gb_basement_ncores_job',
            },

        {
         -logic_name => 'genomic_alignment_long',
         -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment',
         -analysis_capacity => $self->o('genomic_alignment_capacity'),
            -parameters => {
                            'raxml_number_of_cores' => $self->o('raxml_number_of_cores'),
                            'mafft_exe' => $self->o('mafft_exe'),
                            'mafft_binaries' => $self->o('mafft_binaries'),
                            'raxml_exe' => $self->o('raxml_exe'),
                            'prank_exe' => $self->o('prank_exe'),
                           },
         -can_be_empty => 1,
         -rc_name => '8Gb_basement_ncores_job',
         -flow_into => {
                        1 => [ 'hc_alignment' ],
                        2 => [ 'genomic_tree_himem' ],
                       },
        },

            {
             -logic_name => 'genomic_tree',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicTree',
             -analysis_capacity => $self->o('genomic_tree_capacity'),
             -parameters => {
                             'treebest_exe' => $self->o('treebest_exe'),
                             'mlss_id' => $self->o('mlss_id'),
                            },
             -flow_into => {
                            -2 => ['genomic_tree_himem'],
                            -1 => ['genomic_tree_himem'],
                           },
             -rc_name => 'default',
            },

            {
             -logic_name => 'genomic_tree_himem',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicTree',
             -analysis_capacity => $self->o('genomic_tree_capacity'),
             -parameters => {
                             'treebest_exe' => $self->o('treebest_exe'),
                             'mlss_id' => $self->o('mlss_id'),
                            },
             -can_be_empty => 1,
             -rc_name => '4Gb_job',
            },

        {   -logic_name    => 'treebest_mmerge',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge',
            -analysis_capacity => $self->o('treebest_capacity'),
            -parameters => {
                            'treebest_exe' => $self->o('treebest_exe'),
                            'mlss_id' => $self->o('mlss_id'),
                           },
            -flow_into => {
                           '1->A' =>  {
                                       'hc_alignment_post_tree' => {'gene_tree_id' => '#gene_tree_id#', 'post_treebest' => 1},
                                       'hc_tree_structure' => undef,
                                      },
                           'A->1' => [ 'orthotree' ],
                           1 => [ 'ktreedist' ],
                           2 => [ 'hc_tree_structure' ],
#                           1 => [ 'orthotree', 'ktreedist' ],
            },
            -rc_name => 'default',
        },

        {   -logic_name         => 'hc_alignment_post_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'alignment',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

        {   -logic_name         => 'hc_tree_structure',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_structure',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

        {   -logic_name    => 'orthotree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -analysis_capacity => $self->o('orthotree_capacity'),
            -parameters => {
                            'tag_split_genes'   => 0,
                            'mlss_id' => $self->o('mlss_id'),
            },
            -flow_into  => [ 'hc_tree_attributes', 'hc_tree_homologies' ],
           -rc_name => 'default',
        },

        {   -logic_name    => 'ktreedist',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist',
            -analysis_capacity => -1,
            -parameters => {
                            'treebest_exe'  => $self->o('treebest_exe'),
                            'ktreedist_exe' => $self->o('ktreedist_exe'),
                            'mlss_id' => $self->o('mlss_id'),
                           },
            -rc_name => 'default',
        },

        {   -logic_name         => 'hc_tree_attributes',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_attributes',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

        {   -logic_name         => 'hc_tree_homologies',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_homologies',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

    ];
}

1;

