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

Bio::EnsEMBL::Compara::PipeConfig::CreateHmmProfiles_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CreateHmmProfiles_conf -host mysql-ens-compara-prod-X -port XXXX \
        -mlss_id <your_mlss_id>

=head1 DESCRIPTION

The PipeConfig file for Creating HMM profiles. This pipeline fetches the
PANTHER profiles and perform Hmmer searches to classify our sequences and
then build the new HMMs. These families are then filtered and processed.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::CreateHmmProfiles_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # where to find the list of Compara methods. Unlikely to be changed
    'method_link_dump_file' => $self->check_file_in_ensembl('ensembl-compara/sql/method_link.txt'),

    # custom pipeline name, in case you don't like the default one
        # 'rel_with_suffix' is the concatenation of 'ensembl_release' and 'rel_suffix'
        # Tag attached to every single tree
        'division'              => undef,

    #default parameters for the geneset qc

        'coverage_threshold' => 50, #percent
        'species_threshold'  => '#expr(#species_count#/2)expr#', #half of ensembl species

    # dependent parameters: updating 'base_dir' should be enough
        'work_dir'              => $self->o('pipeline_dir'),
        'fasta_dir'             => $self->o('work_dir') . '/blast_db',  # affects 'dump_subset_create_blastdb' and 'blastp'
        'cluster_dir'           => $self->o('work_dir') . '/cluster',
        'dump_dir'              => $self->o('work_dir') . '/dumps',
        'tmp_hmmsearch'         => $self->o('work_dir') . '/tmp_hmmsearch',
        'big_tmp_dir'           => $self->o('work_dir') . '/scratch',
        'seed_hmm_library_basedir'                  => $self->o('work_dir') . '/seed_hmms',
        'panther_hmm_library_basedir'               => $self->o('work_dir') . '/hmm_panther_12',
        'worker_compara_hmm_library_basedir'        => $self->o('work_dir') . '/compara_hmm_'.$self->o('ensembl_release'),
        'worker_treefam_only_hmm_library_basedir'   => $self->o('work_dir') . '/treefam_hmms/2015-12-18_only_TF_hmmer3/',

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,
        'allow_missing_coordinates' => 0,
        'allow_missing_cds_seqs'    => 0,

    # blast parameters:
        # Amount of sequences to be included in each blast job
        'num_sequences_per_blast_job'   => 100,

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
        # File with gene / peptide names that must be excluded from the
        # clusters (e.g. know to disturb the trees)
        'gene_blocklist_file'           => '/dev/null',

    # tree building parameters:
        'use_quick_tree_break'      => 1,

        'split_genes_gene_count'    => 5000,

        'mcoffee_short_gene_count'  => 20,
        'mcoffee_himem_gene_count'  => 250,
        'mafft_gene_count'          => 300,
        'mafft_himem_gene_count'    => 400,
        'mafft_runtime'             => 7200,
        'treebest_threshold_n_residues' => 10000,
        'treebest_threshold_n_genes'    => 400,
        'update_threshold_trees'    => 0.2,

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
        # you can define your own species_tree for 'notung'. It *has* to be binary
        'binary_species_tree_input_file'   => undef,

    # executable locations:
        # HMM specific parameters
        # The location of the HMM library:
        'compara_hmm_library_basedir'               => $self->o('shared_hps_dir') . '/compara_hmm_'.$self->o('ensembl_release')."/",
        'target_compara_hmm_library_basedir'        => $self->o('warehouse_dir') . '/treefam_hmms/compara_hmm_'.$self->o('ensembl_release')."/",
        'treefam_hmm_library_basedir'               => $self->o('warehouse_dir') . '/treefam_hmms/2015-12-18/',
        'target_treefam_only_hmm_library_basedir'   => $self->o('warehouse_dir') . '/2015-12-18_only_TF_hmmer3/',

        #README file with the list of all names, genome_ids, assemblies, etc
        'readme_file'                   => $self->o('target_compara_hmm_library_basedir') . '/README_hmm_profiles'.$self->o('ensembl_release').'.txt',

        'seed_hmm_library_name'         => 'seed_hmm_compara.hmm3',
        'hmm_thresholding_table'        => 'hmm_thresholding',
        'hmmer_search_cutoff'           => '1e-23',
        'min_num_members'               => 4,
        'min_num_species'               => 2,
        'min_taxonomic_coverage'        => 0.5,
        'min_ratio_species_genes'       => 0.5,
        'max_gappiness'                 => 0.9,
	    'sequence_limit'                => 50,
	    'max_chunk_length'              => 0,
        'max_chunk_size'                => 100,
        'output_prefix'                 => "hmm_split_",

        # cdhit is used to filter out proteins that are too close to each other
        'cdhit_identity_threshold' => 0.99,

        #name of the profile to be created:
        'hmm_library_name'          => 'panther_12_0.hmm3',
        
        #Compara HMM profile name:
        'compara_hmm_library_name'  => 'compara_hmm_'.$self->o('ensembl_release').'.hmm3',

        #URL to find the PANTHER profiles:
        'panther_url'               => 'ftp://ftp.pantherdb.org/panther_library/current_release/',

        #File name in the 'panther_url':
        'panther_file'              => 'PANTHER12.0_ascii.tgz',

       # List of directories that contain Panther-like databases (with books/ and globals/)
       # It requires two more arguments for each file: the name of the library, and whether subfamilies should be loaded
       'panther_like_databases'  => [],
       #'panther_like_databases'  => [ ["/lustre/scratch110/ensembl/mp12/panther_hmms/PANTHER7.2_ascii", "PANTHER7.2", 1] ],

       # List of MultiHMM files to load (and their names)
       #'multihmm_files'          => [ ["/lustre/scratch110/ensembl/mp12/pfamA_HMM_fs.txt", "PFAM"] ],
       'multihmm_files'          => [],

       # Dumps coming from InterPro
       'panther_annotation_file'    => '/dev/null',
       #'panther_annotation_file' => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/panther_Interpro_annot_v8_1/loose_dummy.txt',

       # A file that holds additional tags we want to add to the HMM clusters (for instance: Best-fit models)
        'extra_model_tags_file'     => undef,

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>  30,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 200,
        'blastpu_capacity'          => 5000,
        'mcoffee_capacity'          => 2000,
        'alignment_filtering_capacity'  => 200,
        'filter_1_capacity'         => 50,
        'filter_2_capacity'         => 50,
        'filter_3_capacity'         => 50,
        'cluster_tagging_capacity'  => 200,
        'build_hmm_capacity'        => 100,
        'hc_capacity'               =>   4,
        'decision_capacity'         =>   4,
        'loadmembers_capacity'      => 30,
        'split_genes_capacity'      => 100,
        'HMMer_search_capacity'     => 8000,
        'HMMer_search_all_hits_capacity'     => 1000,

    # Setting priorities
        'mcoffee_himem_priority'    => 40,
        'mafft_himem_priority'      => 35,
        'mafft_priority'            => 30,
        'mcoffee_priority'          => 20,
        'noisy_priority'            => 20,

    # hive priority for non-LOCAL health_check analysis:
        'hc_priority'               => -10,

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://ensro@mysql-ens-compara-prod-4:4401/treefam_master',
        #'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_master',
        'ncbi_db'   => $self->o('master_db'),

        # Where the members come from (as loaded by the LoadMembers pipeline)
        'member_db' => 'mysql://ensro@mysql-ens-compara-prod-4:4401/mateus_load_members_tf_90',

    };
}


# This section has to be filled in any derived class
sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},  # inherit the standard resource classes, incl. multi-threaded

         '4Gb_big_tmp_job'  => { 'LSF' => ['-C0 -M4000 -R"select[mem>4000] rusage[mem=4000]"', '-worker_base_tmp_dir ' . $self->o('big_tmp_dir')] },
    };
}


sub pipeline_checks_pre_init {
    my ($self) = @_;

    # The master db must be defined to allow mapping stable_ids and checking species for reuse
    die "The master dabase must be defined with a mlss_id" if $self->o('master_db') and not $self->o('mlss_id');
    die "mlss_id can not be defined in the absence of a master dabase" if $self->o('mlss_id') and not $self->o('master_db');

    # Without a master database, we must provide other parameters
    die if not $self->o('master_db') and not $self->o('ncbi_db');
}


sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

        $self->pipeline_create_commands_rm_mkdir(['cluster_dir', 'dump_dir', 'fasta_dir', 'tmp_hmmsearch', 'big_tmp_dir']),
        $self->pipeline_create_commands_rm_mkdir(['compara_hmm_library_basedir', 'panther_hmm_library_basedir', 'seed_hmm_library_basedir']),
    ];
}


sub pipeline_wide_parameters {
# these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'master_db'     => $self->o('master_db'),
        'ncbi_db'       => $self->o('ncbi_db'),
        'member_db'     => $self->o('member_db'),

        'cluster_dir'   => $self->o('cluster_dir'),
        'fasta_dir'     => $self->o('fasta_dir'),
        'dump_dir'      => $self->o('dump_dir'),
        'tmp_hmmsearch' => $self->o('tmp_hmmsearch'),

        'target_compara_hmm_library_basedir'   => $self->o('target_compara_hmm_library_basedir'),
        'panther_hmm_library_basedir'   => $self->o('panther_hmm_library_basedir'),
        'seed_hmm_library_basedir'      => $self->o('seed_hmm_library_basedir'),
        'seed_hmm_library_name'         => $self->o('seed_hmm_library_name'),

        'binary_species_tree_input_file'   => $self->o('binary_species_tree_input_file'),
        'all_blast_params'          => $self->o('all_blast_params'),

        'use_quick_tree_break'   => $self->o('use_quick_tree_break'),
    };
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my %hc_analysis_params = (
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
            -max_retry_count    => 1,
    );
    my %decision_analysis_params = (
            -analysis_capacity  => $self->o('decision_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
            -max_retry_count    => 1,
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
                'A->1'  => [ 'backbone_fire_clustering' ],
            },
        },

        {   -logic_name => 'backbone_fire_clustering',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_1_before_clustering.sql.gz',
            },
            -flow_into  => {
                '1->A'  => [ 'build_hmm_entry_point' ],
                'A->1'  => [ 'backbone_fire_tree_building' ],
            },
        },

        {   -logic_name => 'backbone_fire_tree_building',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_3_before_tree_building.sql.gz',
            },
            -flow_into  => {
                '1->A'  => [ 'cluster_factory' ],
                'A->1'  => [ 'backbone_pipeline_finished' ],
            },
        },

        {   -logic_name => 'backbone_pipeline_finished',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
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

# ---------------------------------------------[load GenomeDB entries from member_db]---------------------------------------------

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => '#master_db#',   # that's where genome_db_ids come from
                'mlss_id'           => $self->o('mlss_id'),
                # Add the locators coming from member_db
                'extra_parameters'  => [ 'locator' ],
                'genome_db_data_source' => '#member_db#',
            },
            -rc_name => '4Gb_job',
            -flow_into => {
                '2->A' => {
                    'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' },
                },
                'A->1' => [ 'create_mlss_ss' ],
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -flow_into  => [ 'genome_member_copy' ],
            -batch_size => 10,
            -hive_capacity => 30,
            -max_retry_count => 2,
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

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -parameters => {
                'whole_method_links'    => [ 'PROTEIN_TREES' ],
            },
            -rc_name => '2Gb_job',
            -parameters => {
                'create_homology_mlss'       => '0',
            },
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
                               'species_tree_input_file'                => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
                               #Options needed when using strains:
                               #-----------------------------------------------------
                               'allow_subtaxa'                          => 1,
                               'multifurcation_deletes_all_subnodes'    => [ 10088 ],
                               #-----------------------------------------------------
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

# ---------------------------------------------[reuse members]-----------------------------------------------------------------------


        {   -logic_name => 'genome_member_copy',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyCanonRefMembersByGenomeDB',
            -parameters => {
                'reuse_db'              => '#member_db#',
                'biotype_filter'        => 'biotype_group = "coding"',
                'exclude_tables'        => [ 'exon_boundaries', 'hmm_annot', 'seq_member_projection_stable_id' ],
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'hc_members_per_genome' ],
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
            %hc_analysis_params,
        },


        {   -logic_name         => 'hc_members_globally',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_globally',
            },
            %hc_analysis_params,
        },

# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

#--------------------------------------------------------[load the HMM profiles]----------------------------------------------------

#----------------------------------------------[classify canonical members based on HMM searches]-----------------------------------

        { -logic_name           => 'load_PANTHER',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadPanther',
            -rc_name            => '4Gb_big_tmp_job',
            -max_retry_count    => 0,
            -parameters         => {
                                    'library_name'      => $self->o('hmm_library_name'),
                                    'hmmer_home'        => $self->o('hmmer3_home'),
                                    'panther_hmm_lib'   => $self->o('panther_hmm_library_basedir'),
                                    'url'               => $self->o('panther_url'),
                                    'file'              => $self->o('panther_file'),
            },
            -flow_into      => [ 'chunk_sequence' ],
        },

        { -logic_name => 'chunk_sequence',
            -module => 'Bio::EnsEMBL::Hive::RunnableDB::FastaFactory',
            -parameters => {
                            'sequence_limit'            => $self->o('sequence_limit'),
                            'max_chunk_length'          => $self->o('max_chunk_length'),
                            'max_chunk_size'            => $self->o('max_chunk_size'),
                            'input_format'              => 'fasta',
                            'seq_filter'                => '^TF',
                            'inputfile'                 => $self->o('treefam_hmm_library_basedir')."/globals/con.Fasta",
                            'output_dir'                => $self->o('tmp_hmmsearch'),
                            'output_prefix'             => $self->o('output_prefix'),
                            'hash_directories'          => 1,
                            'split_by_sequence_count'   => 1,
            },

            -flow_into  => {
                '2->A'  => [ 'treefam_panther_hmm_overlapping' ],
                'A->1'  => [ 'build_seed_hmms' ],
            },
        },

        { -logic_name     => 'treefam_panther_hmm_overlapping',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HmmOverlap',
            -rc_name       => '1Gb_job',
            -parameters     => {
                                'hmmer_home'        => $self->o('hmmer3_home'),
                                'library_name'      => $self->o('hmm_library_name'),
                                'panther_hmm_lib'   => $self->o('panther_hmm_library_basedir'),
            },
            -hive_capacity  => $self->o('HMMer_search_capacity'),
            -flow_into      => {
                                -1 => [ 'treefam_panther_hmm_overlapping_himem' ],  # MEMLIMIT
                            },
        },

        { -logic_name     => 'treefam_panther_hmm_overlapping_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HmmOverlap',
            -rc_name       => '2Gb_job',
            -parameters     => {
                                'hmmer_home'        => $self->o('hmmer3_home'),
                                'library_name'      => $self->o('hmm_library_name'),
                                'panther_hmm_lib'   => $self->o('panther_hmm_library_basedir'),
            },
            -hive_capacity => $self->o('HMMer_search_capacity'),
        },

        { -logic_name     => 'build_seed_hmms',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BuildSeedHmms',
            -rc_name       => '1Gb_job',
            -parameters     => {
                                'hmmer_home'                => $self->o('hmmer3_home'),
                                'panther_hmm_library_name'  => $self->o('hmm_library_name'),
                                'treefam_hmm_lib'           => $self->o('treefam_hmm_library_basedir'),
                                'target_treefam_only_hmm_lib'      => $self->o('target_treefam_only_hmm_library_basedir'),
                                'panther_hmm_lib'           => $self->o('panther_hmm_library_basedir'),
                                'seed_hmm_library_basedir'  => $self->o('seed_hmm_library_basedir'),
                                'seed_hmm_library_name'     => $self->o('seed_hmm_library_name'),
            },
            -hive_capacity  => $self->o('HMMer_search_capacity'),
            -flow_into      => {
                                1 => [ 'backup_before_cdhit_diversity' ],
                            },
        },

        {   -logic_name => 'backup_before_cdhit_diversity',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_2_before_cdhit_divergency.sql.gz',
            },
            -flow_into  => {
                '1->A'  => [ 'diversity_CDHit' ],
                'A->1'  => [ 'HMMer_search_factory' ],
            },
        },

        {   -logic_name => 'diversity_CDHit',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CDHitDiversity',

            -parameters => {
                            'cdhit_exe'                => $self->o('cdhit_exe'),
                            'cdhit_identity_threshold' => '0.99',
                            'cdhit_num_threads'        => 8,
                            'cdhit_memory_in_mb'       => 0,
            },

            -flow_into     => {
                -1 => [ 'diversity_CDHit_himem' ],
                3 => [ '?table_name=seq_member_projection' ],
            },

            -hive_capacity => $self->o('build_hmm_capacity'),
            -batch_size    => 50,
            -priority      => -20,
            -rc_name       => '16Gb_16c_job',
        },

        {   -logic_name => 'diversity_CDHit_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CDHitDiversity',

            -parameters => {
                'cdhit_exe'                => $self->o('cdhit_exe'),
                'cdhit_identity_threshold' => '0.99',
                'cdhit_num_threads'        => 8,
                'cdhit_memory_in_mb'       => 0,
            },
            -flow_into => {
                3 => [ '?table_name=seq_member_projection' ],
            },

            -hive_capacity => $self->o('build_hmm_capacity'),
            -batch_size    => 10,
            -priority      => -20,
            -rc_name       => '32Gb_16c_job',
        },


        {   -logic_name => 'HMMer_search_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FactoryUnannotatedMembers',
            -parameters => {
                            'use_diversity_filter' => 1,
                           },
            -rc_name       => '4Gb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A'  => [ 'HMMer_search' ],
                'A->1'  => [ 'HMM_clusterize' ],
            },
        },

        {
         -logic_name => 'HMMer_search',
         -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMerSearch',
         -parameters => {
                         'hmmer_home'        => $self->o('hmmer3_home'),
                         'library_name'      => $self->o('seed_hmm_library_name'),
                         'library_basedir'   => $self->o('seed_hmm_library_basedir'),
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
                         'library_name'      => $self->o('seed_hmm_library_name'),
                         'library_basedir'   => $self->o('seed_hmm_library_basedir'),
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
                         'library_name'      => $self->o('seed_hmm_library_name'),
                         'library_basedir'   => $self->o('seed_hmm_library_basedir'),
                         'hmmer_cutoff'      => $self->o('hmmer_search_cutoff'),
                        },
         -hive_capacity => $self->o('HMMer_search_capacity'),
         -rc_name => '32Gb_job',
         -priority=> 25,
        },

            {
             -logic_name => 'HMM_clusterize',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClusterize',
             -parameters => {
                 'extra_tags_file'  => $self->o('extra_model_tags_file'),
             },
             -rc_name => '16Gb_job',
             -flow_into      => [ 'dump_unannotated_members' ],
            },

# -------------------------------------------------[Blast unannotated members]-------------------------------------------------------

        {   -logic_name => 'dump_unannotated_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpUnannotatedMembersIntoFasta',
            -parameters => {
                'fasta_file'    => '#fasta_dir#/unannotated.fasta',
            },
            -rc_name       => '16Gb_job',
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
            -rc_name       => '1Gb_job',
            -flow_into  => [ 'unannotated_all_vs_all_factory' ],
        },

        {   -logic_name => 'unannotated_all_vs_all_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastFactoryUnannotatedMembers',
            -parameters => {
                'step'              => $self->o('num_sequences_per_blast_job'),
            },
            -rc_name       => '16Gb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A' => [ 'blastp_unannotated' ],
                'A->1' => [ 'hcluster_dump_input_all_pafs' ]
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
               -2 => 'break_batch',
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
               -2 => 'break_batch',
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


        {   -logic_name    => 'break_batch',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BreakUnannotatedBlast',
            -flow_into  => {
                2 => 'blastp_unannotated_no_runlimit',
            }
        },

        {   -logic_name => 'hcluster_dump_input_all_pafs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepareSingleTable',
            -parameters => {
                'outgroups'     => $self->o('outgroups'),
            },
            -rc_name       => '4Gb_job',
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into  => [ 'hcluster_run' ],
        },




# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

# ---------------------------------------------[clustering step]---------------------------------------------------------------------

        {   -logic_name => 'build_hmm_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into => {
                '1->A' => [ 'load_PANTHER' ],
                'A->1' => [ 'remove_blocklisted_genes' ],
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
            -rc_name => '32Gb_job',
        },

        {   -logic_name => 'hcluster_parse_output',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput',
            -rc_name => '16Gb_job',
        },

        {   -logic_name     => 'cluster_tagging',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ClusterTagging',
            -hive_capacity  => $self->o('cluster_tagging_capacity'),
            -rc_name    	=> '4Gb_job',
            -batch_size     => 50,
            -flow_into => {
               -1 => [ 'cluster_tagging_himem' ],  # MEMLIMIT
            },
        },

        {   -logic_name     => 'cluster_tagging_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ClusterTagging',
            -hive_capacity  => $self->o('cluster_tagging_capacity'),
            -rc_name    	=> '8Gb_job',
            -batch_size     => 50,
        },

        {   -logic_name => 'filter_1_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id, COUNT(seq_member_id) AS tree_num_genes FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "tree" AND clusterset_id="default" GROUP BY root_id',
            },
            -flow_into  => {
                2 => 'filter_level_1',
            }
        },

        {   -logic_name => 'filter_level_1',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterSmallClusters',
            -parameters         => {
                'min_num_members'           => $self->o('min_num_members'),
                'min_num_species'           => $self->o('min_num_species'),
                'min_taxonomic_coverage'    => $self->o('min_taxonomic_coverage'),
                'min_ratio_species_genes'   => $self->o('min_ratio_species_genes'),
            },
            -hive_capacity  => $self->o('filter_1_capacity'),
            -batch_size     => 10,
        },


        {   -logic_name         => 'remove_blocklisted_genes',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveBlocklistedGenes',
            -parameters         => {
                'blocklist_file' => $self->o('gene_blocklist_file'),
            },
            -flow_into          => [ 'clusterset_backup' ],
        },

        {   -logic_name         => 'create_additional_clustersets',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets',
            -parameters         => {
                member_type     => 'protein',
                'additional_clustersets'    => [qw(treebest phyml-aa phyml-nt nj-dn nj-ds nj-mm raxml raxml_parsimony raxml_bl notung copy raxml_update filter_level_1 filter_level_2 filter_level_3 filter_level_4 fasttree )],
            },
            -flow_into          => [ 'cluster_tagging_factory' ],
        },


# ---------------------------------------------[Pluggable QC step]----------------------------------------------------------

        {   -logic_name    => 'clusterset_backup',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => 'INSERT IGNORE INTO gene_tree_backup (seq_member_id, root_id) SELECT seq_member_id, root_id FROM gene_tree_node WHERE seq_member_id IS NOT NULL',
            },
            -flow_into          => [ 'create_additional_clustersets' ],
        },

        {   -logic_name => 'cluster_tagging_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id="default"',
            },
            -flow_into => {
                '2->A'  => [ 'cluster_tagging' ],
                'A->1'  => [ 'filter_1_factory' ],
            },
        },

# ---------------------------------------------[main tree fan]-------------------------------------------------------------

        {   -logic_name => 'cluster_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id, COUNT(seq_member_id) AS tree_num_genes FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "tree" AND clusterset_id="filter_level_1" GROUP BY root_id',
            },
            -flow_into  => {
                '2->A'  => [ 'alignment_entry_point' ],
                'A->1'  => [ 'hc_global_tree_set' ],
            },
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
                'A->1' => [ 'filter_decision' ],
            },
            %decision_analysis_params,
        },

        {   -logic_name         => 'hc_global_tree_set',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -flow_into      => [ 'backup_before_cdhit_filter', 'write_stn_tags' ],
            %hc_analysis_params,
        },

        {   -logic_name     => 'write_stn_tags',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters     => {
                'input_file'    => $self->o('tree_stats_sql'),
            },
            -flow_into      => [ 'email_tree_stats_report' ],
        },

        {   -logic_name     => 'email_tree_stats_report',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HTMLReport',
            -parameters     => {
                'email' => $self->o('email'),
            },
        },


# ---------------------------------------------[Pluggable MSA steps]----------------------------------------------------------

        {   -logic_name => 'mcoffee_short',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'cmd_max_runtime'       => '43200',
                'method'                => 'cmcoffee',
                'mcoffee_exe'           => $self->o('mcoffee_exe'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
                'escape_branch'         => -1,
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -batch_size           => 20,
            -rc_name    => '1Gb_job',
            -flow_into => {
               -1 => [ 'mcoffee' ],  # MEMLIMIT
               -2 => [ 'mafft' ],
            },
        },

        {   -logic_name => 'mcoffee',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'cmd_max_runtime'       => '43200',
                'method'                => 'cmcoffee',
                'mcoffee_exe'           => $self->o('mcoffee_exe'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
                'escape_branch'         => -1,
            },
            -analysis_capacity    => $self->o('mcoffee_capacity'),
            -rc_name    => '2Gb_job',
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
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '2Gb_job',
            -priority   => $self->o('mafft_priority'),
            -flow_into => {
               -1 => [ 'mafft_himem' ],  # MEMLIMIT
            },
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
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '8Gb_job',
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
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '8Gb_job',
            -priority   => $self->o('mafft_himem_priority'),
        },

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
            -flow_into  =>
                WHEN(
                     '(#tree_gene_count# <= #threshold_n_genes#) || (#tree_aln_length# <= #threshold_aln_len#)' => 'filter_level_2',
                     '(#tree_gene_count# >= #threshold_n_genes_large# and #tree_aln_length# > #threshold_aln_len#) || (#tree_aln_length# >= #threshold_aln_len_large# and #tree_gene_count# > #threshold_n_genes#)' => 'noisy_large',
                     ELSE 'noisy',
                ),
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
            -flow_into      => [ 'filter_level_2' ],
            -batch_size     => 5,
        },

        {   -logic_name     => 'noisy_large',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Noisy',
            -parameters => {
                'noisy_exe'    => $self->o('noisy_exe'),
                               'noisy_cutoff'  => $self->o('noisy_cutoff_large'),
            },
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -rc_name        => '16Gb_job',
            -priority       => $self->o('noisy_priority'),
            -flow_into      => [ 'filter_level_2' ],
            -batch_size     => 5,
        },

        {   -logic_name => 'filter_level_2',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterGappyClusters',
            -parameters         => {
                'max_gappiness'           => $self->o('max_gappiness'),
            },
            -hive_capacity  => $self->o('filter_2_capacity'),
            -batch_size     => 5,
            -flow_into      => [ 'filter_level_3' ],
        },

        {   -logic_name => 'filter_level_3',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterSubfamiliesPatterns',
            -parameters         => {
                'fasttree_exe'            => $self->o('fasttree_exe'),
                'treebest_exe'            => $self->o('treebest_exe'),
                'output_clusterset_id'    => 'fasttree',
                'input_clusterset_id'     => 'default',
            },
            -hive_capacity  => $self->o('filter_3_capacity'),
            -rc_name 		=> '2Gb_job',
            -batch_size     => 5,

            -flow_into  => {
                2 => WHEN (
                    '(#tree_gene_count# >= #mafft_gene_count# and #tree_gene_count# < #mafft_himem_gene_count#)'   => 'mafft_supertree',
                    '(#tree_gene_count# >= #mafft_himem_gene_count#)'                                              => 'mafft_supertree_himem',
                ),
               -1 => [ 'filter_level_3_himem' ],  # MEMLIMIT
            }
        },

        {   -logic_name => 'filter_level_3_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterSubfamiliesPatterns',
            -parameters         => {
                'fasttree_exe'            => $self->o('fasttree_exe'),
                'treebest_exe'            => $self->o('treebest_exe'),
                'output_clusterset_id'    => 'fasttree',
                'input_clusterset_id'     => 'default',
            },
            -hive_capacity  => $self->o('filter_3_capacity'),
            -rc_name 		=> '16Gb_job',
            -batch_size     => 5,

            -flow_into  => {
                2 => WHEN (
                    '(#tree_gene_count# >= #mafft_gene_count# and #tree_gene_count# < #mafft_himem_gene_count#)'   => 'mafft_supertree',
                    '(#tree_gene_count# >= #mafft_himem_gene_count#)'                                              => 'mafft_supertree_himem',
                ),
            }
        },

        {   -logic_name => 'mafft_supertree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_exe'                  => $self->o('mafft_exe'),
                'escape_branch'              => -1,
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '2Gb_job',
            -priority   => $self->o('mafft_priority'),
            -flow_into => {
               -1 => [ 'mafft_supertree_himem' ],  # MEMLIMIT
            },
        },

        {   -logic_name => 'mafft_supertree_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_exe'                  => $self->o('mafft_exe'),
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '8Gb_job',
            -priority   => $self->o('mafft_himem_priority'),
        },

# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

# ---------------------------------------------[alignment filtering]-------------------------------------------------------------

# ---------------------------------------------[small trees decision]-------------------------------------------------------------

# ---------------------------------------------[model test]-------------------------------------------------------------
           
# ---------------------------------------------[tree building with treebest]-------------------------------------------------------------
           
# ---------------------------------------------[tree building with raxml]-------------------------------------------------------------
  
# ---------------------------------------------[tree reconciliation / rearrangements]-------------------------------------------------------------

        {   -logic_name     => 'split_genes',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -parameters     => {
                split_genes_gene_count  => $self->o('split_genes_gene_count'),
            },
            -hive_capacity  => $self->o('split_genes_capacity'),
            -batch_size     => 20,
            -flow_into      => [ 'build_HMM_aa_v3' ],
        },

        {  -logic_name => 'build_HMM_aa_v3',
           -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',

           -parameters => {
                            'hmmer_home'               => $self->o('hmmer3_home'),
                            'hmmer_version'            => 3,
                            'check_split_genes'        => 1,
                            'cdna'                     => 0,
           },

           -hive_capacity => $self->o('build_hmm_capacity'),
           -batch_size    => 5,
           -priority      => -20,
           -rc_name       => '1Gb_job',
           -flow_into     => {
               -1 => 'build_HMM_aa_v3_himem',
           },
        },

        {   -logic_name     => 'build_HMM_aa_v3_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                            'hmmer_home'            => $self->o('hmmer3_home'),
                            'hmmer_version'         => 3,
                            'check_split_genes'     => 1,
                            'cdna'                  => 0,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -priority       => -15,
            -rc_name        => '4Gb_job',
        },


# ---------------------------------------------[Quick tree break steps]-----------------------------------------------------------------------

# -------------------------------------------[CDHit step (filter_level_4)]---------------------------------------------------------------------

        {   -logic_name => 'backup_before_cdhit_filter',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_4_before_cdhit_filter.sql.gz',
            },
            -flow_into  => {
                '1'  => [ 'CDHit_factory' ],
            },
        },

        {   -logic_name => 'CDHit_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id="filter_level_3"',
            },
            -flow_into  => {
                '2->A'  => [ 'CDHit' ],
                'A->1'  => [ 'prepare_hmm_profiles' ],
            },
        },

        {  -logic_name => 'CDHit',
           -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CDHit',

           -parameters => {
                            'cdhit_exe'                => $self->o('cdhit_exe'),
                            'cdhit_identity_threshold' => $self->o('cdhit_identity_threshold'),
                            'cdhit_num_threads'        => 1,
                            'cdhit_memory_in_mb'       => 0,
           },

            -flow_into => {
               1 => [ 'CDHit_alignment_entry_point' ],  # MEMLIMIT
               -1 => [ 'CDHit_himem' ],  # MEMLIMIT
            },

           -hive_capacity => $self->o('build_hmm_capacity'),
           -batch_size    => 50,
           -priority      => -20,
           -rc_name       => '1Gb_job',
       },

        {  -logic_name => 'CDHit_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CDHit',

            -parameters => {
                'cdhit_exe'                => $self->o('cdhit_exe'),
                'cdhit_identity_threshold' => $self->o('cdhit_identity_threshold'),
                'cdhit_num_threads'        => 4,
                'cdhit_memory_in_mb'       => 0,
            },

            -flow_into => {
               1 => [ 'CDHit_alignment_entry_point' ],  # MEMLIMIT
            },

            -hive_capacity => $self->o('build_hmm_capacity'),
            -batch_size    => 10,
            -priority      => -20,
            -rc_name       => '4Gb_4c_job',
        },

        {   -logic_name => 'CDHit_alignment_entry_point',
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
                    '(#tree_gene_count# <  #mcoffee_short_gene_count#)                                                      and     (#tree_reuse_aln_runtime#/1000 <  #mafft_runtime#)'  => 'cdhit_mcoffee_short',
                    '(#tree_gene_count# >= #mcoffee_short_gene_count# and #tree_gene_count# < #mcoffee_himem_gene_count#)   and     (#tree_reuse_aln_runtime#/1000 <  #mafft_runtime#)'  => 'cdhit_mcoffee',
                    '(#tree_gene_count# >= #mcoffee_himem_gene_count# and #tree_gene_count# < #mafft_gene_count#)           and     (#tree_reuse_aln_runtime#/1000 <  #mafft_runtime#)'  => 'cdhit_mcoffee_himem',
                    '(#tree_gene_count# >= #mafft_gene_count#         and #tree_gene_count# < #mafft_himem_gene_count#)     or      (#tree_reuse_aln_runtime#/1000 >= #mafft_runtime#)'  => 'cdhit_mafft',
                    '(#tree_gene_count# >= #mafft_himem_gene_count#)                                                        or      (#tree_reuse_aln_runtime#/1000 >= #mafft_runtime#)'  => 'cdhit_mafft_himem',
                ),
                'A->1' => [ 'split_genes' ],
            },
            %decision_analysis_params,
        },


        {   -logic_name => 'cdhit_mcoffee_short',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'cmd_max_runtime'       => '43200',
                'method'                => 'cmcoffee',
                'mcoffee_exe'           => $self->o('mcoffee_exe'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
                'escape_branch'         => -1,
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -batch_size           => 20,
            -rc_name    => '1Gb_job',
            -flow_into => {
               -1 => [ 'cdhit_mcoffee' ],  # MEMLIMIT
               -2 => [ 'cdhit_mafft' ],
            },
        },

        {   -logic_name => 'cdhit_mcoffee',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'cmd_max_runtime'       => '43200',
                'method'                => 'cmcoffee',
                'mcoffee_exe'           => $self->o('mcoffee_exe'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
                'escape_branch'         => -1,
            },
            -analysis_capacity    => $self->o('mcoffee_capacity'),
            -rc_name    => '2Gb_job',
            -priority   => $self->o('mcoffee_priority'),
            -flow_into => {
               -1 => [ 'cdhit_mcoffee_himem' ],  # MEMLIMIT
               -2 => [ 'cdhit_mafft' ],
            },
        },

        {   -logic_name => 'cdhit_mafft',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_exe'                  => $self->o('mafft_exe'),
                'escape_branch'              => -1,
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '2Gb_job',
            -priority   => $self->o('mafft_priority'),
            -flow_into => {
               -1 => [ 'cdhit_mafft_himem' ],  # MEMLIMIT
            },
        },

        {   -logic_name => 'cdhit_mcoffee_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'cmd_max_runtime'       => '43200',
                'method'                => 'cmcoffee',
                'mcoffee_exe'           => $self->o('mcoffee_exe'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
                'escape_branch'         => -2,
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '8Gb_job',
            -priority   => $self->o('mcoffee_himem_priority'),
            -flow_into => {
               -1 => [ 'cdhit_mafft_himem' ],
               -2 => [ 'cdhit_mafft_himem' ],
            },
        },

        {   -logic_name => 'cdhit_mafft_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_exe'                  => $self->o('mafft_exe'),
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '8Gb_job',
            -priority   => $self->o('mafft_himem_priority'),
        },

# ---------------------------------------------[HMM thresholding step]-------------------------------------------------------------

        {   -logic_name           => 'prepare_hmm_profiles',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PrepareHmmProfiles',
            -rc_name            => '1Gb_job',
            -max_retry_count    => 0,
            -parameters         => {
                                    'library_name'      => $self->o('compara_hmm_library_name'),
                                    'hmmer_home'        => $self->o('hmmer3_home'),
                                    'worker_compara_hmm_lib'   => $self->o('worker_compara_hmm_library_basedir'),
            },
            -flow_into => {
               1 => [ 'hmm_thresholding_factory' ],
           },
        },

        {   -logic_name     => 'hmm_thresholding_factory',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HmmThresholdFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id, seq_member_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "tree" AND clusterset_id = "filter_level_4" AND seq_member_id IS NOT NULL',
            },
            -rc_name       => '2Gb_job',
            -flow_into  => {
                '2->A'  => [ 'hmm_thresholding_searches' ],
                'A->1'  => [ 'compute_thresholds' ],
            },
        },

        {   -logic_name     => 'hmm_thresholding_searches',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMerSearch',
            -rc_name        => '2Gb_job',
            -parameters     => {
                                'hmmer_home'            => $self->o('hmmer3_home'),
                                'library_name'          => $self->o('compara_hmm_library_name'),
                                'library_basedir'       => $self->o('worker_compara_hmm_library_basedir'),
                                'target_table'          => $self->o('hmm_thresholding_table'),
                                'source_clusterset_id'  => 'filter_level_4',
                                'fetch_all_seqs'        => 1,
                                'store_all_hits'        => 1,
            },
            -hive_capacity  => $self->o('HMMer_search_all_hits_capacity'),
            -batch_size     => 5,
            -flow_into => {
               -1 => [ 'hmm_thresholding_searches_himem' ],
            }
        },

        {   -logic_name     => 'hmm_thresholding_searches_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMerSearch',
            -rc_name        => '8Gb_job',
            -parameters     => {
                                'hmmer_home'            => $self->o('hmmer3_home'),
                                'library_name'          => $self->o('compara_hmm_library_name'),
                                'library_basedir'       => $self->o('worker_compara_hmm_library_basedir'),
                                'target_table'          => $self->o('hmm_thresholding_table'),
                                'source_clusterset_id'  => 'filter_level_4',
                                'fetch_all_seqs'        => 1,
                                'store_all_hits'        => 1,
            },
            -batch_size     => 1,
            -priority       => 10,
            -hive_capacity  => $self->o('HMMer_search_all_hits_capacity'),
            -flow_into => {
               -1 => [ 'hmm_thresholding_searches_super_himem' ],
            }
        },

        {   -logic_name     => 'hmm_thresholding_searches_super_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMerSearch',
            -rc_name        => '64Gb_job',
            -parameters     => {
                                'hmmer_home'            => $self->o('hmmer3_home'),
                                'library_name'          => $self->o('compara_hmm_library_name'),
                                'library_basedir'       => $self->o('worker_compara_hmm_library_basedir'),
                                'target_table'          => $self->o('hmm_thresholding_table'),
                                'source_clusterset_id'  => 'filter_level_4',
                                'fetch_all_seqs'        => 1,
                                'store_all_hits'        => 1,
            },
            -batch_size     => 1,
            -priority       => 20,
            -hive_capacity  => $self->o('HMMer_search_all_hits_capacity'),
        },

        {   -logic_name     => 'compute_thresholds',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::ComputeHmmThresholds',
            -rc_name        => '4Gb_job',

            -flow_into => {
               1 => [ 'build_HMM_with_tags_factory' ],
           },
        },


        #new build_HMM_aa_v3 with cut_off tags
        #-----------------------------------------------------------------------------------------------
        {   -logic_name => 'build_HMM_with_tags_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id="filter_level_4"',
            },
            -flow_into  => {
                '2->A'  => [ 'build_HMM_with_tags' ],
                'A->1'  => [ 'prepare_hmm_profiles_post_thresholding' ],
            },
        },

        {   -logic_name           => 'prepare_hmm_profiles_post_thresholding',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PrepareHmmProfiles',
            -rc_name            => '1Gb_job',
            -max_retry_count    => 0,
            -parameters         => {
                                    'library_name'      => $self->o('compara_hmm_library_name'),
                                    'hmmer_home'        => $self->o('hmmer3_home'),
                                    'readme_file'       => $self->o('readme_file'),
                                    'store_in_warehouse'=> 1,
                                    'target_compara_hmm_lib'   => $self->o('target_compara_hmm_library_basedir'),
                                    'worker_compara_hmm_lib'   => $self->o('worker_compara_hmm_library_basedir'),

            },
        },

        {  -logic_name => 'build_HMM_with_tags',
           -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',

           -parameters => {
                            'hmmer_home'               => $self->o('hmmer3_home'),
                            'hmmer_version'            => 3,
                            'check_split_genes'        => 1,
                            'cdna'                     => 0,
                            'include_thresholds'       => 1,
                            'check_split_genes'        => 1,
           },

           -hive_capacity => $self->o('build_hmm_capacity'),
           -batch_size    => 5,
           -priority      => -20,
           -rc_name       => '1Gb_job',
           -flow_into     => {
               -1 => 'build_HMM_with_tags_himem',
           },
        },

        {   -logic_name     => 'build_HMM_with_tags_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                            'hmmer_home'            => $self->o('hmmer3_home'),
                            'hmmer_version'         => 3,
                            'check_split_genes'     => 1,
                            'cdna'                  => 0,
                            'include_thresholds'    => 1,
                            'check_split_genes'     => 1,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -priority       => -15,
            -rc_name        => '4Gb_job',
        },

        #-----------------------------------------------------------------------------------------------

    ];
}

1;

