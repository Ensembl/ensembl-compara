=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf -password <your_password> -mlss_id <your_mlss_id>

=head1 DESCRIPTION  

This is the Ensembl PipeConfig for the ncRNAtree pipeline.
An example of use can be found in the Example folder.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf ;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

            # User details
            #'email'                 => 'john.smith@example.com',

            # dependent parameters ('work_dir' should be defined)
            'dump_dir'              => $self->o('work_dir') . '/dumps',
            'ss_picts_dir'          => $self->o('work_dir') . '/ss_picts/',

            # How will the pipeline create clusters (families) ?
            # Possible values: 'rfam' (default) or 'ortholog'
            #   'blastp' means that the pipeline will clusters genes according to their RFAM accession
            #   'ortholog' means that the pipeline will use previously inferred orthologs to perform a cluster projection
            'clustering_mode'           => 'rfam',

            'division'              => undef,

    # Parameters to allow merging different runs of the pipeline
        'dbID_range_index'      => 1,
        'label_prefix'          => undef,

        # How much the pipeline will try to reuse from "prev_rel_db"
            # tree break
            'treebreak_tags_to_copy'   => ['model_id', 'model_name'],

            # misc parameters
            'species_tree_input_file'  => '',  # empty value means 'create using genome_db+ncbi_taxonomy information'; can be overriden by a file with a tree in it
            'skip_epo'                 => 0,   # Never tried this one. It may fail
            'create_ss_picts'          => 0,

            # ambiguity codes
            'allow_ambiguity_codes'    => 1,

            # Do we want to initialise the CAFE part now ?
            'initialise_cafe_pipeline'  => undef,
            # Data needed for CAFE
            'cafe_lambdas'             => '',  # For now, we don't supply lambdas
            'cafe_struct_tree_str'     => '',  # Not set by default
            'full_species_tree_label'  => 'full_species_tree',
            'per_family_table'         => 0,
            'cafe_species'             => [],

            # Ortholog-clustering parameters
            'ref_ortholog_db'           => undef,

            # Analyses usually don't fail
            'hive_default_max_retry_count'  => 1,
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


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'mlss_id'       => $self->o('mlss_id'),
        'master_db'     => $self->o('master_db'),
        'member_db'     => $self->o('member_db'),
        'prev_rel_db'   => $self->o('prev_rel_db'),

        'skip_epo'      => $self->o('skip_epo'),
        'epo_db'        => $self->o('epo_db'),

        'create_ss_picts'   => $self->o('create_ss_picts'),
        'initialise_cafe_pipeline'   => $self->o('initialise_cafe_pipeline'),
        'dbID_range_index'  => $self->o('dbID_range_index'),
        'clustering_mode'   => $self->o('clustering_mode'),
    }
}


sub pipeline_analyses {
    my ($self) = @_;

    my %hc_params = (
                     -analysis_capacity => $self->o('hc_capacity'),
                     -priority          => $self->o('hc_priority'),
                     -batch_size        => $self->o('hc_batch_size'),
                    );

    my %backbone_params = (
                           -meadow_type       => 'LOCAL',
                          );

    my %raxml_parameters = (
        'raxml_pthread_exe_sse3'     => $self->o('raxml_pthread_exe_sse3'),
        'raxml_pthread_exe_avx'      => $self->o('raxml_pthread_exe_avx'),
        'raxml_exe_sse3'             => $self->o('raxml_exe_sse3'),
        'raxml_exe_avx'              => $self->o('raxml_exe_avx'),
    );

    my %examl_parameters = (
        'examl_exe_sse3'        => $self->o('examl_exe_sse3'),
        'examl_exe_avx'         => $self->o('examl_exe_avx'),
        'parse_examl_exe'       => $self->o('parse_examl_exe'),
        'mpirun_exe'            => $self->o('mpirun_exe'),
    );

    return [

# --------------------------------------------- [ backbone ]-----------------------------------------------------------------------------
            {   -logic_name => 'backbone_fire_load_genomes',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -input_ids  => [ {} ],
                -flow_into  => {
                                '1->A'  => [ 'copy_tables_factory' ],
                                'A->1'  => [ 'backbone_fire_classify_genes' ],
                               },
                %backbone_params,
            },

            {   -logic_name => 'backbone_fire_classify_genes',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
                -parameters  => {
                                  'output_file'          => $self->o('dump_dir').'/snapshot_before_classify.sql',
                                },
                -flow_into  => {
                               '1->A'   => [ 'load_rfam_models' ],
                               'A->1'   => [ 'backbone_fire_tree_building' ],
                              },
                %backbone_params,
            },

            {   -logic_name => 'backbone_fire_tree_building',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
                -parameters  => {
                                  'output_file'          => $self->o('dump_dir').'/snapshot_before_tree_building.sql',
                                 },
                -flow_into  => {
                                '1->A'  => [ 'clusters_factory' ],
                                'A->1'  => [ 'backbone_pipeline_finished' ],
                               },
                %backbone_params,
            },

            {   -logic_name => 'backbone_pipeline_finished',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -flow_into  => ['notify_pipeline_completed'],
                %backbone_params,
            },

            {   -logic_name => 'notify_pipeline_completed',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
                -parameters => {
                    'subject' => "ncRNA-Tree pipeline (".$self->o('pipeline_name').") has completed",
                    'text' => "This is an automatic message.\n ncRNA-Tree Pipeline for release  #expr(\$self->hive_pipeline->display_name)expr#  has completed.",
                    'email' => $self->o('email'),
                    },
                -flow_into  => [ 'register_pipeline_url' ],
            },

            {   -logic_name => 'register_pipeline_url',
                -module      => 'Bio::EnsEMBL::Compara::RunnableDB::RegisterMLSS',
                -parameters => { 
                    'test_mode' => $self->o('test_mode'),
                    }
            },

# ---------------------------------------------[copy tables from master and fix the offsets]---------------------------------------------

        {   -logic_name => 'copy_tables_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name', 'method_link' ],
                'column_names' => [ 'table' ],
            },
            -flow_into => {
                '2->A' => [ 'copy_table'  ],
                'A->1' => [ 'offset_tables' ],
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => '#master_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
        },

        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OffsetTables',
            -parameters => {
                'range_index'   => '#dbID_range_index#',
            },
            -flow_into  => [ 'offset_more_tables' ],
        },

        {   -logic_name => 'offset_more_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE species_set_header      AUTO_INCREMENT=10000001',
                    'ALTER TABLE method_link_species_set AUTO_INCREMENT=10000001',
                ],
            },
            -flow_into  => [ 'load_genomedb_factory' ],
        },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

            {   -logic_name => 'load_genomedb_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
                -parameters => {
                                'compara_db'            => '#master_db#',   # that's where genome_db_ids come from
                                'mlss_id'               => $self->o('mlss_id'),
                                'extra_parameters'      => [ 'locator' ],
                               },
                -flow_into => {
                               '2->A' => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, }, # fan
                               'A->1' => [ 'create_mlss_ss' ],
                              },
            },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                            'registry_dbs'   => [ $self->o('reg1')],
            },
            -analysis_capacity => 10,
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -parameters => {
                'whole_method_links'        => [ 'NC_TREES' ],
                'singleton_method_links'    => [ 'ENSEMBL_PARALOGUES', 'ENSEMBL_HOMOEOLOGUES' ],
                'pairwise_method_links'     => [ 'ENSEMBL_ORTHOLOGUES' ],
            },
            -flow_into => {
                1 => [ 'make_species_tree', 'load_members_factory' ],
            },
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_per_genome',
                allow_missing_coordinates   => 0,
                allow_missing_cds_seqs => 0,
                allow_ambiguity_codes => $self->o('allow_ambiguity_codes'),
                only_canonical              => 1,
            },
            %hc_params,
        },

        {   -logic_name => 'load_members_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                '2->A' => 'genome_member_copy',
                'A->1' => [ 'hc_members_globally' ],
            },
        },

        {   -logic_name        => 'genome_member_copy',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyCanonRefMembersByGenomeDB',
            -parameters        => {
                'reuse_db'              => '#member_db#',
                'biotype_filter'        => 'biotype_group LIKE "%noncoding"',
            },
            -analysis_capacity => 10,
            -rc_name           => '250Mb_job',
            -flow_into         => [ 'hc_members_per_genome' ],
        },

        {   -logic_name         => 'hc_members_globally',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_globally',
            },
            -flow_into          => [ 'insert_member_projections' ],
            %hc_params,
        },

        {   -logic_name => 'insert_member_projections',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'INSERT INTO seq_member_projection (target_seq_member_id, source_seq_member_id) SELECT target_seq_member_id, canonical_member_id FROM seq_member_projection_stable_id JOIN gene_member ON source_stable_id = stable_id',
                ],
            },
        },

# ---------------------------------------------[load species tree]-------------------------------------------------------------------


        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                'species_tree_input_file'               => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
                'multifurcation_deletes_node'           => [ 314146, 1489913 ], # 33316 and 129949 has been removed from NCBI taxonomy
                'multifurcation_deletes_all_subnodes'   => [  9347, 186625,  32561 ],
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
            %hc_params,
        },

# ---------------------------------------------[load RFAM models]---------------------------------------------------------------------

        {   -logic_name    => 'load_rfam_models',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadInfernalHMMModels',
            -parameters    => {
                               'url'               => $self->o('rfam_ftp_url'),
                               'remote_file'       => $self->o('rfam_remote_file'),
                               'expanded_basename' => $self->o('rfam_expanded_basename'),
                               'expander'          => $self->o('rfam_expander'),
                               'type'              => 'infernal',
                               'skip_consensus'    => 1,
                              },
            -flow_into     => WHEN(
                                   '#clustering_mode# eq "ortholog"' => 'ortholog_cluster',
                                   ELSE 'rfam_classify',
                               ),
        },

# ---------------------------------------------[run RFAM classification]--------------------------------------------------------------

            {   -logic_name    => 'rfam_classify',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMClassify',
                -flow_into     => [ 'cluster_qc_factory' ],
                -rc_name       => '2Gb_job',
            },

            {   -logic_name    => 'clusterset_backup',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
                -parameters    => {
                    'sql'         => 'INSERT IGNORE INTO gene_tree_backup (seq_member_id, root_id) SELECT seq_member_id, root_id FROM gene_tree_node WHERE seq_member_id IS NOT NULL',
                },
                -flow_into     => [ 'create_additional_clustersets' ],
            },

            {   -logic_name    => 'create_additional_clustersets',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets',
                -parameters    => {
                                   'member_type'            => 'ncrna',
                                   'additional_clustersets' => [qw(pg_it_nj ml_it_10 pg_it_phyml ss_it_s16 ss_it_s6a ss_it_s16a ss_it_s6b ss_it_s16b ss_it_s6c ss_it_s6d ss_it_s6e ss_it_s7a ss_it_s7b ss_it_s7c ss_it_s7d ss_it_s7e ss_it_s7f ft_it_ml ft_it_nj ftga_it_ml ftga_it_nj)],
                                  },
            },

            {   -logic_name => 'cluster_qc_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
                -flow_into  => {
                    '2->A' => [ 'per_genome_qc' ],
                    'A->1' => [ 'clusterset_backup' ],
                },
            },

            {   -logic_name => 'per_genome_qc',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PerGenomeGroupsetQC',
            },

        {   -logic_name => 'ortholog_cluster',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OrthologClusters',
            -parameters => {
                'sort_clusters'         => 1,
                'add_model_id'          => 1,
            },
            -rc_name    => '2Gb_job',
            -flow_into  => 'expand_clusters_with_projections',
        },

        {   -logic_name         => 'expand_clusters_with_projections',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExpandClustersWithProjections',
            -rc_name            => '250Mb_job',
            -flow_into          => [ 'cluster_qc_factory' ],
        },

# -------------------------------------------------[build trees]------------------------------------------------------------------

            {   -logic_name    => 'clusters_factory',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                                'inputquery'      => 'SELECT root_id AS gene_tree_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "tree" GROUP BY root_id ORDER BY COUNT(*) DESC, root_id ASC',
                               },
                -flow_into     => {
                                   '2->A' => WHEN( '#skip_epo#' => 'msa_chooser', ELSE 'recover_epo' ),
                                   'A->1' => [ 'hc_global_tree_set' ],
                                  },
            },

            { -logic_name         => 'hc_global_tree_set',
              -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
              -parameters         => {
                                      mode            => 'global_tree_set',
                                     },
              -flow_into          => [ 'write_stn_tags',
                                        WHEN('#clustering_mode# eq "ortholog"' => 'remove_overlapping_homologies', ELSE [ 'homology_stats_factory', 'id_map_mlss_factory' ]),
                                        WHEN('#initialise_cafe_pipeline#', 'make_full_species_tree'),
                                    ],
              %hc_params,
            },

        {
             -logic_name => 'remove_overlapping_homologies',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveOverlappingHomologies',
             -flow_into  => [ 'rename_labels' ],
        },

        {
             -logic_name => 'rename_labels',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RenameLabelsBeforMerge',
             -parameters => {
                 'division'     => $self->o('division'),
                 'label_prefix' => $self->o('label_prefix'),
             },
             -flow_into  => [ 'homology_stats_factory', 'id_map_mlss_factory' ],
        },

        {   -logic_name     => 'write_stn_tags',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters     => {
                'input_file'    => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/tree-stats-as-stn_tags.sql',
            },
            -flow_into      => [ 'email_tree_stats_report' ],
        },

        {   -logic_name     => 'email_tree_stats_report',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HTMLReport',
            -parameters     => {
                'email' => $self->o('email'),
            },
        },

            {   -logic_name    => 'recover_epo',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverEPO',
                -parameters    => {
                    'max_members'   => 50000,
                },
                -analysis_capacity => $self->o('recover_capacity'),
                -flow_into => {
                    1 => 'hc_epo_removed_members',
                    -1 => 'recover_epo_himem',
                },
                -rc_name => '2Gb_job',
            },

            {   -logic_name    => 'recover_epo_himem',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverEPO',
                -analysis_capacity => $self->o('recover_capacity'),
                -flow_into => [ 'hc_epo_removed_members' ],
                -rc_name => '16Gb_job',
            },

            {  -logic_name        => 'hc_epo_removed_members',
               -module            => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
               -parameters        => {
                                      mode => 'epo_removed_members',
                                     },
               -flow_into         => [ 'msa_chooser' ],
               %hc_params,
            },

            {   -logic_name    => 'msa_chooser',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
                -parameters    => {
                                   'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                                   'tags'  => {
                                       'gene_count'          => 0,
                                   },
                                  },
                -batch_size    => 10,
                -rc_name       => '1Gb_job',
                -priority      => 30,
                -analysis_capacity => $self->o('msa_chooser_capacity'),
                -flow_into     => WHEN( '#tree_gene_count# > #treebreak_gene_count#' => 'aligner_for_tree_break', ELSE 'tree_entry_point' ),
            },

            {   -logic_name    => 'aligner_for_tree_break',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -analysis_capacity => $self->o('aligner_for_tree_break_capacity'),
                -parameters => {
                                'cmbuild_exe' => $self->o('cmbuild_exe'),
                                'cmalign_exe' => $self->o('cmalign_exe'),
                                'infernal_mxsize' => $self->o('infernal_mxsize'),
                               },
                -flow_into     => {
                    1 => ['quick_tree_break' ],
                    -1 => [ 'aligner_for_tree_break_himem' ],
                },
                -rc_name => '2Gb_job',
            },

            {   -logic_name    => 'aligner_for_tree_break_himem',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -analysis_capacity => $self->o('aligner_for_tree_break_capacity'),
                -parameters => {
                                'cmbuild_exe' => $self->o('cmbuild_exe'),
                                'cmalign_exe' => $self->o('cmalign_exe'),
                                'infernal_mxsize' => $self->o('infernal_mxsize'),
                               },
                -flow_into     => [ 'quick_tree_break' ],
                -rc_name => '4Gb_job',
            },

            {   -logic_name => 'quick_tree_break',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak',
                -parameters => {
                                'quicktree_exe'     => $self->o('quicktree_exe'),
                                'tags_to_copy'      => $self->o('treebreak_tags_to_copy'),
                                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                               },
                -analysis_capacity  => $self->o('quick_tree_break_capacity'),
                -rc_name        => '2Gb_job',
                -priority       => 50,
                -flow_into      => {
                   1   => ['other_paralogs'],
                   -1  => ['quick_tree_break_himem'], # MEMLIMIT
                },
            },

            {   -logic_name => 'quick_tree_break_himem',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak',
                -parameters => {
                                'quicktree_exe'     => $self->o('quicktree_exe'),
                                'tags_to_copy'      => $self->o('treebreak_tags_to_copy'),
                                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                               },
                -analysis_capacity  => $self->o('quick_tree_break_capacity'),
                -rc_name        => '4Gb_job',
                -priority       => 50,
                -flow_into      => [ 'other_paralogs' ],
            },

            {   -logic_name     => 'other_paralogs',
                -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
                -parameters     => {
                                    'dataflow_subclusters' => 1,
                                   },
                -analysis_capacity  => $self->o('other_paralogs_capacity'),
                -rc_name            => '250Mb_long_job',
                -priority           => 40,
                -flow_into     => {
                                   2 => [ 'tree_backup' ],
                                  },
            },

            {   -logic_name    => 'infernal',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -analysis_capacity => $self->o('infernal_capacity'),
                -parameters    => {
                                   'cmbuild_exe' => $self->o('cmbuild_exe'),
                                   'cmalign_exe' => $self->o('cmalign_exe'),
                                   'infernal_mxsize' => $self->o('infernal_mxsize'),
                                  },
                -flow_into     => {
                                  -1 => [ 'infernal_himem' ],
                                   1 => [ 'pre_sec_struct_tree', WHEN('#create_ss_picts#' => 'create_ss_picts' ) ],
                                  },
                -rc_name       => '1Gb_job',
            },

            {   -logic_name    => 'infernal_himem',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -analysis_capacity => $self->o('infernal_capacity'),
                -parameters    => {
                                   'cmbuild_exe' => $self->o('cmbuild_exe'),
                                   'cmalign_exe' => $self->o('cmalign_exe'),
                                   'infernal_mxsize' => $self->o('infernal_mxsize'),
                                  },
                -flow_into     => [ 'pre_sec_struct_tree', WHEN('#create_ss_picts#' => 'create_ss_picts' ) ],
                -rc_name       => '2Gb_job',
            },

            {   -logic_name    => 'tree_backup',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
                -parameters    => {
                                   'sql' => 'INSERT INTO gene_tree_backup (seq_member_id, root_id) SELECT seq_member_id, root_id FROM gene_tree_node WHERE seq_member_id IS NOT NULL AND root_id = #gene_tree_id#',
                                  },
                -flow_into => [ 'tree_entry_point' ],
                -analysis_capacity => 1,
            },

            {   -logic_name    => 'tree_entry_point',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
                -parameters    => {
                                   'tags'  => {
                                       'model_id'          => '',
                                   },
                                  },
                -flow_into => {
                               '1->A' => [ 'genomic_alignment', WHEN('#tree_model_id#' => 'infernal') ],
                               'A->1' => [ 'treebest_mmerge' ],
                              },
            },

            {   -logic_name    => 'create_ss_picts',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenerateSSPict',
                -analysis_capacity => $self->o('ss_picts_capacity'),
                -parameters    => {
                                   'ss_picts_dir'  => $self->o('ss_picts_dir'),
                                   'r2r_exe'       => $self->o('r2r_exe'),
                                  },
                -rc_name       => '2Gb_job',
            },

            {
             -logic_name    => 'pre_sec_struct_tree', ## pre_sec_struct_tree
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels',  ## PrepareRAxMLSecModels -- rename
             -analysis_capacity => $self->o('raxml_capacity'),
             -parameters => {
                             %raxml_parameters,
                             'cmd_max_runtime'       => '86400',
                             'raxml_number_of_cores' => 4,
                            },
             -flow_into => {
                            2 => [ 'sec_struct_model_tree'],
                            -2 => [ 'pre_sec_struct_tree_long' ],       # RUNTIME
                           },
             -rc_name => '2Gb_4c_job',
            },

            {
             -logic_name    => 'pre_sec_struct_tree_long', ## pre_sec_struct_tree
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels',  ## PrepareRAxMLSecModels -- rename
             -analysis_capacity => $self->o('raxml_capacity'),
             -parameters => {
                             %raxml_parameters,
                             'raxml_number_of_cores' => 8,
                            },
             -flow_into => {
                            2 => [ 'sec_struct_model_tree_long'],
                           },
             -rc_name => '4Gb_8c_job',
            },

        {   -logic_name    => 'sec_struct_model_tree', ## sec_struct_model_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree', ## SecStrucModels
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'cmd_max_runtime'       => '86400',
                            'raxml_number_of_cores' => 8,
                           },

             -flow_into => {
                            -2 => [ 'sec_struct_model_tree_long' ],       # RUNTIME
                           },

            -rc_name => '4Gb_8c_job',
        },

        {   -logic_name    => 'sec_struct_model_tree_long', ## sec_struct_model_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree', ## SecStrucModels
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'raxml_number_of_cores' => 16,
                           },
            -rc_name => '8Gb_16c_job',
        },

        {   -logic_name    => 'genomic_alignment',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment',
            -analysis_capacity => $self->o('genomic_alignment_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'cmd_max_runtime'       => '43200',
                            'mafft_exe'             => $self->o('mafft_exe'),
                            'raxml_number_of_cores' => 4,
                            'prank_exe'             => $self->o('prank_exe'),
                           },
            -flow_into => {
                           -1 => ['genomic_alignment_himem'],
                           3  => ['fast_trees'],
                           2  => ['genomic_tree'],
                          },
            -rc_name => '2Gb_4c_job',
            -priority      => $self->o('genomic_alignment_priority'),
        },

            {
             -logic_name => 'fast_trees',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees',
             -analysis_capacity => $self->o('fast_trees_capacity'),
             -parameters => {
                            %examl_parameters,
                             'fasttree_exe'          => $self->o('fasttree_exe'),
                             'parsimonator_exe'      => $self->o('parsimonator_exe'),
                             'examl_number_of_cores' => 4,
                            },
            -flow_into => {
                           -1 => ['fast_trees_himem'],
                          },
             -rc_name => '8Gb_mpi_4c_job',
            },
            {
             -logic_name => 'fast_trees_himem',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees',
             -analysis_capacity => $self->o('fast_trees_capacity'),
             -parameters => {
                            %examl_parameters,
                             'fasttree_exe'          => $self->o('fasttree_exe'),
                             'parsimonator_exe'      => $self->o('parsimonator_exe'),
                             'examl_number_of_cores' => 4,
                            },
            -flow_into => {
                           -1 => ['fast_trees_hugemem'],
                          },
             -rc_name => '16Gb_mpi_4c_job',
            },
            {
             -logic_name => 'fast_trees_hugemem',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees',
             -analysis_capacity => $self->o('fast_trees_capacity'),
             -parameters => {
                            %examl_parameters,
                             'fasttree_exe'          => $self->o('fasttree_exe'),
                             'parsimonator_exe'      => $self->o('parsimonator_exe'),
                             'examl_number_of_cores' => 4,
                            },
             -rc_name => '32Gb_mpi_4c_job',
            },

        {
         -logic_name => 'genomic_alignment_himem',
         -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment',
         -analysis_capacity => $self->o('genomic_alignment_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'cmd_max_runtime'       => '43200',
                            'raxml_number_of_cores' => 8,
                            'mafft_exe' => $self->o('mafft_exe'),
                            'prank_exe' => $self->o('prank_exe'),
                            'inhugemem' => 1,
                           },
         -rc_name => '8Gb_8c_job',
         -priority  => $self->o('genomic_alignment_himem_priority'),
         -flow_into => {
                        3 => [ 'fast_trees' ],
                        2 => [ 'genomic_tree_himem' ],
                        -1 => [ 'genomic_alignment_hugemem' ],
                       },
        },
        {
         -logic_name => 'genomic_alignment_hugemem',
         -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment',
         -analysis_capacity => $self->o('genomic_alignment_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'raxml_number_of_cores' => 8,
                            'mafft_exe' => $self->o('mafft_exe'),
                            'prank_exe' => $self->o('prank_exe'),
                            'inhugemem' => 1,
                           },
         -rc_name => '32Gb_8c_job',
         -flow_into => {
                        3 => [ 'fast_trees_himem' ],
                        2 => [ 'genomic_tree_himem' ],
                       },
        },


            {
             -logic_name => 'genomic_tree',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicTree',
             -analysis_capacity => $self->o('genomic_tree_capacity'),
             -parameters => {
                             'treebest_exe' => $self->o('treebest_exe'),
                            },
             -flow_into => {
                            -2 => ['genomic_tree_himem'],
                            -1 => ['genomic_tree_himem'],
                           },
             -rc_name => '250Mb_job',
            },

            {
             -logic_name => 'genomic_tree_himem',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicTree',
             -analysis_capacity => $self->o('genomic_tree_capacity'),
             -parameters => {
                             'treebest_exe' => $self->o('treebest_exe'),
                            },
             -rc_name => '1Gb_job',
            },

        {   -logic_name    => 'treebest_mmerge',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge',
            -analysis_capacity => $self->o('treebest_capacity'),
            -parameters => {
                            'treebest_exe' => $self->o('treebest_exe'),
                           },
            -flow_into  => [ 'orthotree', 'ktreedist', 'consensus_cigar_line_prep' ],
            -rc_name => '1Gb_job',
        },

        {   -logic_name    => 'orthotree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -analysis_capacity => $self->o('orthotree_capacity'),
            -parameters => {
                            'tag_split_genes'   => 0,
            },
            -flow_into  => {
                1 => [ 'hc_tree_homologies' ],
                -1 => [ 'orthotree_himem' ],
            },
           -rc_name => '250Mb_job',
        },

        {   -logic_name    => 'orthotree_himem',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -analysis_capacity => $self->o('orthotree_capacity'),
            -parameters => {
                            'tag_split_genes'   => 0,
            },
            -flow_into  => [ 'hc_tree_homologies' ],
           -rc_name => '1Gb_job',
        },

        {   -logic_name    => 'ktreedist',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist',
            -parameters => {
                            'treebest_exe'  => $self->o('treebest_exe'),
                            'ktreedist_exe' => $self->o('ktreedist_exe'),
                           },
            -rc_name => '1Gb_job',
        },

        {   -logic_name     => 'consensus_cigar_line_prep',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnConsensusCigarLine',
            -rc_name        => '2Gb_job',
            -batch_size     => 20,
        },

        {   -logic_name         => 'hc_tree_homologies',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_homologies',
            },
            %hc_params,
        },

        {   -logic_name => 'homology_stats_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory',
            -parameters => {
                'methods'   => {
                    'ENSEMBL_ORTHOLOGUES'   => 2,
                    'ENSEMBL_PARALOGUES'    => 3,
                },
            },
            -flow_into => {
                2 => {
                    'orthology_stats' => { 'homo_mlss_id' => '#mlss_id#' },
                },
                3 => {
                    'paralogy_stats' => { 'homo_mlss_id' => '#mlss_id#' },
                },
            },
        },

        {   -logic_name => 'orthology_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthologyStats',
            -parameters => {
                'member_type'           => 'ncrna',
            },
            -hive_capacity => $self->o('ortho_stats_capacity'),
        },

        {   -logic_name => 'paralogy_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats',
            -parameters => {
                'member_type'           => 'ncrna',
            },
            -hive_capacity => $self->o('ortho_stats_capacity'),
        },

        {   -logic_name => 'id_map_mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory',
            -parameters => {
                'methods'   => {
                    'ENSEMBL_ORTHOLOGUES'   => 2,
                },
            },
            -flow_into => {
                2 => [ 'mlss_id_mapping' ],
            },
        },

        {   -logic_name => 'mlss_id_mapping',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDMapping',
            -hive_capacity => $self->o('homology_id_mapping_capacity'),
            -flow_into => { 1 => { 'homology_id_mapping' => INPUT_PLUS() } },
        },

        {   -logic_name => 'homology_id_mapping',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -flow_into  => {
                -1 => [ 'homology_id_mapping_himem' ],
            },
            -hive_capacity => $self->o('homology_id_mapping_capacity'),
        },

        {   -logic_name => 'homology_id_mapping_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -rc_name => '1Gb_job',
            -hive_capacity => $self->o('homology_id_mapping_capacity'),
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE::pipeline_analyses_cafe_with_full_species_tree($self) },
    ];
}

1;

