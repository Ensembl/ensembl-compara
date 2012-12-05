
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf -password <your_password>

=head1 DESCRIPTION  

    This is an experimental PipeConfig file for ncRNAtrees pipeline (work in progress)

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf ;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

            # parameters that are likely to change from execution to another:
            # 'mlss_id'             => 40088,
            'release'               => '70',
            'rel_suffix'            => '',    # an empty string by default, a letter or string otherwise
            'work_dir'              => '/lustre/scratch110/ensembl/'.$self->o('ENV', 'USER').'/nc_trees_'.$self->o('rel_with_suffix'),

            # dependent parameters
            'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
            'dump_dir'              => $self->o('work_dir') . '/dumps',
            'ss_picts_dir'          => $self->o('work_dir') . '/ss_picts/',
            'pipeline_name'         => 'NC_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

            # dump parameters:
            'dump_table_list'       => '',  # probably either '#updated_tables#' or '' (to dump everything)
            'dump_exclude_ehive'    => 0,


            # capacity values for some analysis:
            'quick_tree_break_capacity'       => 100,
            'msa_chooser_capacity'            => 100,
            'other_paralogs_capacity'         => 100,
            'merge_supertrees_capacity'       => 100,
            'aligner_for_tree_break_capacity' => 200,
            'infernal_capacity'               => 200,
            'orthotree_capacity'              => 200,
            'treebest_capacity'               => 400,
            'genomic_tree_capacity'           => 200,
            'genomic_alignment_capacity'      => 200,
            'fast_trees_capacity'             => 200,
            'raxml_capacity'                  => 200,
            'recover_capacity'                => 150,
            'ss_picts_capacity'               => 200,

            # executable locations:
            'cmalign_exe'           => '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmalign',
            'cmbuild_exe'           => '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmbuild',
            'cmsearch_exe'          => '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmsearch',
            'mafft_exe'             => '/software/ensembl/compara/mafft-6.707/bin/mafft',
            'mafft_binaries'        => '/software/ensembl/compara/mafft-6.707/binaries',
            'raxml_exe'             => '/software/ensembl/compara/raxml/RAxML-7.2.8-ALPHA/raxmlHPC-SSE3',
            'prank_exe'             => '/software/ensembl/compara/prank/090707/src/prank',
            'raxmlLight_exe'        => '/software/ensembl/compara/raxml/RAxML-Light-1.0.5/raxmlLight',
            'parsimonator_exe'      => '/software/ensembl/compara/parsimonator/Parsimonator-1.0.2/parsimonator-SSE3',
            'ktreedist_exe'         => '/software/ensembl/compara/ktreedist/Ktreedist.pl',
            'fasttree_exe'          => '/software/ensembl/compara/fasttree/FastTree',
            'treebest_exe'          => '/software/ensembl/compara/treebest.doubletracking',
            'sreformat_exe'         => '/usr/local/ensembl/bin/sreformat',
            'quicktree_exe'         => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
#            'b2ct_exe'              => '/software/ensembl/compara/ViennaRNA-2.0.7/Utils/b2ct',
#            'sir_graph_exe'         => '/software/ensembl/compara/mfold_util-4.6/src/sir_graph',
            'r2r_exe'               => '/software/ensembl/compara/R2R-1.0.3/src/r2r',

            # tree break
            'treebreak_gene_count'     => 500,
            'treebreak_tags_to_copy'   => ['clustering_id', 'model_name'],

            # misc parameters
            'species_tree_input_file'  => '',  # empty value means 'create using genome_db+ncbi_taxonomy information'; can be overriden by a file with a tree in it
            'skip_epo'                 => 0,   # Never tried this one. It will probably fail


            # connection parameters
            'pipeline_db' => {
                              -driver => 'mysql',
                              -host   => 'compara2',
                              -port   => 3306,
                              -user   => 'ensadmin',
                              -pass   => $self->o('password'),
                              -dbname => $ENV{'USER'}.'_compara_nctrees_'.$self->o('rel_with_suffix'),
                             },

            'reg1' => {
                       -host   => 'ens-staging',
                       -port   => 3306,
                       -user   => 'ensro',
                       -pass   => '',
                      },

            'reg2' => {
                       -host   => 'ens-staging2',
                       -port   => 3306,
                       -user   => 'ensro',
                       -pass   => '',
                      },

            'master_db' => {
                            -host   => 'compara1',
                            -port   => 3306,
                            -user   => 'ensro',
                            -pass   => '',
                            -dbname => 'sf5_ensembl_compara_master', # 'sf5_ensembl_compara_master',
                           },

            'epo_db' => {   # ideally, the current release database with epo pipeline results already loaded
                         -host   => 'compara3',
                         -port   => 3306,
                         -user   => 'ensro',
                         -pass   => '',
                         -dbname => 'sf5_ensembl_compara_69',
                        },
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

sub resource_classes {
    my ($self) = @_;
    return {
            'default'   => { 'LSF' => '-M2000000 -R"select[mem>2000] rusage[mem=2000]"' },
            'himem'     => { 'LSF' => '-q basement -M15000000 -R"select[mem>15000] rusage[mem=15000]"' },
            '1Gb_job'   => { 'LSF' => '-C0         -M1000000  -R"select[mem>1000]  rusage[mem=1000]"' },
            '8Gb_job'   => { 'LSF' => '-C0         -M8000000  -R"select[mem>8000]  rusage[mem=8000]"' },
            '4Gb_job'   => { 'LSF' => '-C0         -M4000000  -R"select[mem>4000]  rusage[mem=4000]"' },
           };
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
            },

            {   -logic_name => 'backbone_fire_load',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -parameters  => [ {
                                  'updated_tables'    => 'method_link species_set method_link_species_set ncbi_taxa_name ncbi_taxa_node',   ## Fill
                                  'filename'          => 'snapshot_before_load',
                                  'output_file'       => $self->o('dump_dir').'/#filename#',
                                } ],
                -flow_into  => {
                               '1->A'   => [ 'load_genomedb_factory' ],
                               'A->1'   => [ 'backbone_fire_tree_building' ],
                              },
            },

            {   -logic_name => 'backbone_fire_tree_building',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -parameters  => [ {
                                  'updated_tables'    => 'genome_db members',   ## Fill -- more?, species_set?
                                  'filename'          => 'snapshot_before_tree_building',
                                  'output_file'       => $self->o('dump_dir').'/#filename#',
                                 } ],
                -flow_into  => {
                                '1->A'  => [ 'rfam_classify' ],
                                'A->1'  => [ 'backbone_pipeline_finished' ],
                               },
            },

            {   -logic_name => 'backbone_pipeline_finished',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            },

# ---------------------------------------------[copy tables from master and fix the offsets]---------------------------------------------

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'   => $self->o('master_db'),
                'inputlist' => [ 'method_link', 'species_set', 'method_link_species_set', 'ncbi_taxa_name', 'ncbi_taxa_node' ],
                'column_names' => [ 'table' ],
                'input_id'  => { 'src_db_conn' => '#db_conn#', 'table' => '#table#' },
                'fan_branch_code' => 2,
            },

            -flow_into => {
                           '2->A' => [ 'copy_table' ],
                           'A->1' => [ 'offset_tables' ],
#                2 => [ 'copy_table'  ],
#                1 => [ 'offset_tables' ],  # backbone
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
                    'ALTER TABLE species_tree_node AUTO_INCREMENT=100000001',
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
                'fan_branch_code' => 2,
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

                                'fan_branch_code'       => 2,
                               },
                -flow_into => {
                               '2->A' => [ 'load_genomedb' ],           # fan
                               'A->1' => [ 'load_genomedb_funnel' ],
                               1      => [ 'load_rfam_models' ],
                              },
            },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                            'registry_dbs'   => [ $self->o('reg1'), $self->o('reg2') ],
            },
            -hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
            -flow_into => {
                1 => [ 'load_members_factory' ],   # each will flow into another one
            },
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
                           1 => [ 'make_species_tree', 'create_lca_species_set' ],
            },
        },

# ---------------------------------------------[load species tree]-------------------------------------------------------------------


        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                'species_tree_input_file' => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
                'multifurcation_deletes_node'           => [ 33316, 129949, 314146 ],
                'multifurcation_deletes_all_subnodes'   => [  9347, 186625,  32561 ],
                'mlss_id'                               => $self->o('mlss_id'),
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into  => {
                3 => { 'mysql:////method_link_species_set_tag' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'species_tree', 'value' => '#species_tree_string#' } },
            },
        },


# ---------------------------------------------[create the low-coverage-assembly species set]-----------------------------------------

        {   -logic_name => 'create_lca_species_set',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  "INSERT INTO species_set (genome_db_id) SELECT genome_db_id FROM genome_db LIMIT 1",   # insert a dummy pair (auto_increment++, <anything>) into the table
                            "DELETE FROM species_set WHERE species_set_id IN (#_insert_id_0#)",     # delete the previously inserted row, but keep the auto_increment
                ],
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                2 => {
                    'generate_pre_species_set'     => { 'lca_species_set_id' => '#_insert_id_0#' },     # pass it on to the query
                    'mysql:////species_set_tag' => { 'species_set_id' => '#_insert_id_0#', 'tag' => 'name', 'value' => 'low-coverage-assembly' },   # record the id in ss_tag table
                },
            },
        },

        {   -logic_name => 'generate_pre_species_set',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',    # another non-stardard use of JobFactory for iterative insertion
            -parameters => {
                'db_conn'         => $self->o('epo_db'),
                'inputquery'      => "SELECT #lca_species_set_id# as lca_species_set_id, GROUP_CONCAT(DISTINCT g.genome_db_id) as pre_species_set FROM genome_db g JOIN species_set ss USING(genome_db_id) JOIN method_link_species_set mlss USING(species_set_id) WHERE assembly_default AND mlss.name LIKE '%EPO_LOW_COVERAGE%' AND g.genome_db_id NOT IN (SELECT DISTINCT(g2.genome_db_id) FROM genome_db g2 JOIN species_set ss2 USING(genome_db_id) JOIN method_link_species_set mlss2 USING(species_set_id) WHERE assembly_default AND mlss2.name LIKE '%EPO')",
                'fan_branch_code' => 3,
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                           3 => [ 'store_lca_species_set' ],
            },
        },

        {   -logic_name => 'store_lca_species_set',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',    # another non-stardard use of JobFactory for iterative insertion
            -parameters => {
                'inputquery'      => "SELECT #lca_species_set_id# as species_set_id, genome_db_id FROM genome_db where genome_db_id in (#pre_species_set#)",
                'fan_branch_code' => 3,
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                3 => [ 'mysql:////species_set' ],
            },
        },

# ---------------------------------------------[load ncRNA and gene members]---------------------------------------------

        {   -logic_name    => 'load_members_factory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenomePrepareNCMembers',
            -hive_capacity => 10,
            -flow_into => {
                2 => [ 'load_members' ],   # per-genome fan
            },
            -rc_name => 'default',
        },

        {   -logic_name    => 'load_members',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GeneStoreNCMembers',
            -hive_capacity => 30,
            -rc_name => 'default',
        },

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
                                'fan_branch_code' => 2,
                               },

                -rc_name       => 'default',
                -flow_into     => {
                                   2 => [ 'recover_epo' ],
                                  },
            },


        {   -logic_name    => 'recover_epo',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverEPO',
            -parameters    => {
                'mlss_id'        => $self->o('mlss_id'),
                'epo_db'         => $self->o('epo_db'),
                'skip'           => $self->o('skip_epo'),
            },
            -hive_capacity => $self->o('recover_capacity'),
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
                -hive_capacity => $self->o('msa_chooser_capacity'),
                -flow_into     => {
                                   '1->A' => [ 'genomic_alignment', 'infernal' ],
                                   'A->1' => [ 'treebest_mmerge' ],
                                   '3->B' => [ 'aligner_for_tree_break' ],
                                   'B->4' => [ 'quick_tree_break' ],
                                  },
            },

            {   -logic_name    => 'aligner_for_tree_break',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -hive_capacity => $self->o('aligner_for_tree_break_capacity'),
                -parameters => {
                                'cmbuild_exe' => $self->o('cmbuild_exe'),
                                'cmalign_exe' => $self->o('cmalign_exe'),
                               },
                -rc_name => 'default',
            },

            {   -logic_name => 'quick_tree_break',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak',
                -parameters => {
                                'mlss_id'           => $self->o('mlss_id'),
                                'quicktree_exe'     => $self->o('quicktree_exe'),
                                'sreformat_exe'     => $self->o('sreformat_exe'),
                                'tags_to_copy'      => $self->o('treebreak_tags_to_copy'),
                                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                               },
                -hive_capacity  => $self->o('quick_tree_break_capacity'),
                -rc_name        => '4Gb_job',
                -priority       => 50,
                -flow_into      => [ 'other_paralogs' ],
            },

            {   -logic_name     => 'other_paralogs',
                -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
                -parameters     => {
                                    'dataflow_subclusters' => 1,
                                    'mlss_id'              => $self->o('mlss_id'),
                                   },
                -hive_capacity  => $self->o('other_paralogs_capacity'),
                -rc_name        => '1Gb_job',
                -priority       => 40,
                -flow_into => {
                               '2->A' => [ 'genomic_alignment', 'infernal' ],
                               'A->2' => [ 'treebest_mmerge' ],
                              },
            },

            {   -logic_name    => 'infernal',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -hive_capacity => $self->o('infernal_capacity'),
                -parameters    => {
                                   'cmbuild_exe' => $self->o('cmbuild_exe'),
                                   'cmalign_exe' => $self->o('cmalign_exe'),
                                  },
                -flow_into     => {
                                   1 => ['pre_sec_struct_tree' ],
                                   3 => ['create_ss_picts'],
                                  },
                -rc_name       => 'default',
            },

            {   -logic_name    => 'create_ss_picts',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenerateSSPict',
                -hive_capacity => $self->o('ss_picts_capacity'),
                -parameters    => {
                                   'ss_picts_dir'  => $self->o('ss_picts_dir'),
#                                   'b2ct_exe'      => $self->o('b2ct_exe'),
#                                   'sir_graph_exe' => $self->o('sir_graph_exe'),
                                   'r2r_exe'       => $self->o('r2r_exe'),
                                  },
                -rc_name       => 'default',
            },

            {
             -logic_name    => 'pre_sec_struct_tree', ## pre_sec_struct_tree
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels',  ## PrepareRAxMLSecModels -- rename
             -hive_capacity => $self->o('raxml_capacity'),
             -parameters => {
                             'raxml_exe' => $self->o('raxml_exe'),
                            },
             -flow_into => {
                            2 => [ 'sec_struct_model_tree'],
                            -1 => ['fast_trees'],  # -1 is MEMLIMIT
                            -2 => ['fast_trees'],  # -2 is TIMELIMIT
                           },
             -rc_name => 'default',
            },

#         {
#          -logic_name => 'pre_sec_struct_tree_himem',
#          -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels',
#          -hive_capacity => 200,
#          -parameters => {
#                          'raxml_exe' => $self->o('raxml_exe'),
#                         },
#          -flow_into => {
#                         1 => [ 'treebest_mmerge' ],
#                         2 => [ 'sec_struct_model_tree_himem' ],
#                        },
#          -can_be_empty => 1,
#          -rc_id => 1,
#         },

        {   -logic_name    => 'sec_struct_model_tree', ## sec_struct_model_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree', ## SecStrucModels
            -hive_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            'raxml_exe' => $self->o('raxml_exe'),
                           },
            -flow_into => {
                           -1 => [ 'sec_struct_model_tree_himem' ],
                           -2 => [ 'sec_struct_model_tree_himem' ],
                          },
            -rc_name => 'default',
        },

        {
         -logic_name => 'sec_struct_model_tree_himem',
         -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree',
         -hive_capacity => $self->o('raxml_capacity'),
         -parameters => {
                         'raxml' => $self->o('raxml_exe'),
                        },
         -can_be_empty => 1,
         -rc_name => 'himem',
        },

        {   -logic_name    => 'genomic_alignment',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment',
            -hive_capacity => $self->o('genomic_alignment_capacity'),
            -parameters => {
                            'mafft_exe' => $self->o('mafft_exe'),
                            'mafft_binaries' => $self->o('mafft_binaries'),
                            'raxml_exe' => $self->o('raxml_exe'),
                            'prank_exe' => $self->o('prank_exe'),
                           },
            -flow_into => {
                           -2 => ['genomic_alignment_long'],
                           -1 => ['genomic_alignment_long'],
                           3  => ['fast_trees'],
                           2  => ['genomic_tree'],
                          },
            -rc_name => 'default',
        },

            {
             -logic_name => 'fast_trees',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees',
             -hive_capacity => $self->o('fast_trees_capacity'),
             -parameters => {
                             'fasttree_exe' => $self->o('fasttree_exe'),
                             'parsimonator_exe' => $self->o('parsimonator_exe'),
                             'raxmlLight_exe' => $self->o('raxmlLight_exe'),
                            },
             -can_be_empty => 1,
             -rc_name => 'himem',
            },

        {
         -logic_name => 'genomic_alignment_long',
         -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment',
         -hive_capacity => $self->o('genomic_alignment_capacity'),
            -parameters => {
                            'mafft_exe' => $self->o('mafft_exe'),
                            'mafft_binaries' => $self->o('mafft_binaries'),
                            'raxml_exe' => $self->o('raxml_exe'),
                            'prank_exe' => $self->o('prank_exe'),
                           },
         -can_be_empty => 1,
         -rc_name => 'himem',
         -flow_into => {
                        2 => ['genomic_tree_himem'],
                       },
        },

            {
             -logic_name => 'genomic_tree',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicTree',
             -hive_capacity => $self->o('genomic_tree_capacity'),
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
             -hive_capacity => $self->o('genomic_tree_capacity'),
             -parameters => {
                             'treebest_exe' => $self->o('treebest_exe'),
                             'mlss_id' => $self->o('mlss_id'),
                            },
             -can_be_empty => 1,
             -rc_name => 'himem',
            },

        {   -logic_name    => 'treebest_mmerge',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge',
            -hive_capacity => $self->o('treebest_capacity'),
            -parameters => {
                            'treebest_exe' => $self->o('treebest_exe'),
                            'mlss_id' => $self->o('mlss_id'),
                           },
            -flow_into => {
                           1 => [ 'orthotree', 'ktreedist' ],
                           -1 => [ 'treebest_mmerge_himem' ],
                           -2 => [ 'treebest_mmerge_himem' ],
            },
            -rc_name => 'default',
        },

        {
         -logic_name => 'treebest_mmerge_himem',
         -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge',
         -hive_capacity => $self->o('treebest_capacity'),
         -parameters => {
                         'treebest_exe' => $self->o('treebest_exe'),
                         'mlss_id' => $self->o('mlss_id'),
                        },
         -flow_into => {
                        1 => [ 'orthotree', 'ktreedist' ],
                       },
         -rc_name => 'himem',
        },

        {   -logic_name    => 'orthotree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -hive_capacity => $self->o('orthotree_capacity'),
            -parameters => {
                            'tag_split_genes'   => 0,
                            'mlss_id' => $self->o('mlss_id'),
            },
            -flow_into => {
                           -1 => ['orthotree_himem' ],
                           -2 => ['orthotree_himem' ],
                          },
            -rc_name => 'default',
        },

        {
         -logic_name => 'orthotree_himem',
         -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
         -hive_capacity => $self->o('orthotree_capacity'),
         -parameters => {
                         'tag_split_genes'   => 0,
                         'mlss_id' => $self->o('mlss_id'),
         },
         -rc_name => 'himem',
        },

        {   -logic_name    => 'ktreedist',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist',
            -hive_capacity => -1,
            -parameters => {
                            'treebest_exe'  => $self->o('treebest_exe'),
                            'ktreedist_exe' => $self->o('ktreedist_exe'),
                            'mlss_id' => $self->o('mlss_id'),
                           },
            -flow_into => {
                           -1 => [ 'ktreedist_himem' ],
                          },
            -rc_name => 'default',
        },

        {
         -logic_name => 'ktreedist_himem',
         -module => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Ktreedist',
         -hive_capacity => -1,
         -parameters => {
                         'treebest_exe'  => $self->o('treebest_exe'),
                         'ktreedist_exe' => $self->o('ktreedist_exe'),
                         'mlss_id' => $self->o('mlss_id'),
                        },
         -rc_name => 'himem',
        },

    ];
}

1;

