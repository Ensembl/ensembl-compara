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

Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION

This is the ncRNAtrees pipeline.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf ;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS

use Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpHomologiesForPosttree;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::OrthologQMAlignment;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => $self->o('collection') . '_' . $self->o('division') . '_ncrna_trees_' . $self->o('rel_with_suffix'),
        'method_type'   => 'NC_TREES',

        'work_dir' => $self->o('pipeline_dir'),

            # dependent parameters ('work_dir' should be defined)
            'dump_dir'              => $self->o('work_dir') . '/dumps',
            'ss_picts_dir'          => $self->o('work_dir') . '/ss_picts/',
            'gene_dumps_dir'        => $self->o('dump_dir') . '/genes',

            # How will the pipeline create clusters (families) ?
            # Possible values: 'rfam' (default) or 'ortholog'
            #   'blastp' means that the pipeline will clusters genes according to their RFAM accession
            #   'ortholog' means that the pipeline will use previously inferred orthologs to perform a cluster projection
            'clustering_mode'           => 'rfam',

        'master_db'   => 'compara_master',
        'member_db'   => 'compara_members',
        'mapping_db'  => 'compara_prev',
        'prev_rel_db' => 'compara_prev',
        # The following parameter should ideally contain EPO-2X alignments of
        # all the genomes used in the ncRNA-trees. However, due to release
        # coordination considerations, this may not be possible. If so, use the
        # one from the previous release.
        'epo_db'      => 'compara_prev',

        # The dbs required for OrthologQMAlignment alt_aln_dbs can be an array list of alignment dbs
        'alt_aln_dbs'     => [
            'compara_curr',
        ],

     # Whole db DC parameters
     'datacheck_groups' => ['compara_gene_tree_pipelines'],
     'db_type'          => ['compara'],
     'output_dir_path'  => $self->o('work_dir') . '/datachecks/',
     'overwrite_files'  => 1,
     'failures_fatal'   => 1, # no DC failure tolerance
     'db_name'          => $self->o('dbowner') . '_' . $self->o('pipeline_name'),

    # Parameters to allow merging different runs of the pipeline
        'dbID_range_index'      => 14,
        'collection'            => 'default',
        'species_set_name'      => $self->o('collection'),
        'label_prefix'          => '',
        'member_type'           => 'ncrna',

        # capacity values for some analysis:
        'quick_tree_break_capacity'       => 100,
        'msa_chooser_capacity'            => 200,
        'other_paralogs_capacity'         => 200,
        'aligner_for_tree_break_capacity' => 200,
        'infernal_capacity'               => 200,
        'orthotree_capacity'              => 200,
        'treebest_capacity'               => 400,
        'genomic_tree_capacity'           => 300,
        'genomic_alignment_capacity'      => 700,
        'fast_trees_capacity'             => 400,
        'raxml_capacity'                  => 700,
        'recover_capacity'                => 150,
        'ss_picts_capacity'               => 200,
        'ortho_stats_capacity'            => 10,
        'homology_id_mapping_capacity'    => 10,
        'cafe_capacity'                   => 50,
        'decision_capacity'               => 4,

        # Setting priorities
        'genomic_alignment_priority'       => 35,
        'genomic_alignment_himem_priority' => 40,

            # tree break
            'treebreak_tags_to_copy'   => ['model_id', 'model_name'],
            'treebreak_gene_count'     => 400,

        # Params for healthchecks;
        'hc_priority'   => 10,
        'hc_capacity'   => 40,
        'hc_batch_size' => 10,

        # RFAM parameters
        'rfam_ftp_url'           => 'ftp://ftp.ebi.ac.uk/pub/databases/Rfam/12.0/',
        'rfam_remote_file'       => 'Rfam.cm.gz',
        'rfam_expanded_basename' => 'Rfam.cm',
        'rfam_expander'          => 'gunzip ',

        # miRBase database
        'mirbase_url' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/mirbase_22',

            # misc parameters
            'species_tree_input_file'  => '',  # empty value means 'create using genome_db+ncbi_taxonomy information'; can be overriden by a file with a tree in it
            'binary_species_tree_input_file'   => undef, # you can define your own species_tree for 'CAFE'. It *has* to be binary
            'skip_epo'                 => 0,   # Never tried this one. It may fail
            'create_ss_picts'          => 0,

            # ambiguity codes
            'allow_ambiguity_codes'    => 1,

            # Do we want to initialise the CAFE part now ?
            'do_cafe'                  => undef,
            # Data needed for CAFE
            'cafe_lambdas'             => '',  # For now, we don't supply lambdas
            'cafe_struct_tree_str'     => '',  # Not set by default
            'full_species_tree_label'  => 'full_species_tree',
            'per_family_table'         => 0,
            'cafe_species'             => [],

            # Analyses usually don't fail
            'hive_default_max_retry_count'  => 1,
            
            # homology dumps options
            'orthotree_dir'             => $self->o('dump_dir') . '/orthotree/',
            'homology_dumps_dir'        => $self->o('dump_dir'). '/homology_dumps/',
            'homology_dumps_shared_dir' => $self->o('homology_dumps_shared_basedir') . '/' . $self->o('collection')    . '/' . $self->o('ensembl_release'),
            'prev_homology_dumps_dir'   => $self->o('homology_dumps_shared_basedir') . '/' . $self->o('collection')    . '/' . $self->o('prev_release'),

            # Parameters for OrthologQMAlignment
            'wga_species_set_name'       => "collection-" . $self->o('collection'),
            'homology_method_link_types' => ['ENSEMBL_ORTHOLOGUES'],
            # WGA dump directories for OrthologQMAlignment
            'wga_dumps_dir'      => $self->o('homology_dumps_dir'),
            'prev_wga_dumps_dir' => $self->o('homology_dumps_shared_basedir') . '/' . $self->o('collection')    . '/' . $self->o('prev_release'),
            # set how many orthologs should be flowed at a time
            'orth_batch_size'   => 10,
            # set to 1 when all pairwise and multiple WGA complete
            'dna_alns_complete' => 0,
            # populated by the check_file_copy analysis when wga analyses finished
            'orth_wga_complete' => 0,

            #Parameters for HighConfidenceOrthologs
            'threshold_levels'            => [ ],          # division specific
            'high_confidence_capacity'    => 500,          # how many mlss_ids can be processed in parallel
            'import_homologies_capacity'  => 50,           # how many homology mlss_ids can be imported in parallel (via mysqlimport)
            'goc_files_dir'               => $self->o('homology_dumps_dir'),
            'range_label'                 => $self->o('member_type'),

        # Gene tree stats options
        'gene_tree_stats_shared_dir' => $self->o('gene_tree_stats_shared_basedir') . '/' . $self->o('collection') . '/' . $self->o('ensembl_release'),
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
            @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

            $self->pipeline_create_commands_rm_mkdir(['work_dir', 'dump_dir', 'ss_picts_dir', 'gene_dumps_dir', 'output_dir_path']),
            $self->pipeline_create_commands_rm_mkdir(['gene_tree_stats_shared_dir'], undef, 'do not rm'),

            $self->db_cmd( 'CREATE TABLE ortholog_quality (
                            homology_id              INT NOT NULL,
                            genome_db_id             INT NOT NULL,
                            alignment_mlss           INT NOT NULL,
                            combined_exon_coverage   FLOAT(5,2) NOT NULL,
                            combined_intron_coverage FLOAT(5,2) NOT NULL,
                            quality_score            FLOAT(5,2) NOT NULL,
                            exon_length              INT NOT NULL,
                            intron_length            INT NOT NULL,
                            INDEX (homology_id)
            )'),

           $self->db_cmd( 'CREATE TABLE datacheck_results (
                                  submission_job_id INT,
                                  dbname VARCHAR(255) NOT NULL,
                                  passed INT,
                                  failed INT,
                                  skipped INT,
                                  INDEX submission_job_id_idx (submission_job_id)
             )'),
    ];
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'ensembl_release' => $self->o('ensembl_release'),

        'master_db'     => $self->o('master_db'),
        'member_db'     => $self->o('member_db'),
        'prev_rel_db'   => $self->o('prev_rel_db'),
        'alt_aln_dbs'   => $self->o('alt_aln_dbs'),
        'mapping_db'    => $self->o('mapping_db'),

        'pipeline_dir'              => $self->o('pipeline_dir'),
        'output_dir_path'           => $self->o('output_dir_path'),
        'dump_dir'                  => $self->o('dump_dir'),
        'homology_dumps_dir'        => $self->o('homology_dumps_dir'),
        'prev_homology_dumps_dir'   => $self->o('prev_homology_dumps_dir'),
        'homology_dumps_shared_dir' => $self->o('homology_dumps_shared_dir'),
        'orthotree_dir'             => $self->o('orthotree_dir'),
        'wga_dumps_dir'             => $self->o('wga_dumps_dir'),
        'prev_wga_dumps_dir'        => $self->o('prev_wga_dumps_dir'),
        'gene_dumps_dir'            => $self->o('gene_dumps_dir'),
        'gene_tree_stats_shared_dir' => $self->o('gene_tree_stats_shared_dir'),

        'goc_files_dir'      => $self->o('goc_files_dir'),
        'wga_files_dir'      => $self->o('wga_dumps_dir'),
        'hashed_mlss_id'     => '#expr(dir_revhash(#mlss_id#))expr#',
        'goc_file'           => '#goc_files_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.goc.tsv',
        'wga_file'           => '#wga_files_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.wga.tsv',
        'previous_wga_file'  => defined $self->o('prev_wga_dumps_dir') ? '#prev_wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga.tsv' : undef,
        'high_conf_file'     => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.high_conf.tsv',

        'skip_epo'      => $self->o('skip_epo'),
        'epo_db'        => $self->o('epo_db'),

        'member_type'       => $self->o('member_type'),
        'create_ss_picts'   => $self->o('create_ss_picts'),
        'do_cafe'           => $self->o('do_cafe'),
        'dbID_range_index'  => $self->o('dbID_range_index'),
        'clustering_mode'   => $self->o('clustering_mode'),
        'threshold_levels'  => $self->o('threshold_levels'),
        'range_label'       => $self->o('range_label'),

        'dna_alns_complete' => $self->o('dna_alns_complete'), # manually change to 1 when all wgas have finished
        'orth_wga_complete' => $self->o('orth_wga_complete'), # populated by the check_file_copy analysis when wga analyses finished

        'orth_batch_size'             => $self->o('orth_batch_size'),
        'high_confidence_capacity'    => $self->o('high_confidence_capacity'),
        'import_homologies_capacity'  => $self->o('import_homologies_capacity'),

    }
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},  # inherit the standard resource classes, incl. multi-threaded
    };
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my %hc_params = (
                     -analysis_capacity => $self->o('hc_capacity'),
                     -priority          => $self->o('hc_priority'),
                     -batch_size        => $self->o('hc_batch_size'),
                    );

    my %raxml_decision_params = (
        # The number of cores is based on the number of "alignment patterns"
        # Here we don't have that exact value so approximate it with half
        # of the number of columns in the alignment (assuming some columns
        # will be paired and some will be redundant).
        'raxml_cores'              => '#expr( (#aln_length# / 2) / #raxml_patterns_per_core# )expr#',
        # 500 is the value advised for DNA alignments
        'raxml_patterns_per_core'  => 500,
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

    my %decision_analysis_params = (
            -analysis_capacity  => $self->o('decision_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
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
            },

            {   -logic_name => 'backbone_fire_tree_building',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
                -parameters  => {
                                  'output_file'          => $self->o('dump_dir').'/snapshot_before_tree_building.sql',
                                 },
                -flow_into  => {
                                '1->A'  => [ 'clusters_factory' ],
                                'A->1'  => [ 'backbone_fire_posttree' ],
                               },
            },
            
            {   -logic_name => 'backbone_fire_posttree',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -flow_into  => {
                    '1->A' => ['rib_fire_homology_dumps'],
                    'A->1' => ['backbone_pipeline_finished'],
                },
            },

            {   -logic_name => 'backbone_pipeline_finished',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -flow_into  => [ 
                    'notify_pipeline_completed',
                    'wga_expected_dumps',                    
                    WHEN( '#homology_dumps_shared_dir#' => 'copy_dumps_to_shared_loc' ), 
                ],
            },

            {   -logic_name => 'notify_pipeline_completed',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::NotifyByEmail',
                -parameters => {
                    'text'  => 'The pipeline has completed.',
                    'email' => $self->o('email'),
                    },
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

        # CreateReuseSpeciesSets/PrepareSpeciesSetsMLSS may want to create new
        # entries. We need to make sure they don't collide with the master database
        {   -logic_name => 'offset_more_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE species_set_header      AUTO_INCREMENT=10000001',
                    'ALTER TABLE method_link_species_set AUTO_INCREMENT=10000001',
                ],
            },
            -flow_into  => [ 'load_mlss_id' ],
        },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        {   -logic_name => 'load_mlss_id',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',
            -parameters => {
                'method_type'      => $self->o('method_type'),
                'species_set_name' => $self->o('species_set_name'),
                'release'          => '#ensembl_release#'
            },
            -flow_into  => [ 'load_genomedb_factory' ],
        },

            {   -logic_name => 'load_genomedb_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
                -parameters => {
                                'compara_db'            => '#master_db#',   # that's where genome_db_ids come from
                                'extra_parameters'      => [ 'locator' ],
                               },
                -flow_into => {
                               '2->A' => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, }, # fan
                               'A->1' => [ 'create_mlss_ss' ],
                              },
            },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -analysis_capacity => 10,
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -parameters => {
                'whole_method_links'        => [ $self->o('method_type') ],
                'singleton_method_links'    => [ 'ENSEMBL_PARALOGUES', 'ENSEMBL_HOMOEOLOGUES' ],
                'pairwise_method_links'     => [ 'ENSEMBL_ORTHOLOGUES' ],
            },
            -rc_name   => '1Gb_job',
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
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::InsertMemberProjections',
            -parameters => {
                'source_species_names'  => [ 'homo_sapiens', 'mus_musculus', 'danio_rerio' ],
            },
        },

# ---------------------------------------------[load species tree]-------------------------------------------------------------------


        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                'species_tree_input_file'               => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
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
                -parameters    => {
                    'mirbase_url'   => $self->o('mirbase_url'),
                },
                -flow_into     => [ 'expand_clusters_with_projections' ],
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
            -flow_into          => [ 'cluster_qc_factory' ],
            -rc_name => '500Mb_job',
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
                                       # 'backbone_fire_homology_dumps',
                                       WHEN('#do_cafe# and  #binary_species_tree_input_file#', 'CAFE_species_tree'),
                                       WHEN('#do_cafe# and !#binary_species_tree_input_file#', 'make_full_species_tree'),],
              %hc_params,
            },

        {
             -logic_name => 'rename_labels',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RenameLabels',
             -parameters => {
                 'clusterset_id'=> $self->o('collection'),
                 'label_prefix' => $self->o('label_prefix'),
             },
             -flow_into  => [ 'homology_stats_factory', 'id_map_mlss_factory' ],
        },

        {   -logic_name     => 'write_stn_tags',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters     => {
                'input_file'    => $self->o('tree_stats_sql'),
            },
            -flow_into      => [ 'generate_tree_stats_report' ],
        },

        {   -logic_name => 'generate_tree_stats_report',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StatsReport',
            -parameters => {
                'stats_exe'                  => $self->o('gene_tree_stats_report_exe'),
                'gene_tree_stats_shared_dir' => $self->o('gene_tree_stats_shared_dir'),
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
                -flow_into => {
                    1 => 'hc_epo_removed_members',
                    -1 => 'recover_epo_hugemem',
                },
                -rc_name => '16Gb_job',
            },

            {   -logic_name    => 'recover_epo_hugemem',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverEPO',
                -analysis_capacity => $self->o('recover_capacity'),
                -flow_into => [ 'hc_epo_removed_members' ],
                -rc_name => '24Gb_job',
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
                                'mxsize_increment'  => 3000,    # Must be in line with the memory of the _himem analysis
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
                               },
                -flow_into     => [ 'quick_tree_break' ],
                -rc_name => '8Gb_job',
            },

            {   -logic_name => 'quick_tree_break',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak',
                -parameters => {
                                'quicktree_exe'     => $self->o('quicktree_exe'),
                                'treebest_exe'      => $self->o('treebest_exe'),
                                'tags_to_copy'      => $self->o('treebreak_tags_to_copy'),
                                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                               },
                -analysis_capacity  => $self->o('quick_tree_break_capacity'),
                -rc_name        => '2Gb_job',
                -priority       => 50,
                -flow_into      => {
                   1   => ['other_paralogs', 'subcluster_factory'],
                   -1  => ['quick_tree_break_himem'], # MEMLIMIT
                },
            },

            {   -logic_name => 'quick_tree_break_himem',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak',
                -parameters => {
                                'quicktree_exe'     => $self->o('quicktree_exe'),
                                'treebest_exe'      => $self->o('treebest_exe'),
                                'tags_to_copy'      => $self->o('treebreak_tags_to_copy'),
                                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
                               },
                -analysis_capacity  => $self->o('quick_tree_break_capacity'),
                -rc_name        => '8Gb_job',
                -priority       => 50,
                -flow_into      => [ 'other_paralogs', 'subcluster_factory' ],
            },

            {   -logic_name     => 'other_paralogs',
                -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
                -parameters     => {
                    'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                    'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
                },
                -analysis_capacity  => $self->o('other_paralogs_capacity'),
                -priority           => 40,
                -rc_name            => '1Gb_job',
                -max_retry_count    => 3,
                -flow_into     => {
                                   -1 => [ 'other_paralogs_himem' ],
                                   3 => [ 'other_paralogs' ],
                                  },
            },

            {   -logic_name     => 'other_paralogs_himem',
                -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
                -parameters     => {
                    'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                    'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
                },
                -analysis_capacity  => $self->o('other_paralogs_capacity'),
                -priority           => 40,
                -rc_name            => '4Gb_job',
                -max_retry_count    => 3,
                -flow_into     => {
                                   3 => [ 'other_paralogs_himem' ],
                                  },
            },


            {   -logic_name     => 'subcluster_factory',
                -module         => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters     => {
                    'inputquery'    => 'SELECT gtn1.root_id AS gene_tree_id FROM (gene_tree_node gtn1 JOIN gene_tree_root_attr USING (root_id)) JOIN gene_tree_node gtn2 ON gtn1.parent_id = gtn2.node_id WHERE gtn1.root_id != gtn2.root_id AND gtn2.root_id = #gene_tree_id#',
                },
                -hive_capacity  => $self->o('other_paralogs_capacity'),
                -flow_into      => {
                    2 => [ 'tree_backup' ],
                }
            },

            {   -logic_name    => 'infernal',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -analysis_capacity => $self->o('infernal_capacity'),
                -parameters    => {
                                   'cmbuild_exe' => $self->o('cmbuild_exe'),
                                   'cmalign_exe' => $self->o('cmalign_exe'),
                                   'mxsize_increment'  => 10000,    # Must be in line with the memory of the _himem analysis
                                  },
                -flow_into     => {
                                  -1 => [ 'infernal_himem' ],
                                   1 => [ 'pre_secondary_structure_decision', WHEN('#create_ss_picts#' => 'create_ss_picts' ) ],
                                  },
                -rc_name       => '1Gb_job',
            },

            {   -logic_name    => 'infernal_himem',
                -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal',
                -analysis_capacity => $self->o('infernal_capacity'),
                -parameters    => {
                                   'cmbuild_exe' => $self->o('cmbuild_exe'),
                                   'cmalign_exe' => $self->o('cmalign_exe'),
                                  },
                -flow_into     => [ 'pre_secondary_structure_decision', WHEN('#create_ss_picts#' => 'create_ss_picts' ) ],
                -rc_name       => '16Gb_job',
            },

            {   -logic_name => 'pre_secondary_structure_decision',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -parameters => {
                    %raxml_decision_params,
                },
                -flow_into => {
                    1 => WHEN(
                        '(#raxml_cores# <= 1)'                                  => 'pre_sec_struct_tree_1_core',
                        '(#raxml_cores# >  1)  && (#raxml_cores# <= 2)'         => 'pre_sec_struct_tree_2_cores',
                        '(#raxml_cores# >  2)  && (#raxml_cores# <= 4)'         => 'pre_sec_struct_tree_4_cores',
                        '(#raxml_cores# >  4)'                                  => 'pre_sec_struct_tree_8_cores',
                    ),
                },
                %decision_analysis_params,
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

        {   -logic_name    => 'pre_sec_struct_tree_1_core', ## pre_sec_struct_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels',  ## PrepareRAxMLSecModels -- rename
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'raxml_number_of_cores' => 1,
                            'more_cores_branch'     => 3,
                            'cmd_max_runtime'       => '43200',
                            },
             -flow_into => {
                           -1 => [ 'pre_sec_struct_tree_2_cores' ], # This analysis also has more memory
                            2 => [ 'secondary_structure_decision' ],
                            3 => [ 'pre_sec_struct_tree_2_cores' ], #After trying to restart RAxML we should escalate the capacity.
                           },
        },

        {   -logic_name    => 'pre_sec_struct_tree_2_cores', ## pre_sec_struct_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels',  ## PrepareRAxMLSecModels -- rename
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'raxml_number_of_cores' => 2,
                            'more_cores_branch'     => 3,
                            'cmd_max_runtime'       => '86400',
                           },
            -flow_into => {
                           -1 => [ 'pre_sec_struct_tree_4_cores' ], # This analysis also has more memory
                            2 => [ 'secondary_structure_decision' ],
                            3 => [ 'pre_sec_struct_tree_4_cores' ],
                          },
            -rc_name => '500Mb_2c_job',
        },

        {   -logic_name    => 'pre_sec_struct_tree_4_cores', ## pre_sec_struct_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels',  ## PrepareRAxMLSecModels -- rename
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'raxml_number_of_cores' => 4,
                            'more_cores_branch'     => 3,
                            'cmd_max_runtime'       => '86400',
                           },
            -flow_into => {
                           -1 => [ 'pre_sec_struct_tree_8_cores' ], # This analysis also has more memory
                            2 => [ 'secondary_structure_decision' ],
                            3 => [ 'pre_sec_struct_tree_8_cores' ],
                           },
            -rc_name => '1Gb_4c_job',
        },

        {   -logic_name    => 'pre_sec_struct_tree_8_cores', ## pre_sec_struct_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels',  ## PrepareRAxMLSecModels -- rename
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'raxml_number_of_cores' => 8,
                           },
            -flow_into => {
                            2 => [ 'secondary_structure_decision' ],
                          },
            -rc_name => '2Gb_8c_job',
        },

            {   -logic_name => 'secondary_structure_decision',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -parameters => {
                    %raxml_decision_params,
                },
                -flow_into => {
                    1 => WHEN(
                        # Tested in e99. Using more than 2 cores slows
                        # down RAxML by a factor 10
                        '#raxml_cores# <= 1'    => 'sec_struct_model_tree_1_core',
                        ELSE                       'sec_struct_model_tree_2_cores',
                    ),
                },
                %decision_analysis_params,
            },

        {   -logic_name    => 'sec_struct_model_tree_1_core', ## sec_struct_model_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree', ## SecStrucModels
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'raxml_number_of_cores' => 1,
                            'more_cores_branch'     => 3,
                            'cmd_max_runtime'       => '43200',
                           },
            -flow_into => {
                           -1 => [ 'sec_struct_model_tree_2_cores' ],   # This analysis has more cores *and* more memory
                            3 => [ 'sec_struct_model_tree_2_cores' ],
                          },
        },

        {   -logic_name    => 'sec_struct_model_tree_2_cores', ## sec_struct_model_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree', ## SecStrucModels
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'raxml_number_of_cores' => 2,
                            'more_cores_branch'     => 3,
                            'cmd_max_runtime'       => '86400',
                           },
            -flow_into => {
                           -1 => [ 'sec_struct_model_tree_4_cores' ],   # This analysis has more cores *and* more memory
                            3 => [ 'sec_struct_model_tree_4_cores' ],
                       },
            -rc_name => '500Mb_2c_job',
        },

        {   -logic_name    => 'sec_struct_model_tree_4_cores', ## sec_struct_model_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree', ## SecStrucModels
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'raxml_number_of_cores' => 4,
                            'more_cores_branch'     => 3,
                            'cmd_max_runtime'       => '86400',
                           },
            -flow_into => {
                           -1 => [ 'sec_struct_model_tree_8_cores' ],   # This analysis has more cores *and* more memory
                            3 => [ 'sec_struct_model_tree_8_cores' ],
                       },
            -rc_name => '1Gb_4c_job',
        },

        {   -logic_name    => 'sec_struct_model_tree_8_cores', ## sec_struct_model_tree
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree', ## SecStrucModels
            -analysis_capacity => $self->o('raxml_capacity'),
            -parameters => {
                            %raxml_parameters,
                            'cmd_max_runtime'       => '86400',
                            'raxml_number_of_cores' => 8,
                           },
            -rc_name => '2Gb_8c_job',
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
                            'genome_dumps_dir'      => $self->o('genome_dumps_dir'),
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
             -rc_name => '8Gb_4c_mpi',
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
             -rc_name => '16Gb_4c_mpi',
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
             -rc_name => '32Gb_4c_mpi',
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
                            'genome_dumps_dir' => $self->o('genome_dumps_dir'),
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
                            'genome_dumps_dir' => $self->o('genome_dumps_dir'),
                            'inhugemem' => 1,
                           },
         -rc_name => '32Gb_8c_job',
         -flow_into => {
                        3 => [ 'fast_trees_himem' ],
                        2 => [ 'genomic_tree_himem' ],
                        -1 => [ 'genomic_alignment_mammoth' ],
                       },
        },
        {   -logic_name        => 'genomic_alignment_mammoth',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment',
            -parameters        => {
                %raxml_parameters,
                'raxml_number_of_cores' => 8,
                'mafft_exe'             => $self->o('mafft_exe'),
                'prank_exe'             => $self->o('prank_exe'),
                'genome_dumps_dir'      => $self->o('genome_dumps_dir'),
                'inhugemem'             => 1,
            },
            -analysis_capacity => $self->o('genomic_alignment_capacity'),
            -rc_name           => '96Gb_8c_job',
            -flow_into         => {
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
                'tag_split_genes'     => 0,
                'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
            },
            -rc_name    => '1Gb_job',
            -flow_into  => {
                -1 => [ 'orthotree_himem' ],
            },
        },

        {   -logic_name    => 'orthotree_himem',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -analysis_capacity => $self->o('orthotree_capacity'),
            -parameters => {
                'tag_split_genes'     => 0,
                'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
            },
            -rc_name    => '4Gb_job',
        },

        {   -logic_name    => 'ktreedist',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist',
            -parameters => {
                            'treebest_exe'  => $self->o('treebest_exe'),
                            'ktreedist_exe' => $self->o('ktreedist_exe'),
                           },
            -rc_name => '2Gb_job',
        },

        {   -logic_name     => 'consensus_cigar_line_prep',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnConsensusCigarLine',
            -rc_name        => '4Gb_job',
            -batch_size     => 20,
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
                1 => [ 'set_default_values' ],
                2 => [ 'orthology_stats',   ],
                3 => [ 'paralogy_stats',    ],
            },
        },

        {   -logic_name => 'orthology_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthologyStats',
            -parameters => {
                'hashed_mlss_id'    => '#expr(dir_revhash(#mlss_id#))expr#',
                'homology_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
            },
            -rc_name       => '500Mb_job',
            -hive_capacity => $self->o('ortho_stats_capacity'),
        },
        
        {   -logic_name => 'paralogy_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats',
            -parameters => {
                'hashed_mlss_id'    => '#expr(dir_revhash(#mlss_id#))expr#',
                'homology_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
            },
            -rc_name       => '500Mb_job',
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
            -parameters => {
                'prev_rel_db'               => '#mapping_db#',
            },
            -hive_capacity => $self->o('homology_id_mapping_capacity'),
            -flow_into => { 1 => { 'homology_id_mapping' => INPUT_PLUS() } },
        },

        {   -logic_name => 'homology_id_mapping',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -parameters => {
                'prev_rel_db'               => '#mapping_db#',
                'hashed_mlss_id'            => '#expr(dir_revhash(#mlss_id#))expr#',
                'homology_flatfile'         => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                'prev_homology_flatfile'    => '#prev_homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homology_id_map.tsv',
            },
            -flow_into  => {
                -1 => [ 'homology_id_mapping_himem' ],
            },
            -hive_capacity => $self->o('homology_id_mapping_capacity'),
        },

        {   -logic_name => 'homology_id_mapping_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -parameters => {
                'prev_rel_db'               => '#mapping_db#',
                'hashed_mlss_id'            => '#expr(dir_revhash(#mlss_id#))expr#',
                'homology_flatfile'         => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                'prev_homology_flatfile'    => '#prev_homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homology_id_map.tsv',
            },
            -rc_name => '1Gb_job',
            -hive_capacity => $self->o('homology_id_mapping_capacity'),
        },

        {   -logic_name => 'rib_fire_homology_dumps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => [ 'homology_dumps_mlss_id_factory', 'gene_dumps_genome_db_factory' ],
                'A->1' => 'rib_fire_homology_processing',
            },
        },

        {   -logic_name => 'rib_fire_homology_processing',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => [ 'rib_fire_orth_wga_and_high_conf', 'rename_labels' ],
        },

        {   -logic_name => 'copy_dumps_to_shared_loc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'         => '/bin/bash -c "mkdir -p #homology_dumps_shared_dir# && rsync -rtO #homology_dumps_dir#/ #homology_dumps_shared_dir#"',
            },
            -rc_name    => '500Mb_job',
        },

        {   -logic_name => 'rib_fire_orth_wga_and_high_conf',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => 'rib_fire_orth_wga',
                'A->1'  => 'rib_fire_high_confidence_orths'
            },
        },

        {   -logic_name => 'rib_fire_orth_wga',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CheckSwitch',
            -parameters => {
                'switch_name' => 'dna_alns_complete',
            },
            -flow_into  => {
                1 => { 'pair_species' => { 'species_set_name' => $self->o('wga_species_set_name') } },
            },
            -max_retry_count => 0,
        },

        {   -logic_name => 'rib_fire_high_confidence_orths',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CheckSwitch',
            -parameters => {
                'switch_name' => 'orth_wga_complete',
            },
            -flow_into  => [ 'mlss_id_for_high_confidence_factory', 'paralogue_for_import_factory' ],
            -max_retry_count => 0,
        },

        {   -logic_name => 'paralogue_for_import_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory',
            -parameters => {
                'methods'   => { 'ENSEMBL_PARALOGUES' => 1 },
            },
            -flow_into  => [ 'import_homology_table' ],
        },

        {   -logic_name => 'gene_dumps_genome_db_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -rc_name    => '4Gb_job',
            -flow_into => {
                2 => [ 'dump_genes' ],
            },
        },

        {   -logic_name     => 'dump_genes',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters     => {
                'output_file'   => '#gene_dumps_dir#/gene_member.#genome_db_id#.tsv',
                'append'        => ['--batch', '--quick'],
                'input_query'   => 'SELECT stable_id, gene_member_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand FROM gene_member WHERE genome_db_id = #genome_db_id# ORDER BY dnafrag_id, dnafrag_start',
            },
        },

        {   -logic_name => 'wga_expected_dumps',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpWGAExpectedTags',
            -parameters => {
                'wga_expected_file'  => '#dump_dir#/wga_expected.mlss_tags.tsv',
            },
            -flow_into => {
                1 => { 'datacheck_factory' => { 'datacheck_groups' => $self->o('datacheck_groups'), 'db_type' => $self->o('db_type'), 'compara_db' => $self->pipeline_url(), 'registry_file' => undef }},
            },
        },        

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE::pipeline_analyses_cafe_with_full_species_tree($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats::pipeline_analyses_hom_stats($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpHomologiesForPosttree::pipeline_analyses_split_homologies_posttree($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::OrthologQMAlignment::pipeline_analyses_ortholog_qm_alignment($self)  },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs::pipeline_analyses_high_confidence($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory::pipeline_analyses_datacheck_factory($self) },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    # datacheck specific tweaks for pipelines
    $analyses_by_name->{'datacheck_factory'}->{'-parameters'} = {'dba' => '#compara_db#'};
    $analyses_by_name->{'store_results'}->{'-parameters'} = {'dbname' => '#db_name#'};
}

1;
