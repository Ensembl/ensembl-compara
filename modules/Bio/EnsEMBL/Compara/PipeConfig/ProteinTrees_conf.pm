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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION

The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::GOC;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneSetQC;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpHomologiesForPosttree;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::OrthologQMAlignment;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
        # names of species we don't want to reuse this time
        'do_not_reuse_list'     => [ ],

        # where to find the list of Compara methods. Unlikely to be changed
        'method_link_dump_file' => $self->check_file_in_ensembl('ensembl-compara/sql/method_link.txt'),

        'pipeline_name' => $self->o('collection') . '_' . $self->o('division').'_protein_trees_'.$self->o('rel_with_suffix'),
        'method_type'   => 'PROTEIN_TREES',

    # Parameters to allow merging different runs of the pipeline
        'dbID_range_index'      => undef,
        'collection'            => 'default',
        'species_set_name'      => $self->o('collection'),
        'label_prefix'          => '',
        'member_type'           => 'protein',

    #default parameters for the geneset qc
        'coverage_threshold' => 50, #percent
        'missing_sequence_threshold' => 0.05,
        'species_threshold'  => '#expr(#species_count#/2)expr#', #half of ensembl species

    # data directories:
        'work_dir'              => $self->o('pipeline_dir'),
        'fasta_dir'             => $self->o('work_dir') . '/blast_db',  # affects 'dump_subset_create_blastdb' and 'blastp'
        'cluster_dir'           => $self->o('work_dir') . '/cluster',
        'dump_dir'              => $self->o('work_dir') . '/dumps',
        'gene_dumps_dir'        => $self->o('dump_dir') . '/genes',
        'dump_pafs_dir'         => $self->o('dump_dir') . '/pafs',
        'examl_dir'             => $self->o('work_dir') . '/examl',
        'tmp_dir'               => $self->o('work_dir') . '/tmp',
        'plots_dir'             => $self->o('work_dir') . '/plots', # Directory used to store plots and their input files

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,
        'allow_missing_coordinates' => 0,
        'allow_missing_cds_seqs'    => 0,

    # blast parameters:
        # Amount of sequences to be included in each blast job
        'num_sequences_per_blast_job'   => 500,

        # cdhit is used to filter out proteins that are too close to each other
        'cdhit_identity_threshold'      => 0.99,

        # define blast parameters and evalues for ranges of sequence-length
        # Important note: -max_hsps parameter is only available on ncbi-blast-2.3.0 or higher.
        'all_blast_params'          => [
            [ 0,   35,       '-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix PAM30 -word_size 2',    '1e-4'  ],
            [ 35,  50,       '-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix PAM70 -word_size 2',    '1e-6'  ],
            [ 50,  100,      '-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix BLOSUM80 -word_size 2', '1e-8'  ],
            [ 100, 10000000, '-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix BLOSUM62 -word_size 3', '1e-10' ],  # should really be infinity, but ten million should be big enough
        ],

    # clustering parameters:
        # affects 'hcluster_dump_input_per_genome'
        'outgroups'                     => {},
        # (half of the previously used 'clutering_max_gene_count=1500) affects 'hcluster_run'
        'clustering_max_gene_halfcount' => 750,
        # File with gene / peptide names that must be excluded from the clusters (e.g. know to disturb the trees)
        'gene_blocklist_file'           => '/dev/null',

    # tree building parameters:
        'use_raxml'                 => 0,
        'use_notung'                => 0,
        'use_treerecs'              => 0,
        'do_model_selection'        => 0,
        'use_quick_tree_break'      => 1,

        'treebreak_gene_count'      => 1500,
        'split_genes_gene_count'    => 5000,

        'mcoffee_short_gene_count'  => 20,
        'mcoffee_himem_gene_count'  => 250,
        'mafft_gene_count'          => 300,
        'mafft_himem_gene_count'    => 400,
        'mafft_runtime'             => 7200,
        'raxml_threshold_n_genes' => 500,
        'raxml_threshold_aln_len' => 150,
        'examl_ptiles'            => 16,
        'treebest_threshold_n_residues' => 10000,
        'treebest_threshold_n_genes'    => 400,
        'update_threshold_trees'    => 0.2,

    # sequence type used on the phylogenetic inferences
    # It has to be set to 1 for the strains
        'use_dna_for_phylogeny'     => 0,

    # alignment filtering options
        'threshold_n_genes'       => 20,
        'threshold_aln_len'       => 1000,
        'threshold_n_genes_large' => 2000,
        'threshold_aln_len_large' => 15000,
        'noisy_cutoff'            => 0.4,
        'noisy_cutoff_large'      => 1,

    # species tree reconciliation
        # you can define your own species_tree for 'treebest'. It can contain multifurcations
        'species_tree_input_file'   => undef,
        # When automatically binarizing the tree, should we assume timetree tags to be there ?
        'use_timetree_times'        => 0,
        # you can define your own species_tree for 'notung' or 'CAFE'. It *has* to be binary
        'binary_species_tree_input_file'   => undef,

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'codeml_parameters_file'    => $self->check_file_in_ensembl('ensembl-compara/scripts/pipeline/protein_trees.codeml.ctl.hash'),
        'taxlevels'                 => [],

    # threshold used by per_genome_qc in order to check if the amount of orphan genes are acceptable
    # values were infered by checking previous releases, values that are out of these ranges may be caused by assembly and/or gene annotation problems.
    # SELECT stn1.node_id, stn1.left_index, stn1.right_index, stn1.node_name, stn1.taxon_id, COUNT(*), MIN(ratio), AVG(ratio), MAX(ratio)
    # FROM species_tree_node stn1
    # JOIN (SELECT node_id, root_id, left_index, right_index, taxon_id, genome_db_id, node_name, nb_genes, nb_genes_in_tree/nb_genes AS ratio  FROM species_tree_node JOIN species_tree_node_attr USING (node_id) WHERE genome_db_id IS NOT NULL) stn2
    # ON stn1.root_id = stn2.root_id AND stn1.left_index < stn2.left_index AND stn1.right_index > stn2.right_index
    # WHERE stn1.root_id = 40140000
    # GROUP BY stn1.node_id
    # ORDER BY stn1.left_index;
        'mapped_gene_ratio_per_taxon' => {
            '2759'    => 0.5,     #eukaryotes
          },

    # mapping parameters:
        'do_stable_id_mapping'      => 1,
        'do_treefam_xref'           => 1,
        # The TreeFam release to map to
        'tf_release'                => '9_69',

    # plots
        #compute Jaccard Index and Gini coefficient (Lorenz curve)
        'do_jaccard_index'          => 1,
        'jaccard_index_script'      => $self->check_exe_in_ensembl('ensembl-compara/scripts/homology/plotJaccardIndex.r'),
        'lorentz_curve_script'      => $self->check_exe_in_ensembl('ensembl-compara/scripts/homology/plotLorentzCurve.r'),

    # HMM specific parameters (mostly set in the ENV file)

       # Dumps coming from InterPro
       'panther_annotation_file'    => '/dev/null',
       #'panther_annotation_file' => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/panther_Interpro_annot_v8_1/loose_dummy.txt',

       # A file that holds additional tags we want to add to the HMM clusters (for instance: Best-fit models)
        'extra_model_tags_file'     => undef,

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   3,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 1500,
        'blastpu_capacity'          => 150,
        'mcoffee_short_capacity'    => 600,
        'mafft_capacity'            => 2500,
        'mafft_himem_capacity'      => 1200,
        'split_genes_capacity'      => 600,
        'alignment_filtering_capacity'  => 200,
        'cluster_tagging_capacity'  => 100,
        'prottest_capacity'         => 200,
        'treebest_capacity'         => 400,
        'raxml_capacity'            => 200,
        'examl_capacity'            => 400,
        'copy_tree_capacity'        => 100,
        'notung_capacity'           => 200,
        'ortho_tree_capacity'       => 50,
        'quick_tree_break_capacity' => 1500,
        'build_hmm_capacity'        => 200,
        'ktreedist_capacity'        => 150,
        'goc_capacity'              => 100,
        'goc_stats_capacity'        => 70,
        'genesetQC_capacity'        => 100,
        'other_paralogs_capacity'   => 50,
        'homology_dNdS_capacity'    => 1300,
        'copy_homology_dNdS_capacity'    => 100,
        'homology_dNdS_factory_capacity' =>  10,
        'hc_capacity'               => 150,
        'decision_capacity'         => 150,
        'hc_post_tree_capacity'     => 100,
        'HMMer_classify_capacity'   => 400,
        'loadmembers_capacity'      =>  30,
        'HMMer_classifyPantherScore_capacity'   => 1000,
        'HMMer_search_capacity'     => 8000,
        'copy_trees_capacity'       => 50,
        'copy_alignments_capacity'  => 50,
        'mafft_update_capacity'     => 50,
        'raxml_update_capacity'     => 50,
        'ortho_stats_capacity'      => 10,
        'cafe_capacity'             => 50,

    # hive priority values for some analyses:
        'hc_priority'               => -10,
        'mcoffee_himem_priority'    => 40,
        'mafft_himem_priority'      => 35,
        'mafft_priority'            => 30,
        'mcoffee_priority'          => 20,
        'treebest_long_himem_priority' => 20,

    #default maximum retry count:
        'hive_default_max_retry_count' => 1,

        # parameters for OrthologQMAlignment
        'wga_species_set_name'       => "collection-" . $self->o('collection'),
        'homology_method_link_types' => ['ENSEMBL_ORTHOLOGUES'],
        # WGA dump directories for OrthologQMAlignment
        'wga_dumps_dir'      => $self->o('homology_dumps_dir'),
        # set how many orthologs should be flowed at a time
        'orth_batch_size'   => 10,
        # set to 1 when all pairwise and multiple WGA complete
        'dna_alns_complete' => 0,

        # parameters for HighConfidenceOrthologs
        'threshold_levels'            => [ ],          # division specific
        'high_confidence_capacity'    => 500,          # how many mlss_ids can be processed in parallel
        'import_homologies_capacity'  => 20,           # how many homology mlss_ids can be imported in parallel (via mysqlimport)
        'goc_files_dir'               => $self->o('homology_dumps_dir'),
        'range_label'                 => $self->o('member_type'),

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the dbs required for OrthologQMAlignment alt_aln_dbs can be an array list of alignment dbs
        'alt_aln_dbs'     => [
            'compara_curr',
        ],

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'compara_master',
        'ncbi_db'   => $self->o('master_db'),

        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        'prev_rel_db' => 'compara_prev',
        # By default, the stable ID mapping is done on the previous release database
        'mapping_db'  => $self->o('prev_rel_db'),

        # Where the members come from (as loaded by the LoadMembers pipeline)
        'member_db'   => 'compara_members',

    # Configuration of the pipeline worklow

        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   'ortholog' means that the pipeline will use previously inferred orthologs to perform a cluster projection
        #   'hmm' means that the pipeline will run an HMM classification
        #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
        #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<
        'clustering_mode'           => 'hybrid',

        # List of species some genes have been projected from
        'projection_source_species_names' => [],

        # How much the pipeline will try to reuse from "prev_rel_db"
        # Possible values: 'clusters' (default), 'members'
        #   'members' means that only the members are copied over, and the rest will be re-computed
        #   'hmms' is like 'members', but also copies the HMM profiles. It requires that the clustering mode is not 'blastp'  >> UNIMPLEMENTED <<
        #   'hmm_hits' is like 'hmms', but also copies the HMM hits  >> UNIMPLEMENTED <<
        #   'blastp' is like 'members', but also copies the blastp hits. It requires that the clustering mode is 'blastp'  >> UNIMPLEMENTED <<
        #   'ortholog' the orthologs will be copied from the reuse db  >> UNIMPLEMENTED <<
        #   'clusters' is like 'hmm_hits' or 'blastp' (depending on the clustering mode), but also copies the clusters
        #   'alignments' is like 'clusters', but also copies the alignments  >> UNIMPLEMENTED <<
        #   'trees' is like 'alignments', but also copies the trees  >> UNIMPLEMENTED <<
        #   'homologies is like 'trees', but also copies the homologies  >> UNIMPLEMENTED <<
        'reuse_level'               => 'members',

    # CAFE parameters
        'cafe_lambdas'             => '',  # For now, we don't supply lambdas
        'cafe_struct_tree_str'     => '',  # Not set by default
        'full_species_tree_label'  => 'default',
        'per_family_table'         => 1,
        'cafe_species'             => [],
        #Use Timetree divergence times for the GeneTree internal nodes
        'use_timetree_times'       => 1,

    # GOC parameters
        # Points to the previous protein trees production database. Will be used for various GOC operations.
        'goc_taxlevels'                 => [],

    # HMM specific parameters
        'hmm_library_name'              => '',      # Name of HMMER-3 library. Currently unused
        'hmmer_search_cutoff'           => '1e-23',

    # Extra analyses
        # gain/loss analysis ?
        'do_cafe'                => 1,
        # gene order conservation ?
        'do_goc'                 => 1,
        # orthology wga ?
        'do_orth_wga'            => 1,
        # compute dNdS for homologies?
        'do_dnds'                => 0,
        # Export HMMs ?
        'do_hmm_export'          => 0,
        # Do we want the Gene QC part to run ?
        'do_gene_qc'             => 1,
        # Do we extract overall statistics for each pair of species ?
        'do_homology_stats'      => 1,
        # Do we need a mapping between homology_ids of this database to another database ?
        'do_homology_id_mapping' => 1,

        # homology dumps options
        'orthotree_dir'             => $self->o('dump_dir') . '/orthotree/',
        'homology_dumps_dir'        => $self->o('dump_dir') . '/homology_dumps/',
        'homology_dumps_shared_dir' => $self->o('homology_dumps_shared_basedir') . '/' . $self->o('collection')    . '/' . $self->o('ensembl_release'),

        # Gene tree stats options
        'gene_tree_stats_shared_dir' => $self->o('gene_tree_stats_shared_basedir') . '/' . $self->o('collection') . '/' . $self->o('ensembl_release'),

        # Whole db DC parameters
        'datacheck_groups' => ['compara_gene_tree_pipelines'],
        'db_type'          => ['compara'],
        'output_dir_path'  => $self->o('work_dir') . '/datachecks/',
        'overwrite_files'  => 1,
        'failures_fatal'   => 1, # no DC failure tolerance
        'db_name'          => $self->o('dbowner') . '_' . $self->o('pipeline_name'),
    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},  # inherit the standard resource classes, incl. multi-threaded
    };
}


sub pipeline_checks_pre_init {
    my ($self) = @_;

    # The master db must be defined to allow mapping stable_ids and checking species for reuse
    die "Mapping of stable_id is only possible with a master database" if $self->o('do_stable_id_mapping') and not $self->o('master_db');
    die "Species reuse is only possible with a master database" if $self->o('prev_rel_db') and not $self->o('master_db');

    # Without a master database, we must provide other parameters
    die if not $self->o('master_db') and not $self->o('ncbi_db');

    my %reuse_modes = (clusters => 1, members => 1);
    die "'reuse_level' must be set to one of: ".join(", ", keys %reuse_modes) unless $self->o('reuse_level') and $reuse_modes{$self->o('reuse_level')};
    my %clustering_modes = (blastp => 1, ortholog => 1, hmm => 1, hybrid => 1, topup => 1);
    die "'clustering_mode' must be set to one of: ".join(", ", keys %clustering_modes) unless $self->o('clustering_mode') and $clustering_modes{$self->o('clustering_mode')};

    # In HMM mode the library must exist
    if (($self->o('clustering_mode') ne 'blastp') and ($self->o('clustering_mode') ne 'ortholog')) {
        my $lib = $self->o('hmm_library_basedir');
            if ($self->o('hmm_library_version') == 2){
                die "'$lib' does not seem to be a valid HMM library (Panther-style)\n" unless ((-d $lib) && (-d "$lib/books") && (-d "$lib/globals") && (-s "$lib/globals/con.Fasta"));
            }
            elsif($self->o('hmm_library_version') == 3){
                die "$lib does not seem to be a valid HMM library (Panther-style)\n" unless ((-d $lib) && (-s "$lib/compara_hmm_".$self->o('ensembl_release').".hmm3") && (-s "$lib/compara_hmm_".$self->o('ensembl_release').".hmm3.h3f") && (-s "$lib/compara_hmm_".$self->o('ensembl_release').".hmm3.h3i") && (-s "$lib/compara_hmm_".$self->o('ensembl_release').".hmm3.h3m") && (-s "$lib/compara_hmm_".$self->o('ensembl_release').".hmm3.h3p"));
            }
    }
}


sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'cluster_dir', 'dump_dir', 'gene_dumps_dir', 'dump_pafs_dir', 'examl_dir', 'tmp_dir', 'fasta_dir', 'plots_dir', 'output_dir_path']),
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

        'master_db'     => $self->o('master_db'),
        'ncbi_db'       => $self->o('ncbi_db'),
        'member_db'     => $self->o('member_db'),
        'reuse_db'      => $self->o('prev_rel_db'),
        'mapping_db'    => $self->o('mapping_db'),
        'alt_aln_dbs'   => $self->o('alt_aln_dbs'),
        'db_name'       => $self->o('db_name'),

        'ensembl_release' => $self->o('ensembl_release'),
        'collection'      => $self->o('collection'),  # required for per-MLSS homology merge

        'reg_conf'      => $self->o('reg_conf'),
        'member_type'   => $self->o('member_type'),
        'range_label'   => $self->o('range_label'),

        'pipeline_dir'  => $self->o('pipeline_dir'),
        'cluster_dir'   => $self->o('cluster_dir'),
        'fasta_dir'     => $self->o('fasta_dir'),
        'examl_dir'     => $self->o('examl_dir'),
        'dump_dir'      => $self->o('dump_dir'),
        'plots_dir'     => $self->o('plots_dir'),
        'dump_pafs_dir' => $self->o('dump_pafs_dir'),
        'gene_dumps_dir'        => $self->o('gene_dumps_dir'),
        'hmm_library_basedir'   => $self->o('hmm_library_basedir'),
        'hmm_library_version'   => $self->o('hmm_library_version'),

        'homology_dumps_dir'        => $self->o('homology_dumps_dir'),
        'homology_dumps_shared_dir' => $self->o('homology_dumps_shared_dir'),
        'orthotree_dir'             => $self->o('orthotree_dir'),
        'wga_dumps_dir'             => $self->o('wga_dumps_dir'),
        'gene_tree_stats_shared_dir' => $self->o('gene_tree_stats_shared_dir'),

        'goc_files_dir'      => $self->o('goc_files_dir'),
        'wga_files_dir'      => $self->o('wga_dumps_dir'),
        'hashed_mlss_id'     => '#expr(dir_revhash(#mlss_id#))expr#',
        'goc_file'           => '#goc_files_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.goc.tsv',
        'wga_file'           => '#wga_files_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.wga.tsv',
        'high_conf_file'     => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.high_conf.tsv',

        'output_dir_path'    => $self->o('output_dir_path'),

        'clustering_mode'   => $self->o('clustering_mode'),
        'reuse_level'       => $self->o('reuse_level'),
        'threshold_levels'              => $self->o('threshold_levels'),
        'do_homology_id_mapping'        => $self->o('do_homology_id_mapping'),
        'do_jaccard_index'              => $self->o('do_jaccard_index'),
        'binary_species_tree_input_file'   => $self->o('binary_species_tree_input_file'),
        'all_blast_params'          => $self->o('all_blast_params'),

        'orth_batch_size'             => $self->o('orth_batch_size'),
        'high_confidence_capacity'    => $self->o('high_confidence_capacity'),
        'import_homologies_capacity'  => $self->o('import_homologies_capacity'),

        'use_quick_tree_break'   => $self->o('use_quick_tree_break'),
        'use_notung'   => $self->o('use_notung'),
        'use_treerecs' => $self->o('use_treerecs'),
        'use_raxml'    => $self->o('use_raxml'),
        'do_goc'       => $self->o('do_goc'),
        'do_orth_wga'  => $self->o('do_orth_wga'),
        'do_cafe'      => $self->o('do_cafe'),
        'do_stable_id_mapping'   => $self->o('do_stable_id_mapping'),
        'do_treefam_xref'   => $self->o('do_treefam_xref'),
        'do_homology_stats' => $self->o('do_homology_stats'),
        'do_hmm_export'     => $self->o('do_hmm_export'),
        'do_gene_qc'        => $self->o('do_gene_qc'),
        'dbID_range_index'  => $self->o('dbID_range_index'),
        'dna_alns_complete' => $self->o('dna_alns_complete'), # manually change to 1 when all wgas have finished

        'mapped_gene_ratio_per_taxon' => $self->o('mapped_gene_ratio_per_taxon'),
    };
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my %hc_analysis_params = (
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
    );

    my %semaphore_check_params = (
        'compara_db' => $self->pipeline_url(),
        'datacheck_names' => [ 'TimelySemaphoreRelease' ],
        'db_type' => $self->o('db_type'),
        'registry_file' => undef,
    );

    #-------------------------------------------------------------------------------
    # This boundaries are based on RAxML and ExaML manuals.
    # Which suggest the following number of cores:
    #
    #   ExaML:  DNA: 3.5K patterns/core
    #           AAs: 1K   patterns/core
    #
    #   RAxML:  DNA: 500 patterns/core
    #           AAs: 150 patterns/core
    #
    #-------------------------------------------------------------------------------
    my %raxml_decision_params = (
        # The number of cores is primarily based on the number of "alignment patterns"
        # with an extra boost (a multiplier) based on the number of genes
        'raxml_cores'              => '#expr( #raxml_core_multiplier# * #tree_aln_num_of_patterns# / #raxml_patterns_per_core# )expr#',
        # This means the number of cores will be x2 when we hit 1,000 genes,
        # x3 when we hit 2,000 genes, etc
        'raxml_genes_per_core_mult'=> 1_000,
        'raxml_core_multiplier'    => '#expr( 1 + #tree_gene_count# / #raxml_genes_per_core_mult# )expr#',
        # cf the RAxML manual
        'raxml_patterns_per_core'  => $self->o('use_dna_for_phylogeny') ? '500' : '150',

        'tags'  => {
            #The default value matches the default dataflow we want: _8_cores analysis.
            'aln_num_of_patterns' => 200,
            'gene_count'          => 0,
        },
    );

    my %decision_analysis_params = (
            -analysis_capacity  => $self->o('decision_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
    );
    my %raxml_parsimony_parameters = (
        'raxml_pthread_exe_sse3'    => $self->o('raxml_pthread_exe_sse3'),
        'raxml_pthread_exe_avx'     => $self->o('raxml_pthread_exe_avx'),
        'raxml_exe_sse3'            => $self->o('raxml_exe_sse3'),
        'raxml_exe_avx'             => $self->o('raxml_exe_avx'),
        'treebest_exe'              => $self->o('treebest_exe'),
        'input_clusterset_id'       => 'default',
        'output_clusterset_id'      => 'raxml_parsimony',
    );
    my %examl_parameters = (
        'examl_exe_sse3'        => $self->o('examl_exe_sse3'),
        'examl_exe_avx'         => $self->o('examl_exe_avx'),
        'parse_examl_exe'       => $self->o('parse_examl_exe'),
        'treebest_exe'          => $self->o('treebest_exe'),
        'mpirun_exe'            => $self->o('mpirun_exe'),
        'use_dna_for_phylogeny' => $self->o('use_dna_for_phylogeny'),
        'output_clusterset_id'  => $self->o('use_notung') ? 'raxml' : 'default',
        'input_clusterset_id'   => 'raxml_parsimony',
    );
    my %raxml_parameters = (
        'raxml_pthread_exe_sse3'    => $self->o('raxml_pthread_exe_sse3'),
        'raxml_pthread_exe_avx'     => $self->o('raxml_pthread_exe_avx'),
        'raxml_exe_sse3'            => $self->o('raxml_exe_sse3'),
        'raxml_exe_avx'             => $self->o('raxml_exe_avx'),
        'treebest_exe'              => $self->o('treebest_exe'),
        'output_clusterset_id'      => $self->o('use_notung') ? 'raxml' : 'default',
        'input_clusterset_id'       => 'raxml_parsimony',
    );
    my %raxml_update_parameters = (
        'raxml_pthread_exe_sse3'    => $self->o('raxml_pthread_exe_sse3'),
        'raxml_pthread_exe_avx'     => $self->o('raxml_pthread_exe_avx'),
        'raxml_exe_sse3'            => $self->o('raxml_exe_sse3'),
        'raxml_exe_avx'             => $self->o('raxml_exe_avx'),
        'treebest_exe'              => $self->o('treebest_exe'),
		'input_clusterset_id'	    => 'copy',
        'output_clusterset_id'      => 'raxml_update',
    );

    my %raxml_bl_parameters = (
        'raxml_pthread_exe_sse3'    => $self->o('raxml_pthread_exe_sse3'),
        'raxml_pthread_exe_avx'     => $self->o('raxml_pthread_exe_avx'),
        'raxml_exe_sse3'            => $self->o('raxml_exe_sse3'),
        'raxml_exe_avx'             => $self->o('raxml_exe_avx'),
        'treebest_exe'              => $self->o('treebest_exe'),
        'input_clusterset_id'       => 'notung',
        'output_clusterset_id'      => 'raxml_bl',
    );

    my %notung_parameters = (
        'notung_jar'                => $self->o('notung_jar'),
        'treebest_exe'              => $self->o('treebest_exe'),
        'java_exe'                  => $self->o('java_exe'),
        'label'                     => 'binary',
        'input_clusterset_id'       => $self->o('use_raxml') ? 'raxml' : 'default',
        'output_clusterset_id'      => 'notung',
    );

    my %blastp_parameters = (
        'blast_bin_dir'             => $self->o('blast_bin_dir'),
        'blast_params'              => "#expr( #all_blast_params#->[#param_index#]->[2])expr#",
        'evalue_limit'              => "#expr( #all_blast_params#->[#param_index#]->[3])expr#",
    );

    return [

# ---------------------------------------------[backbone]--------------------------------------------------------------------------------

        {   -logic_name => 'backbone_fire_db_prepare',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions',
            -input_ids  => [ { } ],
            -flow_into  => {
                '1->A'  => [ 'copy_ncbi_tables_factory' ],
                'A->1'  => [ 'genome_loading_funnel_check' ],
            },
        },

        {   -logic_name => 'genome_loading_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'backbone_fire_clustering' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'backbone_fire_clustering',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'output_file'   => '#dump_dir#/snapshot_1_before_clustering.sql.gz',
            },
            -rc_name       => '1Gb_job',
            -flow_into  => [ { 'pre_clustering_semaphore_check' => \%semaphore_check_params } ],
        },

        {   -logic_name        => 'pre_clustering_semaphore_check',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -max_retry_count   => 0,
            -flow_into         => [ { 'fire_clustering_analyses' => '{}' } ],
        },

        {   -logic_name => 'fire_clustering_analyses',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => WHEN(
                    '#are_all_species_reused# and (#reuse_level# eq "clusters")' => 'copy_clusters',
                    ELSE 'clustering_method_decision',
                ),
                'A->1'  => [ 'clustering_analyses_funnel_check' ],
            },
        },

        {   -logic_name => 'clustering_analyses_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'backbone_fire_tree_building' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'backbone_fire_tree_building',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_2_before_tree_building.sql.gz',
            },
            -flow_into  => [ { 'pre_tree_building_semaphore_check' => \%semaphore_check_params } ],
        },

        {   -logic_name        => 'pre_tree_building_semaphore_check',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -max_retry_count   => 0,
            -flow_into         => [ { 'fire_tree_building_analyses' => '{}' } ],
        },

        {   -logic_name => 'fire_tree_building_analyses',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => [ 'cluster_factory' ],
                'A->1'  => [ 'backbone_fire_homology_dumps' ],
            },
        },

        {   -logic_name => 'backbone_fire_homology_dumps',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ { 'pre_homology_dump_semaphore_check' => \%semaphore_check_params } ],
        },

        {   -logic_name        => 'pre_homology_dump_semaphore_check',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -max_retry_count   => 0,
            -flow_into         => [ { 'fire_homology_dump_analyses' => '{}' } ],
        },

        {   -logic_name => 'fire_homology_dump_analyses',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => [ 'snapshot_posttree', 'homology_dumps_mlss_id_factory', 'gene_dumps_genome_db_factory' ],
                'A->1' => [ 'backbone_fire_posttree' ],
            },
        },

        {   -logic_name => 'backbone_fire_posttree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ { 'posttree_semaphore_check' => \%semaphore_check_params } ],
        },

        {   -logic_name        => 'posttree_semaphore_check',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -max_retry_count   => 0,
            -flow_into         => [ { 'fire_posttree_analyses' => '{}' } ],
        },

        {   -logic_name => 'fire_posttree_analyses',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => [ 'rib_group_1' ],
                'A->1'  => [ 'posttree_funnel_check' ],
            },
        },

        {   -logic_name => 'posttree_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'backbone_pipeline_finished' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'backbone_pipeline_finished',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_4_pipeline_finished.sql.gz',
            },
            -rc_name    => '1Gb_24_hour_job',
            -flow_into  => [ { 'final_semaphore_check' => \%semaphore_check_params } ],
        },

        {   -logic_name        => 'final_semaphore_check',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -max_retry_count   => 0,
            -flow_into         => [ { 'fire_final_analyses' => '{}' } ],
        },

        {   -logic_name => 'fire_final_analyses',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => [
                WHEN( '#gene_tree_stats_shared_dir#' => 'generate_tree_stats_report' ),
                'wga_expected_dumps',
                WHEN( '#homology_dumps_shared_dir#' => 'copy_dumps_to_shared_loc' ),
            ],
        },

# ---------------------------------------------[copy tables from master]-----------------------------------------------------------------

        {   -logic_name => 'copy_ncbi_tables_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name' ],
                'column_names' => [ 'table' ],
            },
            -flow_into => {
                '2->A' => [ 'copy_ncbi_table'  ],
                'A->1' => [ 'copy_ncbi_tables_funnel_check' ],
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

        {   -logic_name => 'copy_ncbi_tables_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'check_member_db_is_same_version' ],
            %hc_analysis_params,
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
            -flow_into      => [ 'load_mlss_id' ],
        },

# ---------------------------------------------[load GenomeDB entries from member_db]---------------------------------------------

        {   -logic_name => 'load_mlss_id',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',
            -parameters => {
                'method_type'      => $self->o('method_type'),
                'species_set_name' => $self->o('species_set_name'),
                'release'          => '#ensembl_release#'
            },
            -flow_into  => [ 'find_prev_homology_dumps' ],
        },

        {   -logic_name => 'find_prev_homology_dumps',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SetPrevHomologyDumpParams',
            -parameters => {
                'homology_dumps_shared_basedir' => $self->o('homology_dumps_shared_basedir'),
                'collection'                    => $self->o('collection'),
                'prev_release'                  => $self->o('prev_release'),
            },

            -flow_into  => [ 'load_genomedb_factory' ],
        },

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => '#master_db#',   # that's where genome_db_ids come from
                # Add the locators coming from member_db
                'extra_parameters'  => [ 'locator' ],
                'genome_db_data_source' => '#member_db#',
            },
            -rc_name => '4Gb_job',
            -flow_into => {
                '2->A' => {
                    'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' },
                },
                'A->1' => [ 'load_genomedb_funnel_check' ],
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -batch_size => 10,
            -hive_capacity => 30,
            -max_retry_count => 2,
        },

        {   -logic_name => 'load_genomedb_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'member_copy_factory' ],
            %hc_analysis_params,
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
                    'load_mlss_id' => INPUT_PLUS( { 'master_db' => '#member_db#', } ),
                }
            },
        },

# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

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

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -parameters => {
                'whole_method_links'        => [ 'PROTEIN_TREES' ],
                'singleton_method_links'    => [ 'ENSEMBL_PARALOGUES', 'ENSEMBL_HOMOEOLOGUES' ],
                'pairwise_method_links'     => [ 'ENSEMBL_ORTHOLOGUES' ],
            },
            -rc_name => '2Gb_job',
            -flow_into => {
                1 => [ 'make_treebest_species_tree', 'hc_members_globally' ],
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


# ---------------------------------------------[load species tree]-------------------------------------------------------------------

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

        {   -logic_name => 'copy_trees_from_previous_release',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyTreesFromDB',
            -parameters => {
                'input_clusterset_id'               => 'default',
                'output_clusterset_id'              => 'copy',
                'branch_for_new_tree'               => '3',
                'branch_for_wiped_out_trees'        => '4',
                'branch_for_update_threshold_trees' => '5',
                'update_threshold_trees'            => $self->o('update_threshold_trees'),
            },
            -flow_into  => {
                 1 => [ 'copy_alignments_from_previous_release' ],
                 3 => [ 'alignment_entry_point' ],
                 4 => [ 'alignment_entry_point' ],
                 5 => [ 'alignment_entry_point' ],
            },
            -hive_capacity        => $self->o('copy_trees_capacity'),
            -rc_name => '8Gb_job',
        },

        {   -logic_name => 'copy_alignments_from_previous_release',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CopyAlignmentsFromDB',
            -parameters => {
                'input_clusterset_id'   => 'default',
            },
            -flow_into  			=> [ 'mafft_update' ],
            -hive_capacity          => $self->o('copy_alignments_capacity'),
            -rc_name => '8Gb_job',
        },
# ---------------------------------------------[reuse members]-----------------------------------------------------------------------

        {   -logic_name => 'member_copy_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'extra_parameters'  => [ 'is_polyploid' ],
                'compara_db'        => '#master_db#',
            },
            -rc_name => '4Gb_job',
            -flow_into => {
                '2->A' => [ 'genome_member_copy' ],
                'A->1' => [ 'member_copy_funnel_check' ],
            },
        },

        {   -logic_name => 'member_copy_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => { 1 => { 'create_mlss_ss' => INPUT_PLUS() } },
            %hc_analysis_params,
        },

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

# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'blastp_controller',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into => {
                '1->A' => [ 'reusedspecies_factory', 'nonreusedspecies_factory' ],
                'A->1' => [ 'hcluster_dump_factory' ],
            },
        },

        {   -logic_name => 'reusedspecies_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'polyploid_genomes' => 0,
                'component_genomes' => '#expr( (#reuse_level# eq "members") ? 0 : 1 )expr#',
                'normal_genomes'    => '#expr( (#reuse_level# eq "members") ? 0 : 1 )expr#',
                'species_set_id'    => '#reuse_ss_id#',
            },
            -flow_into => {
                2 => [ 'paf_table_reuse' ],
            },
        },

        {   -logic_name => 'nonreusedspecies_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'polyploid_genomes' => 0,
                'species_set_id'    => '#expr( (#reuse_level# eq "members") ? undef : #nonreuse_ss_id# )expr#',
            },
            -flow_into => {
                2 => [ 'paf_create_empty_table' ],
            },
        },

        {   -logic_name => 'paf_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#reuse_db#',
                'table'         => 'peptide_align_feature_#genome_db_id#',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                'where'         => 'hgenome_db_id IN (#reuse_ss_csv#)',
            },
            -flow_into  => [ 'members_against_nonreusedspecies_factory' ],
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_name => '1Gb_24_hour_job',
        },

        {   -logic_name => 'paf_create_empty_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  'CREATE TABLE IF NOT EXISTS peptide_align_feature_#genome_db_id# LIKE peptide_align_feature',
                            'ALTER TABLE peptide_align_feature_#genome_db_id# DISABLE KEYS, AUTO_INCREMENT=#genome_db_id#00000000',
                ],
            },
            -flow_into  => [ 'members_against_allspecies_factory' ],
            -analysis_capacity => 1,
        },

#----------------------------------------------[classify canonical members based on HMM searches]-----------------------------------
        {
            -logic_name     => 'load_InterproAnnotation',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters     => {
                'panther_annotation_file'   => $self->o('panther_annotation_file'),
                'sql'                       => "LOAD DATA LOCAL INFILE '#panther_annotation_file#' INTO TABLE panther_annot
                                                FIELDS TERMINATED BY '\\t' LINES TERMINATED BY '\\n'
                                                (upi, ensembl_id, ensembl_div, panther_family_id, start, end, score, evalue)",
            },
            -flow_into      => [ 'HMMer_classifyCurated' ],
        },

        {
            -logic_name     => 'HMMer_classifyCurated',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters     => {
                'sql'   => 'INSERT INTO hmm_annot SELECT seq_member_id, model_id, NULL FROM hmm_curated_annot hca JOIN seq_member sm ON sm.stable_id = hca.seq_member_stable_id',
            },
            -rc_name        => '4Gb_job',
            -flow_into      => [ 'HMMer_classifyInterpro' ],
        },

        {
            -logic_name     => 'HMMer_classifyInterpro',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters     => {
                'sql'   => 'INSERT IGNORE INTO hmm_annot SELECT seq_member_id, panther_family_id, evalue FROM panther_annot pa JOIN seq_member sm ON sm.stable_id = pa.ensembl_id',
            },
            -flow_into      => [ 'HMMer_remove_projection_hits' ],
        },

        {
            -logic_name     => 'HMMer_remove_projection_hits',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters     => {
                'sql'   => 'DELETE hmm_annot FROM hmm_annot JOIN seq_member_projection ON seq_member_id = target_seq_member_id',
            },
            -flow_into      => [ 'HMMer_classify_factory' ],
        },

        {   -logic_name => 'HMMer_classify_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FactoryUnannotatedMembers',
            -rc_name       => '4Gb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A' => WHEN(
                    '#hmm_library_version# == 3'  => 'HMMer_search',
                    '#hmm_library_version# == 2'  => 'HMMer_classifyPantherScore',
                ),
                'A->1' => [ 'HMMer_classify_funnel_check' ],
            },
        },

            {
             -logic_name => 'HMMer_classifyPantherScore',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyPantherScore',
             -parameters => {
                             'blast_bin_dir'       => $self->o('blast_bin_dir'),
                             'pantherScore_path'   => $self->o('pantherScore_path'),
                             'hmmer_path'          => $self->o('hmmer2_home'),
                            },
             -hive_capacity => $self->o('HMMer_classifyPantherScore_capacity'),
             -rc_name => '4Gb_24_hour_job',
             -flow_into => {
                           -1 => [ 'HMMer_classifyPantherScore_himem' ],  # MEMLIMIT
                           },
            },

            {
             -logic_name => 'HMMer_classifyPantherScore_himem',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyPantherScore',
             -parameters => {
                             'blast_bin_dir'       => $self->o('blast_bin_dir'),
                             'pantherScore_path'   => $self->o('pantherScore_path'),
                             'hmmer_path'          => $self->o('hmmer2_home'),
                            },
             -hive_capacity => $self->o('HMMer_classifyPantherScore_capacity'),
             -rc_name => '8Gb_job',
            },

        {
         -logic_name => 'HMMer_search',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMerSearch',
         -parameters => {
                         'hmmer_home'        => $self->o('hmmer3_home'),
                         'library_name'      => $self->o('hmm_library_name'),
                         'library_basedir'   => '#hmm_library_basedir#',
                         'hmmer_cutoff'      => $self->o('hmmer_search_cutoff'),
                        },
         -hive_capacity => $self->o('HMMer_search_capacity'),
         -rc_name => '2Gb_job',
         -flow_into => {
                       -1 => [ 'HMMer_search_himem' ],  # MEMLIMIT
                       },
        },

        {
         -logic_name => 'HMMer_search_himem',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMerSearch',
         -parameters => {
                         'hmmer_home'        => $self->o('hmmer3_home'),
                         'library_name'      => $self->o('hmm_library_name'),
                         'library_basedir'   => '#hmm_library_basedir#',
                         'hmmer_cutoff'      => $self->o('hmmer_search_cutoff'),
                        },
         -hive_capacity => $self->o('HMMer_search_capacity'),
         -rc_name => '4Gb_job',
         -priority=> 20,
         -flow_into => {
                       -1 => [ 'HMMer_search_super_himem' ],  # MEMLIMIT
                       },
        },

        {
         -logic_name => 'HMMer_search_super_himem',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMerSearch',
         -parameters => {
                         'hmmer_home'        => $self->o('hmmer3_home'),
                         'library_name'      => $self->o('hmm_library_name'),
                         'library_basedir'   => '#hmm_library_basedir#',
                         'hmmer_cutoff'      => $self->o('hmmer_search_cutoff'),
                        },
         -hive_capacity => $self->o('HMMer_search_capacity'),
         -rc_name => '64Gb_job',
         -priority=> 25,
        },

        {
         -logic_name => 'HMMer_classify_funnel_check',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
         -flow_into  => [ 'HMM_clusterize' ],
         %hc_analysis_params,
        },

            {
             -logic_name => 'HMM_clusterize',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClusterize',
             -parameters => {
                 'extra_tags_file'  => $self->o('extra_model_tags_file'),
             },
             -rc_name => '8Gb_job',
             -flow_into => {
                    1 => WHEN(
                        '#clustering_mode# eq "hybrid"' => 'dump_unannotated_members',
                    ),
                }
            },

        {
            -logic_name     => 'flag_update_clusters',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::FlagUpdateClusters',
			-parameters     => {
                'update_threshold_trees' => $self->o('update_threshold_trees'),
			},
            -rc_name => '16Gb_job',
        },


# -------------------------------------------------[BuildHMMprofiles pipeline]-------------------------------------------------------

        {   -logic_name => 'dump_unannotated_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpUnannotatedMembersIntoFasta',
            -parameters => {
                'fasta_file'    => '#fasta_dir#/unannotated.fasta',
            },
            -rc_name       => '4Gb_job',
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'make_blastdb_unannotated' ],
        },

        {   -logic_name => 'make_blastdb_unannotated',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'blast_bin_dir' => $self->o('blast_bin_dir'),
                'cmd' => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #fasta_name#.blastdb_log -in #fasta_name#',
            },
            -flow_into  => {
                -1 => [ 'make_blastdb_unannotated_himem' ],
                1 => [ 'unannotated_all_vs_all_factory' ],
            }
        },

        {   -logic_name => 'make_blastdb_unannotated_himem',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'blast_bin_dir' => $self->o('blast_bin_dir'),
                'cmd' => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #fasta_name#.blastdb_log -in #fasta_name#',
            },
            -flow_into  => [ 'unannotated_all_vs_all_factory' ],
        },

        {   -logic_name => 'unannotated_all_vs_all_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastFactoryUnannotatedMembers',
            -parameters => {
                'step'              => $self->o('num_sequences_per_blast_job'),
            },
            -rc_name       => '8Gb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A' => [ 'blastp_unannotated' ],
                'A->1' => [ 'blastp_unannotated_funnel_check' ]
            },
        },

        {   -logic_name         => 'blastp_unannotated',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastpUnannotated',
            -parameters         => {
                'blast_db'                  => '#fasta_dir#/unannotated.fasta',
                %blastp_parameters,
            },
            -rc_name       => '1Gb_6_hour_job',
            -flow_into => {
               -1 => [ 'blastp_unannotated_himem' ],  # MEMLIMIT
               -2 => 'break_batch_unannotated',
            },
            -hive_capacity => $self->o('blastpu_capacity'),
        },

        {   -logic_name         => 'blastp_unannotated_himem',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastpUnannotated',
            -parameters         => {
                'blast_db'                  => '#fasta_dir#/unannotated.fasta',
                %blastp_parameters,
            },
            -rc_name       => '2Gb_6_hour_job',
            -flow_into => {
               -2 => 'break_batch_unannotated',
            },
            -priority      => 20,
            -hive_capacity => $self->o('blastpu_capacity'),
        },

        {   -logic_name         => 'blastp_unannotated_no_runlimit',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastpUnannotated',
            -parameters         => {
                'blast_db'                  => '#fasta_dir#/unannotated.fasta',
                %blastp_parameters,
            },
            -rc_name   => '1Gb_24_hour_job',
            -flow_into => {
               -1 => [ 'blastp_unannotated_himem_no_runlimit' ],  # MEMLIMIT
            },
            -hive_capacity => $self->o('blastpu_capacity'),
        },

        {   -logic_name         => 'blastp_unannotated_himem_no_runlimit',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastpUnannotated',
            -parameters         => {
                'blast_db'                  => '#fasta_dir#/unannotated.fasta',
                %blastp_parameters,
            },
            -rc_name       => '2Gb_job',
            -priority      => 20,
            -hive_capacity => $self->o('blastpu_capacity'),
        },


        {   -logic_name    => 'break_batch_unannotated',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BreakUnannotatedBlast',
            -flow_into  => {
                2 => 'blastp_unannotated_no_runlimit',
            }
        },

        {   -logic_name => 'blastp_unannotated_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => { 1 => { 'hcluster_dump_input_all_pafs' => INPUT_PLUS() } },
            %hc_analysis_params,
        },

        {   -logic_name => 'hcluster_dump_input_all_pafs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepareSingleTable',
            -parameters => {
                'outgroups'     => $self->o('outgroups'),
            },
            -rc_name       => '4Gb_job',
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into  => [ 'hcluster_run', 'backup_single_paf' ],
        },

        {   -logic_name => 'backup_single_paf',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature',
                'output_file'   => '#dump_pafs_dir#/peptide_align_feature.sql.gz',
                'exclude_ehive' => 1,
            },
            -analysis_capacity => $self->o('reuse_capacity'),
        },

# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'prepare_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into => {
                '1->A' => [ 'blastdb_factory' ],
                'A->1' => [ 'blastp_controller' ],
            },
        },

        {   -logic_name => 'blastdb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'polyploid_genomes' => 0,
                'arrayref_branch' => 1,
            },
            -flow_into  => {
                '2->A'  => [ 'dump_canonical_members' ],
                'A->1'  => [ 'cdhit'  ],
            },
        },

        {   -logic_name => 'dump_canonical_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta',   # Gets fasta_dir from pipeline_wide_parameters
            -hive_capacity => $self->o('reuse_capacity'),
            #-flow_into => [ 'cdhit' ],
        },

        {   -logic_name => 'cdhit',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CDHit',
            -parameters => {
                'cdhit_exe' => $self->o('cdhit_exe'),
                'cdhit_identity_threshold' => $self->o('cdhit_identity_threshold'),
                'cdhit_num_threads' => 4,
                'cdhit_memory_in_mb' => 8000,
            },
            -flow_into     => {
                2 => [ 'dump_representative_members' ],
                3 => [ '?table_name=seq_member_projection' ],
            },
            -rc_name       => '8Gb_4c_job',
            -hive_capacity => $self->o('reuse_capacity'),
        },

        {   -logic_name => 'dump_representative_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta',
            -parameters => {
                'only_canonical' => 0,
                'only_representative' => 1,
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'make_blastdb' ],
        },

        {   -logic_name => 'make_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'blast_bin_dir' => $self->o('blast_bin_dir'),
                'cmd' => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #fasta_name#.blastdb_log -in #fasta_name#',
            },
            -hive_capacity => $self->o('reuse_capacity'),
        },

        {   -logic_name => 'members_against_allspecies_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory',
            -parameters => {
                'step' => $self->o('num_sequences_per_blast_job'),
            },
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A' => { 'blastp' => INPUT_PLUS() },
                'A->1' => [ 'hc_pafs' ],
            },
        },

        {   -logic_name => 'members_against_nonreusedspecies_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory',
            -parameters => {
                'species_set_id'    => '#nonreuse_ss_id#',
                'step'              => $self->o('num_sequences_per_blast_job'),
            },
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A' => { 'blastp' => INPUT_PLUS() },
                'A->1' => [ 'hc_pafs' ],
            },
        },

        {   -logic_name         => 'blastp',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse',
            -parameters         => {
                'allow_same_species_hits'   => 1,
                %blastp_parameters,
            },
            -batch_size    => 25,
            -rc_name       => '1Gb_6_hour_job',
            -flow_into => {
               -1 => [ 'blastp_himem' ],  # MEMLIMIT
               -2 => [ 'break_batch' ],   # RUNLIMIT
            },
            -hive_capacity => $self->o('blastp_capacity'),
        },

        {   -logic_name         => 'blastp_himem',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse',
            -parameters         => {
                'allow_same_species_hits'   => 1,
                %blastp_parameters,
            },
            -batch_size    => 25,
            -hive_capacity => $self->o('blastp_capacity'),
        },

        {   -logic_name    => 'break_batch',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BreakUnannotatedBlast',
            -flow_into  => {
                2 => 'blastp_no_runlimit',
            }
        },

        {   -logic_name         => 'blastp_no_runlimit',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse',
            -parameters         => {
                'allow_same_species_hits'   => 1,
                %blastp_parameters,
            },
            -flow_into => {
               -1 => [ 'blastp_himem' ],  # MEMLIMIT
            },
            -hive_capacity => $self->o('blastp_capacity'),
        },

        {   -logic_name         => 'hc_pafs',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'peptide_align_features',
            },
            -flow_into => 'backup_paf',
            %hc_analysis_params,
        },

        {   -logic_name => 'backup_paf',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature_#genome_db_id#',
                'output_file'   => '#dump_pafs_dir#/peptide_align_feature_#genome_db_id#.sql.gz',
                'exclude_ehive' => 1,
            },
            -analysis_capacity => $self->o('reuse_capacity'),
        },

# ---------------------------------------------[clustering step]---------------------------------------------------------------------

        {   -logic_name => 'clustering_method_decision',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into => {
                '1->A' => WHEN(
                    '#clustering_mode# eq "blastp"'     => 'prepare_blastdb',
                    '#clustering_mode# eq "ortholog"'   => 'ortholog_cluster',
                    ELSE                                   'load_InterproAnnotation',   # hmm, hybrid, topup
                ),
                'A->1' => [ 'clustering_funnel_check' ],
            },
        },

        {   -logic_name => 'hcluster_dump_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'polyploid_genomes' => 0,
            },
            -flow_into  => {
                '2->A' => [ 'hcluster_dump_input_per_genome' ],
                'A->1' => [ 'hcluster_merge_factory' ],
            },
        },

        {   -logic_name => 'ortholog_cluster',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OrthologClusters',
            -parameters => {
                'sort_clusters'         => 1,
            },
            -rc_name    => '4Gb_job',
            -hive_capacity => $self->o('reuse_capacity'),
        },

        {   -logic_name => 'hcluster_dump_input_per_genome',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepare',
            -parameters => {
                'outgroups'     => $self->o('outgroups'),
            },
            -hive_capacity => $self->o('reuse_capacity'),
        },

        {   -logic_name    => 'hcluster_merge_factory',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ ['txt'], ['cat'], ],
                'column_names' => [ 'ext' ],
            },
            -flow_into => {
                '2->A' => [ 'hcluster_merge_inputs' ],
                'A->1' => [ 'hcluster_run' ],
            },
        },

        {   -logic_name    => 'hcluster_merge_inputs',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'cmd'           => 'cat #cluster_dir#/*.hcluster.#ext# > #cluster_dir#/hcluster.#ext#',
            },
        },

        {   -logic_name    => 'hcluster_run',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'clustering_max_gene_halfcount' => $self->o('clustering_max_gene_halfcount'),
                'hcluster_exe'                  => $self->o('hcluster_exe'),
                'cmd'                           => '#hcluster_exe# -m #clustering_max_gene_halfcount# -w 0 -s 0.34 -O -C #cluster_dir#/hcluster.cat -o #cluster_dir#/hcluster.out #cluster_dir#/hcluster.txt; sleep 30',
            },
            -flow_into => {
                1 => [ 'hcluster_parse_output' ],
            },
            -rc_name => '32Gb_24_hour_job',
        },

        {   -logic_name => 'hcluster_parse_output',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput',
            -rc_name => '4Gb_job',
        },

        {   -logic_name     => 'cluster_tagging',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ClusterTagging',
            -hive_capacity  => $self->o('cluster_tagging_capacity'),
            -rc_name        => '4Gb_job',
            -batch_size     => 50,
        },

        {   -logic_name => 'copy_clusters',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyClusters',
            -parameters => {
                'tags_to_copy'              => [ 'division' ],
            },
            -flow_into  => [ 'remove_blocklisted_genes' ],
            -rc_name => '4Gb_job',
        },

        {   -logic_name => 'clustering_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'expand_clusters_with_projections' ],
            %hc_analysis_params,
        },

        {   -logic_name         => 'expand_clusters_with_projections',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExpandClustersWithProjections',
            -flow_into          => [ 'remove_blocklisted_genes' ],
        },

        {   -logic_name         => 'remove_blocklisted_genes',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveBlocklistedGenes',
            -parameters         => {
                'blocklist_file' => $self->o('gene_blocklist_file'),
            },
            -flow_into          => [ 'hc_clusters' ],
        },

        {   -logic_name         => 'hc_clusters',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -flow_into          => [ 'run_qc_tests' ],
            %hc_analysis_params,
        },

        {   -logic_name         => 'create_additional_clustersets',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets',
            -parameters         => {
                'additional_clustersets'    => [qw(treebest phyml-aa phyml-nt nj-dn nj-ds nj-mm raxml raxml_parsimony raxml_bl notung treerecs copy raxml_update )],
            },
        },


# ---------------------------------------------[Pluggable QC step]----------------------------------------------------------

        {   -logic_name => 'run_qc_tests',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'polyploid_genomes' => 0,
            },
            -flow_into => {
                '2->A' => [ 'per_genome_qc' ],
                '1->A' => [ 'overall_qc' ],
                'A->1' => [ 'cluster_qc_funnel_check' ],
            },
        },

        {   -logic_name => 'overall_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OverallGroupsetQC',
            -parameters => {
                'reuse_db' => '#mapping_db#',
            },
            -hive_capacity  => $self->o('reuse_capacity'),
            -rc_name    => '4Gb_job',
        },

        {   -logic_name => 'per_genome_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PerGenomeGroupsetQC',
            -parameters => {
                'reuse_db'  => '#mapping_db#',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_name    => '4Gb_job',
        },

        {   -logic_name => 'cluster_qc_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'clusterset_backup' ],
            %hc_analysis_params,
        },

        {   -logic_name    => 'clusterset_backup',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => 'INSERT IGNORE INTO gene_tree_backup (seq_member_id, root_id) SELECT seq_member_id, root_id FROM gene_tree_node WHERE seq_member_id IS NOT NULL',
            },
            -flow_into     => {
                1 => [
                    'create_additional_clustersets',
                    'cluster_tagging_factory',
                    WHEN(
                        '#clustering_mode# eq "topup"' => 'flag_update_clusters',
                    ),
                ],
            },
        },

        {   -logic_name => 'cluster_tagging_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id="default"',
            },
            -flow_into  => {
                2 => 'cluster_tagging',
            },
            -rc_name    => '1Gb_job',
        },


# ---------------------------------------------[main tree fan]-------------------------------------------------------------

        {   -logic_name => 'cluster_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id, COUNT(seq_member_id) AS tree_num_genes FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "tree" AND clusterset_id="default" GROUP BY root_id',
            },
            -flow_into  => {
                '2->A'  => WHEN(
                    '#clustering_mode# eq "topup"' => 'copy_trees_from_previous_release',
                    ELSE 'alignment_entry_point',
                ),
                '1->A' => [ 'join_panther_subfam' ],
                'A->1' => [ 'global_tree_processing' ],
            },
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'alignment_entry_point',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'tags'  => {
                    'gene_count'          => 0,
                    'reuse_aln_runtime'   => 0,
                },

                'mcoffee_short_gene_count'  => $self->o('mcoffee_short_gene_count'),
                'mcoffee_himem_gene_count'  => $self->o('mcoffee_himem_gene_count'),
                'mafft_gene_count'          => $self->o('mafft_gene_count'),
                'mafft_himem_gene_count'    => $self->o('mafft_himem_gene_count'),
                'mafft_runtime'             => $self->o('mafft_runtime'),
            },

            -flow_into  => {
                '1->A' => WHEN (
                    '(#tree_gene_count# <  #mcoffee_short_gene_count#)                                                      and     (#tree_reuse_aln_runtime#/1000 <  #mafft_runtime#)'  => 'mcoffee_short',
                    '(#tree_gene_count# >= #mcoffee_short_gene_count# and #tree_gene_count# < #mcoffee_himem_gene_count#)   and     (#tree_reuse_aln_runtime#/1000 <  #mafft_runtime#)'  => 'mcoffee',
                    '(#tree_gene_count# >= #mcoffee_himem_gene_count# and #tree_gene_count# < #mafft_gene_count#)           and     (#tree_reuse_aln_runtime#/1000 <  #mafft_runtime#)'  => 'mcoffee_himem',
                    '(#tree_gene_count# >= #mafft_gene_count#         and #tree_gene_count# < #mafft_himem_gene_count#)     or      (#tree_reuse_aln_runtime#/1000 >= #mafft_runtime#)'  => 'mafft',
                    '(#tree_gene_count# >= #mafft_himem_gene_count#)                                                        or      (#tree_reuse_aln_runtime#/1000 >= #mafft_runtime#)'  => 'mafft_himem',
                ),
                'A->1' => [ 'alignment_funnel_check' ],
            },
            %decision_analysis_params,
        },

        {   -logic_name => 'alignment_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => WHEN(
                '#is_already_supertree#' => { 'panther_paralogs' => INPUT_PLUS() },
                ELSE { 'exon_boundaries_prep' => INPUT_PLUS() },
            ),
            %hc_analysis_params,
        },

        {   -logic_name => 'global_tree_processing',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => {
                '1->A'  => [ 'hc_global_tree_set', 'hc_supertree_factory' ],
                'A->1'  => [ 'tree_id_mapping' ],
            },
        },

        {   -logic_name => 'tree_id_mapping',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [
                WHEN('#do_stable_id_mapping#' => 'stable_id_mapping'),
                WHEN('#do_treefam_xref#' => 'treefam_xref_idmap'),
            ],
        },

        {   -logic_name => 'hc_supertree_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery' => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "supertree"',
            },
            -flow_into  => {
                2 => 'hc_supertree'
            },
        },

        {   -logic_name => 'hc_supertree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HCOneSupertree',
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_global_tree_set',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -flow_into  => [
                    { 'datacheck_trees' => { 'db_type' => $self->o('db_type'), 'compara_db' => $self->pipeline_url(), 'registry_file' => undef, 'datacheck_names' => ['CheckFlatProteinTrees'] } },
                ],
            %hc_analysis_params,
        },

        {
            -logic_name        => 'datacheck_trees',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -analysis_capacity => 100,
            -max_retry_count   => 0,
            -flow_into         => {
                '-1' => [ 'datacheck_trees_high_mem' ],
            },
        },

        {
            -logic_name        => 'datacheck_trees_high_mem',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -analysis_capacity => 100,
            -max_retry_count   => 0,
            -rc_name           => '8Gb_job',
        },

        {   -logic_name    => 'compute_jaccard_index',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComputeJaccardIndex',
            -parameters => {

                'rscript_exe'    => $self->o('rscript_exe'),
                'renv_dir'       => $self->o('renv_dir'),

                'jaccard_index_script'  => $self->o('jaccard_index_script'),
                'lorentz_curve_script'  => $self->o('lorentz_curve_script'),

                'output_jaccard_file'   => '#plots_dir#/jaccard_index.out',
                'output_jaccard_pdf'    => '#plots_dir#/jaccard_index.pdf',

                'output_gini_file'   => '#plots_dir#/gini_coefficient.out',
                'output_gini_pdf'    => '#plots_dir#/gini_coefficient.pdf',
            },
            -rc_name       => '2Gb_24_hour_job',
        },

# ---------------------------------------------[Pluggable MSA steps]----------------------------------------------------------

        {   -logic_name => 'mcoffee_short',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'cmd_max_runtime'       => '21600',  # 6 hours
                'method'                => 'cmcoffee',
                'mcoffee_exe'           => $self->o('mcoffee_exe'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
                'escape_branch'         => -1,
            },
            -hive_capacity        => $self->o('mcoffee_short_capacity'),
            -batch_size           => 20,
            -rc_name   => '1Gb_6_hour_job',
            -flow_into => {
               -1 => [ 'mcoffee' ],  # MEMLIMIT
               -2 => [ 'mafft' ],
            },
        },

        {   -logic_name => 'mcoffee',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'cmd_max_runtime'       => '43200',     # 12 hours
                'method'                => 'cmcoffee',
                'mcoffee_exe'           => $self->o('mcoffee_exe'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
                'escape_branch'         => -1,
            },
            -rc_name    => '2Gb_24_hour_job',
            -priority   => $self->o('mcoffee_priority'),
            -flow_into => {
               -1 => [ 'mcoffee_himem' ],  # MEMLIMIT
               -2 => [ 'mafft' ],
            },
        },

        {   -logic_name => 'mafft',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_exe'                  => $self->o('mafft_exe'),
                'escape_branch'              => -1,
                'mafft_threads'              => 2,
            },
            -hive_capacity        => $self->o('mafft_capacity'),
            -rc_name    => '2Gb_2c_job',
            -priority   => $self->o('mafft_priority'),
            -flow_into => {
               -1 => [ 'mafft_himem' ],  # MEMLIMIT
            },
        },

        {   -logic_name => 'mafft_update',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MafftUpdate',
            -parameters => {
                'mafft_exe'                  => $self->o('mafft_exe'),
            },
            -hive_capacity        => $self->o('mafft_update_capacity'),
            -rc_name    => '2Gb_job',
            -flow_into      => [ 'raxml_update_decision' ],
        },

        {   -logic_name => 'mcoffee_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'cmd_max_runtime'       => '43200',
                'method'                => 'cmcoffee',
                'mcoffee_exe'           => $self->o('mcoffee_exe'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
                'escape_branch'         => -2,
            },
            -rc_name    => '8Gb_24_hour_job',
            -priority   => $self->o('mcoffee_himem_priority'),
            -flow_into => {
               -1 => [ 'mafft_himem' ],
               -2 => [ 'mafft_himem' ],
            },
        },

        {   -logic_name => 'mafft_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_exe'                  => $self->o('mafft_exe'),
                'mafft_threads'              => 4,
            },
            -hive_capacity        => $self->o('mafft_himem_capacity'),
            -rc_name    => '8Gb_4c_24_hour_job',
            -priority   => $self->o('mafft_himem_priority'),
            -flow_into     => {
                -1 => [ 'mafft_huge' ],
            },

        },

        {   -logic_name => 'mafft_huge',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_exe'                  => $self->o('mafft_exe'),
                'mafft_threads'              => 8,
                'mafft_mode'                 => '--retree 1 --memsavetree --memsave',
                'tmp_dir'                    => $self->o('tmp_dir'),
            },
            -hive_capacity        => $self->o('mafft_himem_capacity'),
            -rc_name    => '16Gb_8c_24_hour_job',
            -priority   => $self->o('mafft_himem_priority'),
            -flow_into  => {
                -1 => [ 'mafft_mammoth' ],
            },
        },

        {   -logic_name    => 'mafft_mammoth',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters    => {
                'mafft_exe'     => $self->o('mafft_exe'),
                'mafft_threads' => 16,
                'mafft_mode'    => '--retree 1 --memsavetree --memsave',
                'tmp_dir'       => $self->o('tmp_dir'),
            },
            -hive_capacity => $self->o('mafft_himem_capacity'),
            -rc_name       => '128Gb_16c_24_hour_job',
            -priority      => $self->o('mafft_himem_priority'),
        },

        {   -logic_name     => 'exon_boundaries_prep',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnExonBoundaries',
            -parameters => {
                'treebreak_gene_count'      => $self->o('treebreak_gene_count'),
            },
            -flow_into      => {
                -1 => 'exon_boundaries_prep_himem',
                1 => WHEN(
                    '#use_quick_tree_break# and (#tree_num_genes# > #treebreak_gene_count#)' => 'quick_tree_break',
                    ELSE 'aln_tagging',
                ),
            },
            -hive_capacity  => $self->o('split_genes_capacity'),
            -batch_size     => 20,
        },

        {   -logic_name     => 'exon_boundaries_prep_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnExonBoundaries',
            -parameters => {
                'treebreak_gene_count'      => $self->o('treebreak_gene_count'),
            },
            -flow_into      => WHEN(
                '#use_quick_tree_break# and (#tree_num_genes# > #treebreak_gene_count#)' => 'quick_tree_break',
                ELSE 'aln_tagging',
            ),
            -rc_name    => '2Gb_job',
            -hive_capacity  => $self->o('split_genes_capacity'),
            -batch_size     => 20,
        },

        {   -logic_name     => 'aln_tagging',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::AlignmentTagging',
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -rc_name        => '2Gb_job',
            -batch_size     => 50,
            -flow_into      => [ 'split_genes' ],
        },

# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

        {   -logic_name     => 'split_genes',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -parameters     => {
                split_genes_gene_count  => $self->o('split_genes_gene_count'),
            },
            -hive_capacity  => $self->o('split_genes_capacity'),
            -batch_size     => 20,
            -flow_into      => {
                '2->A' => 'split_genes_per_species',
                'A->1' => 'split_genes_funnel_check',
                -1  => 'split_genes_himem',
            },
        },

        {   -logic_name     => 'split_genes_per_species',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -hive_capacity  => $self->o('split_genes_capacity'),
        },

        {   -logic_name     => 'split_genes_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -hive_capacity  => $self->o('split_genes_capacity'),
            -rc_name        => '4Gb_job',
            -flow_into      => [ 'tree_building_entry_point' ],
        },

        {   -logic_name => 'split_genes_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => { 1 => { 'tree_building_entry_point' => INPUT_PLUS() } },
            %hc_analysis_params,
        },

        {   -logic_name => 'tree_building_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => WHEN(
                    '#use_raxml#' => 'filter_decision',
                    ELSE 'treebest_decision',
                ),
                'A->1' => [ 'tree_building_funnel_check' ],
            },
            %decision_analysis_params,
        },

        {   -logic_name => 'tree_building_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => WHEN(
                '#use_notung#'      => { 'notung_decision' => INPUT_PLUS() },
                '#use_treerecs#'    => { 'treerecs' => INPUT_PLUS() },
                ELSE { 'hc_post_tree' => INPUT_PLUS() },
            ),
            %hc_analysis_params,
        },


# ---------------------------------------------[alignment filtering]-------------------------------------------------------------

        {   -logic_name => 'filter_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'tags'  => {
                    'gene_count' => 0,
                    'aln_length' => 0,
                },
                'threshold_n_genes'      => $self->o('threshold_n_genes'),
                'threshold_aln_len'      => $self->o('threshold_aln_len'),
                'threshold_n_genes_large'      => $self->o('threshold_n_genes_large'),
                'threshold_aln_len_large'      => $self->o('threshold_aln_len_large'),
            },
            -flow_into  => {
                1 => WHEN(
                     '(#tree_gene_count# <= #threshold_n_genes#) || (#tree_aln_length# <= #threshold_aln_len#)' => 'aln_filtering_tagging',
                     '(#tree_gene_count# >= #threshold_n_genes_large# and #tree_aln_length# > #threshold_aln_len#) || (#tree_aln_length# >= #threshold_aln_len_large# and #tree_gene_count# > #threshold_n_genes#)' => 'noisy_large',
                     #'' => 'trimal', # Not actually used
                     ELSE 'noisy',
                ),
            },
            %decision_analysis_params,
        },

        {   -logic_name     => 'noisy',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Noisy',
            -parameters => {
                'noisy_exe'    => $self->o('noisy_exe'),
                               'noisy_cutoff' => $self->o('noisy_cutoff'),
            },
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -rc_name           => '4Gb_job',
            -batch_size     => 5,
            -flow_into      => [ 'aln_filtering_tagging' ],
        },

        {   -logic_name     => 'noisy_large',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Noisy',
            -parameters => {
                'noisy_exe'    => $self->o('noisy_exe'),
                               'noisy_cutoff'  => $self->o('noisy_cutoff_large'),
            },
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -rc_name           => '16Gb_job',
            -batch_size     => 5,
            -flow_into      => [ 'aln_filtering_tagging' ],
        },


        #{   -logic_name     => 'trimal',
            #-module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::TrimAl',
            #-parameters => {
                #'trimal_exe'    => $self->o('trimal_exe'),
            #},
            #-hive_capacity  => $self->o('alignment_filtering_capacity'),
            #-batch_size     => 5,
            #-flow_into      => [ 'aln_filtering_tagging' ],
        #},

        {   -logic_name     => 'aln_filtering_tagging',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::AlignmentFilteringTagging',
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -rc_name        => '2Gb_job',
            -batch_size     => 50,
            -flow_into      => [ 'get_num_of_patterns' ],
        },

# ---------------------------------------------[small trees decision]-------------------------------------------------------------

        {   -logic_name => 'small_trees_go_to_treebest',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'tags'  => {
                    'aln_num_of_patterns'       => 0,
                    'num_distinct_sequences'    => 0,
                },
            },
            -flow_into  => {
                1 => WHEN (
                    '(#tree_num_distinct_sequences# >=4) && (#tree_aln_num_of_patterns# >= 4) && #do_model_selection#'  => 'prottest_decision',
                    '#tree_num_distinct_sequences# < 4'     => 'treebest_small_families',
                    '#tree_aln_num_of_patterns# < 4'        => 'treebest_small_families',
                    ELSE                                       'raxml_parsimony_decision',
                ),
            },
            %decision_analysis_params,
        },

# ---------------------------------------------[model test]-------------------------------------------------------------
        {   -logic_name => 'prottest_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'tags'  => {
                    #The default value matches the default dataflow we want: _8_cores analysis.
                    'aln_length'          => 200,
                    'gene_count'          => 0,
                },
            },
            %decision_analysis_params,

            -flow_into  => {
                1 => WHEN (
                    '(#tree_aln_length# <= 150) && (#tree_gene_count# <= 500)'                                   => 'prottest',
                    '(#tree_aln_length# <= 150) && (#tree_gene_count# > 500)'                                    => 'prottest',
                    '(#tree_aln_length# > 150) && (#tree_aln_length# <= 1200) && (#tree_gene_count# <= 500)'     => 'prottest_8_cores',
                    '(#tree_aln_length# > 150) && (#tree_aln_length# <= 1200) && (#tree_gene_count# > 500)'      => 'prottest_8_cores',
                    '(#tree_aln_length# > 1200) && (#tree_aln_length# <= 2400) && (#tree_gene_count# <= 500)'    => 'prottest_8_cores',
                    '(#tree_aln_length# > 1200) && (#tree_aln_length# <= 2400) && (#tree_gene_count# > 500)'     => 'prottest_16_cores',
                    '(#tree_aln_length# > 2400) && (#tree_aln_length# <= 8000) && (#tree_gene_count# <= 500)'    => 'prottest_16_cores',
                    '(#tree_aln_length# > 2400) && (#tree_aln_length# <= 8000) && (#tree_gene_count# > 500)'     => 'prottest_16_cores',
                    '(#tree_aln_length# > 8000) && (#tree_aln_length# <= 16000) && (#tree_gene_count# <= 500)'   => 'prottest_32_cores',
                    '(#tree_aln_length# > 8000) && (#tree_aln_length# <= 16000) && (#tree_gene_count# > 500)'    => 'prottest_32_cores',
                    '(#tree_aln_length# > 16000) && (#tree_aln_length# <= 32000) && (#tree_gene_count# <= 500)'  => 'prottest_32_cores',
                    '(#tree_aln_length# > 16000) && (#tree_aln_length# <= 32000) && (#tree_gene_count# > 500)'   => 'raxml_parsimony_decision',
                    '(#tree_aln_length# > 32000)'                                                                => 'raxml_parsimony_decision',
                ),
            },
        },

        {   -logic_name => 'prottest',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ProtTest',
            -parameters => {
                'prottest_jar'          => $self->o('prottest_jar'),
                'java_exe'              => $self->o('java_exe'),
                'prottest_memory'       => 3500,
                'n_cores'               => 1,
            },
            -hive_capacity				=> $self->o('prottest_capacity'),
            -rc_name    				=> '2Gb_job',
            -flow_into  => {
                -1 => [ 'prottest_himem' ],
                1 => [ 'raxml_parsimony_decision' ],
            }
        },

        {   -logic_name => 'prottest_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ProtTest',
            -parameters => {
                'prottest_jar'          => $self->o('prottest_jar'),
                'java_exe'              => $self->o('java_exe'),
                'prottest_memory'       => 7000,
                #'escape_branch'         => -1,      # RAxML will use a default model, anyway
                'n_cores'               => 1,
            },
            -hive_capacity				=> $self->o('prottest_capacity'),
            -rc_name					=> '4Gb_job',
            -flow_into  => {
                #-1 => [ 'raxml_parsimony_decision' ],
                1 => [ 'raxml_parsimony_decision' ],
			}
        },

        {   -logic_name => 'prottest_8_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ProtTest',
            -parameters => {
                'prottest_jar'          => $self->o('prottest_jar'),
                'java_exe'              => $self->o('java_exe'),
                'prottest_memory'       => 3500,
                #'escape_branch'         => -1,
                'n_cores'               => 8,
            },
            -hive_capacity				=> $self->o('prottest_capacity'),
            -rc_name    				=> '8Gb_8c_job',
            -flow_into  => {
                1 => [ 'raxml_parsimony_decision' ],
            }
        },

        {   -logic_name => 'prottest_16_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ProtTest',
            -parameters => {
                'prottest_jar'          => $self->o('prottest_jar'),
                'java_exe'              => $self->o('java_exe'),
                'prottest_memory'       => 3500,
                #'escape_branch'         => -1,
                'n_cores'               => 16,
            },
            -hive_capacity				=> $self->o('prottest_capacity'),
            -rc_name    				=> '16Gb_16c_job',
            -flow_into  => {
                1 => [ 'raxml_parsimony_decision' ],
            }
        },

        {   -logic_name => 'prottest_32_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ProtTest',
            -parameters => {
                'prottest_jar'          => $self->o('prottest_jar'),
                'java_exe'              => $self->o('java_exe'),
                'prottest_memory'       => 3500,
                #'escape_branch'         => -1,
                'n_cores'               => 32,
            },
            -hive_capacity				=> $self->o('prottest_capacity'),
            -rc_name    				=> '16Gb_32c_job',
            -flow_into  => {
                1 => [ 'raxml_parsimony_decision' ],
            }
        },

# ---------------------------------------------[tree building with treebest]-------------------------------------------------------------

        {   -logic_name => 'treebest_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'tags'  => {
                    'aln_num_residues'              => 200,
                    'gene_count'                    => 0,
                },
                'treebest_threshold_n_residues'     => $self->o('treebest_threshold_n_residues'),
                'treebest_threshold_n_genes'        => $self->o('treebest_threshold_n_genes'),
            },
            -flow_into  => {
                1 => WHEN (
                    '(#tree_aln_num_residues# < #treebest_threshold_n_residues#)'   => 'treebest_short',
                    '(#tree_gene_count# >= #treebest_threshold_n_genes#)'           => 'treebest_long_himem',
                    ELSE 'treebest',
                ),

            },
            %decision_analysis_params,
        },

        {   -logic_name => 'treebest_short',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML',
            -parameters => {
                'cdna'                      => 1,
                'store_intermediate_trees'  => 1,
                'store_filtered_align'      => 1,
                'treebest_exe'              => $self->o('treebest_exe'),
            },
            -hive_capacity        => $self->o('treebest_capacity'),
            -batch_size => 10,
            -flow_into  => {
                -1 => 'treebest',
                -2 => 'treebest_long_himem',
            }
        },

        {   -logic_name => 'treebest',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML',
            -parameters => {
                'cdna'                      => 1,
                'store_intermediate_trees'  => 1,
                'store_filtered_align'      => 1,
                'treebest_exe'              => $self->o('treebest_exe'),
            },
            -hive_capacity        => $self->o('treebest_capacity'),
            -rc_name    => '2Gb_24_hour_job',
            -flow_into  => {
                -1 => 'treebest_long_himem',
                -2 => 'treebest_long_himem',
            }
        },
        {   -logic_name => 'treebest_long_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML',
            -parameters => {
                'cdna'                      => 1,
                'store_intermediate_trees'  => 1,
                'store_filtered_align'      => 1,
                'treebest_exe'              => $self->o('treebest_exe'),
            },
            -hive_capacity        => $self->o('treebest_capacity'),
            -priority             => $self->o('treebest_long_himem_priority'),
            -rc_name              => '8Gb_168_hour_job',
        },

# ---------------------------------------------[tree building with raxml]-------------------------------------------------------------

        {   -logic_name => 'get_num_of_patterns',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GetPatterns',
            -parameters => {
                'getPatterns_exe'       => $self->o('getPatterns_exe'),
            },
            -hive_capacity				=> $self->o('prottest_capacity'),
            -batch_size    				=> 100,
            -rc_name    				=> '4Gb_job',
            -flow_into  => {
                -1 => [ 'get_num_of_patterns_himem' ],
                2 => [ 'treebest_small_families' ],
                1 => [ 'small_trees_go_to_treebest' ],
            }
        },

        {   -logic_name => 'get_num_of_patterns_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GetPatterns',
            -parameters => {
                'getPatterns_exe'       => $self->o('getPatterns_exe'),
            },
            -hive_capacity				=> $self->o('prottest_capacity'),
            -batch_size    				=> 100,
            -rc_name    				=> '16Gb_job',
            -flow_into  => {
                1 => [ 'small_trees_go_to_treebest' ],
            }
        },

        {   -logic_name => 'raxml_parsimony_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                %raxml_decision_params,
            },
            %decision_analysis_params,

            -flow_into  => {
                '1->A' => WHEN (
                    '(#raxml_cores# <= 1)'                              => 'raxml_parsimony',
                    '(#raxml_cores# >  1)  && (#raxml_cores# <= 2)'     => 'raxml_parsimony_2_cores',
                    '(#raxml_cores# >  2)  && (#raxml_cores# <= 4)'     => 'raxml_parsimony_4_cores',
                    '(#raxml_cores# >  4)  && (#raxml_cores# <= 8)'     => 'raxml_parsimony_8_cores',
                    '(#raxml_cores# >  8)  && (#raxml_cores# <= 16)'    => 'raxml_parsimony_16_cores',
                    '(#raxml_cores# >  16) && (#raxml_cores# <= 32)'    => 'raxml_parsimony_32_cores',
                    '(#raxml_cores# >  32)'                             => 'raxml_parsimony_48_cores',
                ),
                'A->1' => 'raxml_parsimony_funnel_check',
            },
        },

        {   -logic_name => 'raxml_parsimony',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name        => '1Gb_job',
            -flow_into      => {
                -1 => [ 'raxml_parsimony_himem' ],
            }
        },

        {   -logic_name => 'raxml_parsimony_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name        => '4Gb_job',
        },

        {   -logic_name => 'raxml_parsimony_2_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 2,
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name        => '4Gb_2c_job',
            -flow_into      => {
                -1 => [ 'raxml_parsimony_2_cores_himem' ],
            }
        },

        {   -logic_name => 'raxml_parsimony_2_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 2,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name        => '8Gb_2c_job',
        },

        {   -logic_name => 'raxml_parsimony_4_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 4,
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name        => '8Gb_4c_job',
            -flow_into      => {
                -1 => [ 'raxml_parsimony_4_cores_himem' ],
            }
        },

        {   -logic_name => 'raxml_parsimony_4_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 4,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name        => '16Gb_4c_job',
        },

        {   -logic_name => 'raxml_parsimony_8_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 8,
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name        => '16Gb_8c_job',
            -flow_into      => {
                -1 => [ 'raxml_parsimony_8_cores_himem' ],
            }
        },

        {   -logic_name => 'raxml_parsimony_8_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 8,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '32Gb_8c_job',
        },

        {   -logic_name => 'raxml_parsimony_16_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 16,
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '16Gb_16c_job',
            -flow_into      => {
                -1 => [ 'raxml_parsimony_16_cores_himem' ],
            }
        },

        {   -logic_name => 'raxml_parsimony_16_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 16,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '32Gb_16c_job',
        },

        {   -logic_name => 'raxml_parsimony_32_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 32,
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '16Gb_32c_job',
            -flow_into      => {
                -1 => [ 'raxml_parsimony_32_cores_himem' ],
            }
        },

        {   -logic_name => 'raxml_parsimony_32_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 32,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '32Gb_32c_job',
        },

        {   -logic_name => 'raxml_parsimony_48_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 48,
                'cmd_max_runtime'           => '518400',
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '16Gb_48c_168_hour_job',
            -flow_into      => {
                -1 => [ 'raxml_parsimony_48_cores_himem' ],
                -2 => [ 'fasttree' ],
            }
        },

        {   -logic_name => 'raxml_parsimony_48_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 48,
                'cmd_max_runtime'           => '518400',
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '32Gb_48c_168_hour_job',
            -flow_into      => {
                -2 => [ 'fasttree' ],
            }
        },

        {   -logic_name => 'fasttree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FastTree',
            -parameters => {
                'fasttree_exe'                 => $self->o('fasttree_exe'),
                'treebest_exe'              => $self->o('treebest_exe'),
                'output_clusterset_id'      => $self->o('use_notung') ? 'raxml' : 'default',
                'input_clusterset_id'      => 'default',
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name              => '32Gb_32c_job',
        },

        {   -logic_name => 'raxml_parsimony_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'raxml_decision' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'raxml_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                %raxml_decision_params,
            },
            %decision_analysis_params,

            -flow_into  => {
                1 => WHEN (
                    '(#raxml_cores# <= 1)'                              => 'raxml',
                    '(#raxml_cores# >  1)  && (#raxml_cores# <= 2)'     => 'raxml_2_cores',
                    '(#raxml_cores# >  2)  && (#raxml_cores# <= 4)'     => 'raxml_4_cores',
                    '(#raxml_cores# >  4)  && (#raxml_cores# <= 8)'     => 'raxml_8_cores',
                    '(#raxml_cores# >  8)  && (#raxml_cores# <= 16)'    => 'raxml_16_cores',
                    # examl can handle ~4x more patterns
                    '(#raxml_cores# >  16) && (#raxml_cores# <= 32)'    => 'examl_8_cores',
                    '(#raxml_cores# >  32) && (#raxml_cores# <= 48)'    => 'examl_16_cores',
                    '(#raxml_cores# >  48) && (#raxml_cores# <= 128)'   => 'examl_32_cores',
                    '(#raxml_cores# >  128)'                            => 'examl_48_cores',
                ),
            },
        },

        {   -logic_name => 'examl_8_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '8Gb_8c_168_hour_mpi',
            -flow_into => {
               -1 => [ 'examl_8_cores_himem' ],  # MEMLIMIT
               -2 => [ 'examl_16_cores' ],       # RUNTIME
            }
        },

        {   -logic_name => 'examl_8_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '32Gb_8c_168_hour_mpi',
        },

        {   -logic_name => 'examl_16_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '8Gb_16c_168_hour_mpi',
            -flow_into => {
               -1 => [ 'examl_16_cores_himem' ],  # MEMLIMIT
               -2 => [ 'examl_32_cores' ],  	  # RUNTIME
            }
        },

        {   -logic_name => 'examl_16_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '32Gb_16c_168_hour_mpi',
        },

        {   -logic_name => 'examl_32_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '8Gb_32c_168_hour_mpi',
            -flow_into => {
               -1 => [ 'examl_32_cores_himem' ],  # MEMLIMIT
               -2 => [ 'examl_48_cores' ],  	  # RUNTIME
            }
        },

        {   -logic_name => 'examl_32_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '32Gb_32c_168_hour_mpi',
        },

        {   -logic_name => 'examl_48_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
                'escape_branch'         => -2,
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '8Gb_48c_168_hour_mpi',
            -max_retry_count => 3, #We restart this jobs 3 times then they will run in FastTree. After 18 days (3*518400) of ExaML 48 cores. It will probably not converge.
            -flow_into => {
               -1 => [ 'examl_48_cores_himem' ],  # MEMLIMIT
               -2 => [ 'fasttree' ],  # RUNLIMIT
            }
        },

        {   -logic_name => 'examl_48_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
                'escape_branch'         => -2,
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '32Gb_48c_168_hour_mpi',
            -max_retry_count => 3, #We restart this jobs 3 times then they will run in FastTree. After 18 days (3*518400) of ExaML 48 cores. It will probably not converge.
            -flow_into => {
               -2 => [ 'fasttree' ],  # RUNLIMIT
            }
        },

        {   -logic_name => 'raxml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '1Gb_job',
            -flow_into  => {
                -1 => [ 'raxml_8_cores_himem' ],
                -2 => [ 'raxml_8_cores' ],
            }
        },

        {   -logic_name => 'raxml_update_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'tags'  => {
                    #The default value matches the default dataflow we want: _8_cores analysis.
                    'gene_count'          => 0,
                },
            },
            -flow_into  => {
                1 => WHEN(
                    '(#tree_gene_count# <= 500)'                                => 'raxml_update',
                    '(#tree_gene_count# > 500)  && (#tree_gene_count# <= 1000)' => 'raxml_update_8',
                    '(#tree_gene_count# > 1000) && (#tree_gene_count# <= 2000)' => 'raxml_update_16',
                    '(#tree_gene_count# > 3000)'                                => 'raxml_update_32',
                ),
            },
            %decision_analysis_params,
        },

        {   -logic_name => 'raxml_update',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_update',
            -parameters => {
                %raxml_update_parameters,
            },
            -hive_capacity        => $self->o('raxml_update_capacity'),
            -rc_name    => '8Gb_job',
        },

        {   -logic_name => 'raxml_update_8',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_update',
            -parameters => {
                %raxml_update_parameters,
                'raxml_number_of_cores'     => 8,
            },
            -hive_capacity        => $self->o('raxml_update_capacity'),
            -rc_name 	=> '16Gb_8c_job',
        },

        {   -logic_name => 'raxml_update_16',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_update',
            -parameters => {
                %raxml_update_parameters,
                'raxml_number_of_cores'     => 16,
            },
            -hive_capacity        => $self->o('raxml_update_capacity'),
            -rc_name    => '16Gb_16c_job',
        },

        {   -logic_name => 'raxml_update_32',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_update',
            -parameters => {
                %raxml_update_parameters,
                'raxml_number_of_cores'     => 32,
            },
            -hive_capacity        => $self->o('raxml_update_capacity'),
            -rc_name    => '32Gb_32c_job',
        },

        {   -logic_name => 'treebest_small_families',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML',
            -parameters => {
                'cdna'                      => 1,
                'store_intermediate_trees'  => 1,
                'extra_args'                => ' -F 0 ',
                'treebest_exe'              => $self->o('treebest_exe'),
                'output_clusterset_id'      => $self->o('use_notung') ? 'raxml' : 'default',
            },
            -hive_capacity        => $self->o('treebest_capacity'),
            -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'raxml_2_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
                'raxml_number_of_cores'     => 2,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name 		=> '4Gb_2c_24_hour_job',
            -flow_into  => {
                -1 => [ 'raxml_2_cores_himem' ],
                -2 => [ 'raxml_4_cores' ],
            }
        },

        {   -logic_name => 'raxml_2_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
                'raxml_number_of_cores'     => 2,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name 		=> '8Gb_2c_job',
        },

        {   -logic_name => 'raxml_4_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
                'raxml_number_of_cores'     => 4,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name 		=> '8Gb_4c_24_hour_job',
            -flow_into  => {
                -1 => [ 'raxml_4_cores_himem' ],
                -2 => [ 'raxml_8_cores' ],
            }
        },

        {   -logic_name => 'raxml_4_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
                'raxml_number_of_cores'     => 4,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name 		=> '16Gb_4c_job',
        },

        {   -logic_name => 'raxml_8_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
                'raxml_number_of_cores'     => 8,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '16Gb_8c_168_hour_job',
            -flow_into  => {
                -1 => [ 'raxml_8_cores_himem' ],
                -2 => [ 'examl_16_cores' ],
            }
        },

        {   -logic_name => 'raxml_8_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
                'raxml_number_of_cores'     => 8,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name 		=> '32Gb_8c_job',
        },
        {   -logic_name => 'raxml_16_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
                'raxml_number_of_cores'     => 16,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name 		=> '16Gb_16c_168_hour_job',
            -flow_into  => {
                -1 => [ 'raxml_16_cores_himem' ],
                -2 => [ 'examl_32_cores' ],
            }
        },

        {   -logic_name => 'raxml_16_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
                'raxml_number_of_cores'     => 16,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name 		=> '32Gb_16c_168_hour_job',
        },


# ---------------------------------------------[tree reconciliation / rearrangements]-------------------------------------------------------------

        {   -logic_name => 'treerecs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Treerecs',
            -parameters => {
                'input_clusterset_id'       => 'default',
                'output_clusterset_id'      => 'treerecs',
                'treebest_exe'              => $self->o('treebest_exe'),
                'treerecs_exe'              => $self->o('treerecs_exe'),
            },
            -hive_capacity                  => $self->o('notung_capacity'),
            -batch_size    => 2,
            -rc_name        => '2Gb_job',
            -flow_into      => {
                1  => [ 'copy_treerecs_bl_tree_2_default_tree' ],
            },
        },

        {   -logic_name => 'notung_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'tags'  => {
                    #The default value matches the default dataflow we want: _8_cores analysis.
                    'gene_count'          => 0,
                },
            },
            -flow_into  => {
                1 => WHEN(
                    '(#tree_gene_count# <= 500)'                                    => 'notung',
                    '(#tree_gene_count# > 500)  && (#tree_gene_count# <= 1000)'     => 'notung_8gb',
                    '(#tree_gene_count# > 1000) && (#tree_gene_count# <= 2000)'     => 'notung_16gb',
                    '(#tree_gene_count# > 3000) && (#tree_gene_count# <= 6000)'     => 'notung_32gb',
                    '(#tree_gene_count# > 6000) && (#tree_gene_count# <= 10000)'    => 'notung_64gb',
                    '(#tree_gene_count# > 10000)'                                   => 'notung_512gb',
                ),
            },
            %decision_analysis_params,
        },

        {   -logic_name => 'notung',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Notung',
            -parameters => {
                %notung_parameters,
                'notung_memory'             => 1500,
            },
            -hive_capacity                  => $self->o('notung_capacity'),
            -batch_size    => 2,
            -priority       => 1,
            -rc_name        => '2Gb_job',
            -flow_into      => {
                1  => [ 'raxml_bl_decision' ],
            },
        },

        {   -logic_name => 'notung_8gb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Notung',
            -parameters => {
                %notung_parameters,
                'notung_memory'         => 7000,
            },
            -hive_capacity  => $self->o('notung_capacity'),
            -priority       => 10,
            -rc_name        => '8Gb_job',
            -flow_into      => [ 'raxml_bl_decision' ],
        },

        {   -logic_name => 'notung_16gb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Notung',
            -parameters => {
                %notung_parameters,
                'notung_memory'         => 14000,
            },
            -hive_capacity  => $self->o('notung_capacity'),
            -priority       => 15,
            -rc_name        => '16Gb_job',
            -flow_into      => [ 'raxml_bl_decision' ],
        },

        {   -logic_name => 'notung_32gb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Notung',
            -parameters => {
                %notung_parameters,
                'notung_memory'         => 28000,
            },
            -hive_capacity  => $self->o('notung_capacity'),
            -priority       => 20,
            -rc_name        => '32Gb_job',
            -flow_into      => [ 'raxml_bl_decision' ],
        },

        {   -logic_name => 'notung_64gb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Notung',
            -parameters => {
                %notung_parameters,
                'notung_memory'         => 56000,
            },
            -hive_capacity  => $self->o('notung_capacity'),
            -priority       => 25,
            -rc_name        => '64Gb_job',
            -flow_into      => [ 'raxml_bl_decision' ],
        },

        {   -logic_name => 'notung_512gb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Notung',
            -parameters => {
                %notung_parameters,
                'notung_memory'         => 448000,
            },
            -hive_capacity  => $self->o('notung_capacity'),
            -priority       => 30,
            -rc_name        => '512Gb_job',
            -flow_into      => [ 'raxml_bl_decision' ],
        },

        {   -logic_name => 'raxml_bl_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'tags'  => {
                    #The default value matches the default dataflow we want: _8_cores analysis.
                    'gene_count'          => 0,
                },
            },
            -flow_into  => {
                1 => WHEN(
                    '(#tree_gene_count# <= 500)'                                => 'raxml_bl',
                    '(#tree_gene_count# > 500)  && (#tree_gene_count# <= 1000)' => 'raxml_bl_8',
                    '(#tree_gene_count# > 1000) && (#tree_gene_count# <= 2000)' => 'raxml_bl_16',
                    '(#tree_gene_count# > 3000) && (#tree_gene_count# <= 10000)' => 'raxml_bl_32',
                    '(#tree_gene_count# > 10000)'                                => 'raxml_bl_48',
                ),
            },
            %decision_analysis_params,
        },

        {   -logic_name => 'raxml_bl',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                %raxml_bl_parameters,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '8Gb_job',
            -flow_into  => {
                1  => [ 'copy_raxml_bl_tree_2_default_tree' ],
                2 => [ 'copy_treebest_tree_2_raxml_bl_tree' ],
            }
        },

        {   -logic_name => 'raxml_bl_8',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                %raxml_bl_parameters,
                'raxml_number_of_cores'     => 8,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '16Gb_8c_job',
            -flow_into  => {
                1  => [ 'copy_raxml_bl_tree_2_default_tree' ],
                2 => [ 'copy_treebest_tree_2_raxml_bl_tree' ],
            }
        },

        {   -logic_name => 'raxml_bl_16',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                %raxml_bl_parameters,
                'raxml_number_of_cores'     => 16,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '16Gb_16c_job',
            -flow_into  => {
                1  => [ 'copy_raxml_bl_tree_2_default_tree' ],
                2 => [ 'copy_treebest_tree_2_raxml_bl_tree' ],
            }
        },

        {   -logic_name => 'raxml_bl_32',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                %raxml_bl_parameters,
                'raxml_number_of_cores'     => 32,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '32Gb_32c_job',
            -flow_into  => {
                1  => [ 'copy_raxml_bl_tree_2_default_tree' ],
                2 => [ 'copy_treebest_tree_2_raxml_bl_tree' ],
            }
        },

        {   -logic_name => 'raxml_bl_48',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                %raxml_bl_parameters,
                'raxml_number_of_cores'     => 48,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '256Gb_48c_job',
            -flow_into  => {
                1  => [ 'copy_raxml_bl_tree_2_default_tree' ],
                2 => [ 'copy_treebest_tree_2_raxml_bl_tree' ],
            }
        },

        # At this point, we are currently storing the treebest trees as raxml and raxml_bl.
        # if we need to reduce the storage footprint we may skip this, and copy direct to default.
        {   -logic_name => 'copy_treebest_tree_2_raxml_bl_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyLocalTree',
            -parameters => {
                'treebest_exe'          => $self->o('treebest_exe'),
                'input_clusterset_id'   => 'notung',
                'output_clusterset_id'  => 'raxml_bl',
            },
            -hive_capacity        => $self->o('copy_tree_capacity'),
            -rc_name => '2Gb_job',
            -flow_into  => {
                1  => [ 'copy_raxml_bl_tree_2_default_tree' ],
            }
        },

        {   -logic_name                 => 'copy_raxml_bl_tree_2_default_tree',
            -module                     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyLocalTree',
            -parameters => {
                'treebest_exe'          => $self->o('treebest_exe'),
                'input_clusterset_id'   => 'raxml_bl',
                'output_clusterset_id'  => 'default',
            },
            -hive_capacity              => $self->o('copy_tree_capacity'),
            -rc_name                    => '2Gb_job',
            -flow_into                  => [ 'hc_post_tree' ],
        },

        {   -logic_name                 => 'copy_treerecs_bl_tree_2_default_tree',
            -module                     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyLocalTree',
            -parameters => {
                'treebest_exe'          => $self->o('treebest_exe'),
                'input_clusterset_id'   => 'treerecs',
                'output_clusterset_id'  => 'default',
            },
            -hive_capacity              => $self->o('copy_tree_capacity'),
            -rc_name                    => '2Gb_job',
            -flow_into                  => [ 'hc_post_tree' ],
        },

# ---------------------------------------------[orthologies]-------------------------------------------------------------

        {   -logic_name => 'hc_post_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HCOneTree',
            -flow_into  => [ 'ortho_tree_decision' ],
            -hive_capacity        => $self->o('hc_post_tree_capacity'),
            %hc_analysis_params,
        },

        {   -logic_name => 'ortho_tree_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'tags'  => {
                    #The default value matches the default dataflow we want: ortho_tree analysis.
                    'gene_count'          => 0,
                },
            },
            -flow_into  => {
                1 => WHEN(
                    '(#tree_gene_count# <= 400)' => 'ortho_tree',
                    ELSE 'ortho_tree_himem',
                ),
            },
            %decision_analysis_params,
        },

        {   -logic_name => 'ortho_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'tag_split_genes'     => 1,
                'input_clusterset_id' => $self->o('use_notung') ? 'raxml_bl' : 'default',
                'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
            },
            -hive_capacity  => $self->o('ortho_tree_capacity'),
            -priority       => -10,
            -rc_name        => '1Gb_24_hour_job', 
            -flow_into      => {
                1   => [ 'final_tree_steps' ],
                -1  => 'ortho_tree_himem',
            },
        },

        {   -logic_name => 'ortho_tree_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'tag_split_genes'   => 1,
                'input_clusterset_id'   => $self->o('use_notung') ? 'raxml_bl' : 'default',
                'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
            },
            -hive_capacity  => $self->o('ortho_tree_capacity'),
            -priority       => 20,
            -rc_name        => '4Gb_24_hour_job',
            -flow_into      => [ 'final_tree_steps' ],
        },

        {   -logic_name => 'final_tree_steps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => [ 'ktreedist', 'consensus_cigar_line_prep' ],
        },

        {   -logic_name    => 'ktreedist',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist',
            -parameters    => {
                               'treebest_exe'  => $self->o('treebest_exe'),
                               'ktreedist_exe' => $self->o('ktreedist_exe'),
                              },
            -hive_capacity => $self->o('ktreedist_capacity'),
            -batch_size    => 5,
            -rc_name       => '1Gb_24_hour_job',
            -flow_into     => {
                -1 => [ 'ktreedist_himem' ],
            },
        },

        {   -logic_name    => 'ktreedist_himem',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist',
            -parameters    => {
                               'treebest_exe'  => $self->o('treebest_exe'),
                               'ktreedist_exe' => $self->o('ktreedist_exe'),
                              },
            -hive_capacity => $self->o('ktreedist_capacity'),
            -rc_name       => '4Gb_24_hour_job',
        },

        {   -logic_name     => 'consensus_cigar_line_prep',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnConsensusCigarLine',
            -hive_capacity  => $self->o('ktreedist_capacity'),
            -batch_size     => 20,
            -rc_name        => '1Gb_24_hour_job',
            -flow_into      => {
                -1  => [ 'consensus_cigar_line_prep_himem' ],
            },
        },

        {   -logic_name     => 'consensus_cigar_line_prep_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnConsensusCigarLine',
            -rc_name        => '4Gb_job',
            -hive_capacity  => $self->o('ktreedist_capacity'),
            -batch_size     => 20,
        },

        {   -logic_name => 'build_HMM_aa_v3',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'hmmer_home'        => $self->o('hmmer3_home'),
                'hmmer_version'     => 3,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -batch_size     => 5,
            -flow_into      => {
                -1  => 'build_HMM_aa_v3_himem'
            },
        },

        {   -logic_name     => 'build_HMM_aa_v3_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                'hmmer_home'        => $self->o('hmmer3_home'),
                'hmmer_version'     => 3,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
        },

        {   -logic_name => 'build_HMM_cds_v3',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'cdna'              => 1,
                'hmmer_home'        => $self->o('hmmer3_home'),
                'hmmer_version'     => 3,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -batch_size     => 5,
            -flow_into      => {
                -1  => 'build_HMM_cds_v3_himem'
            },
        },

        {   -logic_name     => 'build_HMM_cds_v3_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                'cdna'              => 1,
                'hmmer_home'        => $self->o('hmmer3_home'),
                'hmmer_version'     => 3,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -rc_name        => '2Gb_job',
        },

# ---------------------------------------------[Quick tree break steps]-----------------------------------------------------------------------

        {   -logic_name => 'quick_tree_break',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak',
            -parameters => {
                'quicktree_exe'         => $self->o('quicktree_exe'),
                'treebest_exe'          => $self->o('treebest_exe'),
                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
            },
            -hive_capacity        => $self->o('quick_tree_break_capacity'),
            -rc_name   => '2Gb_24_hour_job',
            -flow_into => {
                1 => [ 'other_paralogs', 'subcluster_factory' ],
                -1 => 'quick_tree_break_himem',
            },
        },

        {   -logic_name => 'quick_tree_break_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::QuickTreeBreak',
            -parameters => {
                'quicktree_exe'         => $self->o('quicktree_exe'),
                'treebest_exe'          => $self->o('treebest_exe'),
                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
            },
            -hive_capacity        => $self->o('quick_tree_break_capacity'),
            -rc_name   => '8Gb_24_hour_job',
            -flow_into => [ 'other_paralogs_himem', 'subcluster_factory' ],
        },

        {   -logic_name     => 'other_paralogs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
            -parameters     => {
                'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
            },
            -hive_capacity  => $self->o('other_paralogs_capacity'),
            -rc_name        => '1Gb_24_hour_job',
            -flow_into      => {
                -1 => [ 'other_paralogs_himem', ],
                3 => [ 'other_paralogs' ],
            }
        },

        {   -logic_name     => 'other_paralogs_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
            -parameters     => {
                'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
            },
            -hive_capacity  => $self->o('other_paralogs_capacity'),
            -rc_name        => '2Gb_24_hour_job',
            -flow_into      => {
                3 => [ 'other_paralogs_himem' ],
            }
        },

        {   -logic_name     => 'subcluster_factory',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters     => {
                'inputquery'    => 'SELECT gtn1.root_id AS gene_tree_id, gene_count AS tree_gene_count FROM (gene_tree_node gtn1 JOIN gene_tree_root_attr USING (root_id)) JOIN gene_tree_node gtn2 ON gtn1.parent_id = gtn2.node_id WHERE gtn1.root_id != gtn2.root_id AND gtn2.root_id = #gene_tree_id#',
            },
            -hive_capacity  => $self->o('other_paralogs_capacity'),
            -flow_into      => {
                2 => [ 'tree_backup' ],
            }
        },

        {   -logic_name    => 'tree_backup',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => 'INSERT INTO gene_tree_backup (seq_member_id, root_id) SELECT seq_member_id, root_id FROM gene_tree_node WHERE seq_member_id IS NOT NULL AND root_id = #gene_tree_id#',
            },
            -flow_into      => [ 'alignment_entry_point' ],
        },

        {   -logic_name     => 'join_panther_subfam',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::MakePantherSuperTrees',
            -rc_name        => '1Gb_job',
            -flow_into      => {
                2 => 'panther_backup',
            },
        },

        {   -logic_name     => 'panther_backup',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters     => {
                'sql'   => 'INSERT INTO gene_tree_backup (seq_member_id, root_id) SELECT gtn3.seq_member_id, gtn1.root_id FROM gene_tree_node gtn1 JOIN gene_tree_node gtn2 ON gtn1.node_id = gtn2.parent_id JOIN gene_tree_node gtn3 ON gtn2.root_id = gtn3.root_id WHERE gtn3.seq_member_id IS NOT NULL AND gtn1.root_id = #gene_tree_id#',
            },
            -flow_into      => {
                1 => { 'alignment_entry_point' => INPUT_PLUS({ 'is_already_supertree' => 1 }) },
            },
        },

        {   -logic_name     => 'panther_paralogs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PantherParalogs',
            -parameters     => {
                'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
            },
            -hive_capacity  => $self->o('other_paralogs_capacity'),
            -rc_name        => '1Gb_24_hour_job',
            -flow_into      => {
                -1 => [ 'panther_paralogs_himem', ],
                3 => [ 'panther_paralogs' ],
            }
        },

        {   -logic_name     => 'panther_paralogs_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PantherParalogs',
            -parameters     => {
                'hashed_gene_tree_id' => '#expr(dir_revhash(#gene_tree_id#))expr#',
                'output_flatfile'     => '#orthotree_dir#/#hashed_gene_tree_id#/#gene_tree_id#.orthotree.tsv',
            },
            -hive_capacity  => $self->o('other_paralogs_capacity'),
            -rc_name        => '4Gb_24_hour_job',
            -flow_into      => {
                3 => [ 'panther_paralogs_himem' ],
            }
        },


# -------------------------------------------[name mapping step]---------------------------------------------------------------------

        {
            -logic_name => 'stable_id_mapping',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper',
            -parameters => {
                'prev_rel_db'   => '#mapping_db#',
                'type'          => 't',
            },
            -flow_into          => [ 'hc_stable_id_mapping' ],
            -rc_name => '4Gb_job',
        },

        {   -logic_name         => 'hc_stable_id_mapping',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'stable_id_mapping',
            },
            -flow_into  => [
                    WHEN('#do_jaccard_index# && #reuse_db#' => 'compute_jaccard_index'),
                ],
            %hc_analysis_params,
        },

        {   -logic_name    => 'treefam_xref_idmap',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper',
            -parameters    => {
                'tf_release'  => $self->o('tf_release'),
                'tag_prefix'  => '',
            },
            -rc_name => '2Gb_job',
        },

        {   -logic_name => 'build_HMM_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id="default"',
            },
            -flow_into  => {
                # We don't use build_HMM_aa_v2 because hmmcalibrate takes ages
                2 => [ 'build_HMM_aa_v3', 'build_HMM_cds_v3' ],
            },
        },

# ---------------------------------------------[homology step]-----------------------------------------------------------------------

        {   -logic_name => 'rib_group_1',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => [
                    'rib_fire_gene_qc',
                    'rib_fire_homology_id_mapping',
                    'rib_fire_cafe',
                    'rib_fire_orth_wga',
                ],
                'A->1' => 'rib_group_2'
            },
        },

        {   -logic_name => 'rib_group_2',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => {
                '1->A' => [
                    'rib_fire_dnds',
                    'rib_fire_homology_stats',
                    'rib_fire_tree_stats',
                    'rib_fire_hmm_build',
                    'rib_fire_goc'
                ],
                'A->1' => 'rib_group_3',
            },
        },

        {   -logic_name => 'rib_group_3',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => {
                '1->A' => [
                    'rib_fire_high_confidence_orths',
                ],
                'A->1' => 'rib_group_4',
            },
        },

        {   -logic_name => 'rib_group_4',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into     => {
                '1->A'  => [ 'compute_statistics' ],
                'A->1'  => [ 'post_wrapup_funnel_check' ],
            },
        },

        {   -logic_name => 'rib_fire_high_confidence_orths',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => [ 'mlss_id_for_high_confidence_factory', 'paralogue_for_import_factory' ],
        },

        {   -logic_name => 'paralogue_for_import_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory',
            -parameters => {
                'methods'   => { 'ENSEMBL_PARALOGUES' => 1 },
            },
            -flow_into  => {
                1 => { 'import_homology_table' => { 'mlss_id' => '#mlss_id#', 'high_conf_expected' => '0' } },
            },
        },

        {   -logic_name => 'polyploid_move_back_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'component_genomes' => 0,
                'normal_genomes'    => 0,
            },
            -flow_into => {
                2 => [ 'component_genome_dbs_move_back_factory' ],
            },
        },

        {   -logic_name => 'component_genome_dbs_move_back_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComponentGenomeDBFactory',
            -flow_into => {
                2 => {
                    'move_back_component_genes' => { 'source_gdb_id' => '#component_genome_db_id#', 'target_gdb_id' => '#principal_genome_db_id#'},
                },
            },
        },

        {   -logic_name => 'move_back_component_genes',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MoveComponentGenes',
            -hive_capacity => $self->o('reuse_capacity'),
        },

        {   -logic_name => 'gene_dumps_genome_db_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'extra_parameters'  => [ 'is_polyploid' ],
            },
            -rc_name    => '4Gb_job',
            -flow_into => {
                2 => WHEN(
                    '#is_polyploid#' => [ 'dump_polyploid_genes' ],
                    ELSE                [ 'dump_genes' ],
                ),
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

        {   -logic_name     => 'dump_polyploid_genes',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters     => {
                'output_file'   => '#gene_dumps_dir#/gene_member.#genome_db_id#.tsv',
                'append'        => ['--batch', '--quick'],
                'input_query'   => q|
                    SELECT gm.stable_id, gm.gene_member_id, df2.dnafrag_id, gm.dnafrag_start, gm.dnafrag_end, gm.dnafrag_strand
                    FROM dnafrag df1
                    JOIN gene_member gm USING (dnafrag_id)
                    JOIN dnafrag df2 USING (name)
                    WHERE df2.genome_db_id = #genome_db_id#
                        AND gm.genome_db_id IN (
                            SELECT gdb2.genome_db_id
                            FROM genome_db gdb1
                            JOIN genome_db gdb2 USING (name)
                            WHERE gdb1.genome_db_id = #genome_db_id#
                                AND gdb2.genome_component IS NOT NULL
                        )
                    ORDER BY df2.dnafrag_id, gm.dnafrag_start
                |,
            },
        },

        {   -logic_name => 'snapshot_posttree',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_3_after_tree_building.sql.gz',
            },
            -hive_capacity => 9, # this prevents too many competing `dump_per_mlss_homologies_tsv` jobs being spawned
            -rc_name        => '1Gb_24_hour_job',
        },

        {   -logic_name => 'rib_fire_cafe',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => WHEN('#do_cafe#' => 'CAFE_species_tree'),
        },

        {   -logic_name => 'rib_fire_homology_stats',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => [
                WHEN('#do_homology_stats#' => 'homology_stats_factory'),
                'set_default_values',
            ],
        },

        {   -logic_name => 'rib_fire_tree_stats',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => 'gene_count_factory',
        },

        {   -logic_name => 'rib_fire_hmm_build',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => WHEN('#do_hmm_export#' => 'build_HMM_factory'),
        },

        {   -logic_name => 'rib_fire_gene_qc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => WHEN('#do_gene_qc#' => 'get_species_set'),
        },

        {   -logic_name => 'rib_fire_homology_id_mapping',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => WHEN('#do_homology_id_mapping#' => 'id_map_mlss_factory'),
        },

        {   -logic_name    => 'compute_statistics',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComputeStatistics',
            -rc_name       => '1Gb_168_hour_job',
            -flow_into     => [ 'write_stn_tags' ],
        },

        {   -logic_name => 'post_wrapup_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => {
                1 => {
                    'datacheck_factory' => {
                        'datacheck_groups' => $self->o('datacheck_groups'),
                        'db_type' => $self->o('db_type'),
                        'compara_db' => $self->pipeline_url(),
                        'registry_file' => undef,
                    },
                },
            },
            %hc_analysis_params,
        },

        {   -logic_name     => 'write_stn_tags',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters     => {
                'input_file'    => $self->o('tree_stats_sql'),
            },
            -flow_into      => [ 'polyploid_move_back_factory', 'rename_labels' ],
        },

        {   -logic_name => 'generate_tree_stats_report',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StatsReport',
            -parameters => {
                'stats_exe'                  => $self->o('gene_tree_stats_report_exe'),
                'gene_tree_stats_shared_dir' => $self->o('gene_tree_stats_shared_dir'),
            },
        },

        {   -logic_name => 'group_genomes_under_taxa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupGenomesUnderTaxa',
            -parameters => {
                'taxlevels'             => $self->o('taxlevels'),
            },
            -flow_into => {
                2 => [ 'mlss_factory' ],
            },
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
                'prev_rel_db'   => '#mapping_db#',
            },
            -hive_capacity => $self->o('homology_dNdS_capacity'),
            -flow_into  => {
                -1 => [ 'mlss_id_mapping_himem' ],
                1 => { 'homology_id_mapping' => INPUT_PLUS() },
            },
        },

        {   -logic_name => 'mlss_id_mapping_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDMapping',
            -parameters => {
                'prev_rel_db'   => '#mapping_db#',
            },
            -hive_capacity => $self->o('homology_dNdS_capacity'),
            -rc_name   => '1Gb_job',
            -flow_into => { 1 => { 'homology_id_mapping' => INPUT_PLUS() } },
        },

        {   -logic_name => 'rib_fire_dnds',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => WHEN('#do_dnds#' => 'group_genomes_under_taxa'),
        },

        {   -logic_name => 'mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory',
            -flow_into => {
                2 => [ 'homology_factory' ],
            },
        },

        {   -logic_name => 'homology_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory',
            -parameters => {
                'hashed_mlss_id'            => '#expr(dir_revhash(#homo_mlss_id#))expr#',
                'homology_flatfile'         => '#homology_dumps_dir#/#hashed_mlss_id#/#homo_mlss_id#.#member_type#.homologies.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#homo_mlss_id#.#member_type#.homology_id_map.tsv',
            },
            -hive_capacity => $self->o('homology_dNdS_factory_capacity'),
            -flow_into => {
                'A->1' => [ 'hc_dnds' ],
                '2->A' => [ 'homology_dNdS' ],
                '3->A' => [ 'copy_homology_dNdS' ],
            },
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
            -rc_name    => '1Gb_job',
            -flow_into  => {
                -1 => [ 'homology_id_mapping_himem' ],
            },
            -analysis_capacity => 100,
        },

        {   -logic_name => 'homology_id_mapping_himem',
            -parameters => {
                'prev_rel_db'               => '#mapping_db#',
                'hashed_mlss_id'            => '#expr(dir_revhash(#mlss_id#))expr#',
                'homology_flatfile'         => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                'prev_homology_flatfile'    => '#prev_homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homology_id_map.tsv',
            },
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -flow_into  => {
                -1 => [ 'homology_id_mapping_hugemem' ],
            },
            -analysis_capacity => 20,
            -rc_name => '8Gb_job',
        },

        {   -logic_name => 'homology_id_mapping_hugemem',
            -parameters => {
                'prev_rel_db'               => '#mapping_db#',
                'hashed_mlss_id'            => '#expr(dir_revhash(#mlss_id#))expr#',
                'homology_flatfile'         => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                'prev_homology_flatfile'    => '#prev_homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                'homology_mapping_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homology_id_map.tsv',
            },
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -analysis_capacity => 20,
            -rc_name => '16Gb_job',
        },

        {   -logic_name => 'rib_fire_orth_wga',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => WHEN('#do_orth_wga#' => 'check_dna_alns_complete'),
        },

        {   -logic_name => 'check_dna_alns_complete',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CheckDnaAlnsComplete',
            -flow_into  => {
                1 => { 'pair_species' => { 'species_set_name' => $self->o('wga_species_set_name') } },
            },
            -max_retry_count => 0,
        },

        {   -logic_name => 'homology_dNdS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Homology_dNdS',
            -parameters => {
                'codeml_parameters_file'    => $self->o('codeml_parameters_file'),
                'codeml_exe'                => $self->o('codeml_exe'),
                'force_rerunning'           => 0,
            },
            -hive_capacity        => $self->o('homology_dNdS_capacity'),
            -priority=> 20,
        },

        {   -logic_name => 'copy_homology_dNdS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CopyHomology_dNdS',
            -parameters => {
            },
            -hive_capacity        => $self->o('copy_homology_dNdS_capacity'),
            -batch_size => 5,
            -flow_into  => {
                2 => [ 'homology_dNdS' ],
            },
        },


        {   -logic_name         => 'hc_dnds',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'homology_dnds',
            },
            -flow_into          => [ 'threshold_on_dS' ],
            %hc_analysis_params,
        },

        {   -logic_name => 'threshold_on_dS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS',
            -hive_capacity => $self->o('homology_dNdS_capacity'),
            -flow_into  => {
                -1 => 'threshold_on_dS_himem',
            },
        },

        {   -logic_name => 'threshold_on_dS_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS',
            -hive_capacity => $self->o('homology_dNdS_capacity'),
        },

        {   -logic_name => 'rib_fire_goc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => WHEN('#do_goc#' => 'goc_entry_point'),
        },

        {   -logic_name => 'gene_count_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -rc_name    => '1Gb_job',
            -parameters => {
                'component_genomes' => 1,
                'polyploid_genomes' => 0,
                'fan_branch_code' => 1,
            },
            -flow_into  => [ 'count_genes_in_tree' ],
        },

        {   -logic_name => 'count_genes_in_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CountGenesInTree',
            -rc_name    => '1Gb_job',
            -parameters => {
                'gene_count_exe' => $self->o('count_genes_in_tree_exe'),
            },
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
                2 => [ 'orthology_stats', ],
                3 => [ 'paralogy_stats',  ],
            },
        },

        {   -logic_name => 'orthology_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthologyStats',
            -parameters => {
                'hashed_mlss_id'    => '#expr(dir_revhash(#mlss_id#))expr#',
                'homology_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
            },
            -hive_capacity => $self->o('ortho_stats_capacity'),
        },

        {   -logic_name => 'paralogy_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats',
            -parameters => {
                'hashed_mlss_id'    => '#expr(dir_revhash(#mlss_id#))expr#',
                'homology_flatfile' => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                'species_tree_label'    => $self->o('use_notung') ? 'binary' : 'default',
            },
            -hive_capacity => $self->o('ortho_stats_capacity'),
        },

        {
             -logic_name => 'rename_labels',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RenameLabels',
             -parameters => {
                 'clusterset_id'=> $self->o('collection'),
                 'label_prefix' => $self->o('label_prefix'),
             },
        },

        {   -logic_name => 'copy_dumps_to_shared_loc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'         => '/bin/bash -c "mkdir -p #homology_dumps_shared_dir# && rsync -rtO #homology_dumps_dir#/ #homology_dumps_shared_dir#"',
            },
        },

        {   -logic_name => 'wga_expected_dumps',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpWGAExpectedTags',
            -parameters => {
                'wga_expected_file'  => '#dump_dir#/wga_expected.mlss_tags.tsv',
            },
        },

            @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE::pipeline_analyses_cafe($self) },
            @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::GOC::pipeline_analyses_goc($self)  },
            @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneSetQC::pipeline_analyses_GeneSetQC($self)  },
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
