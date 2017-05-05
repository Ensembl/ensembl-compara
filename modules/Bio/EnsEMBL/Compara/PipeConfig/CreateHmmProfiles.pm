=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf

=head1 DESCRIPTION

    The PipeConfig file for Creating HMM profiles pipeline.
    This pipeline fetches the PANTHER profiles and perform Hmmer searches to classify our sequences and then build the new HMMs.
    These families are then filtered and processed.


=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. make sure that all default_options are set correctly

    #3. make sure the PANTHER source is correct

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CreateHmmProfiles -password <your_password> -mlss_id <your_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::CreateHmmProfiles;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # User details
        'email'                 => $self->o('ENV', 'USER').'@ebi.ac.uk',
 
    # names of species we don't want to reuse this time
    'do_not_reuse_list'     => [ ],

    # where to find the list of Compara methods. Unlikely to be changed
    'method_link_dump_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/method_link.txt',

    # custom pipeline name, in case you don't like the default one
        # 'rel_with_suffix' is the concatenation of 'ensembl_release' and 'rel_suffix'
        #'pipeline_name'        => 'protein_trees_'.$self->o('rel_with_suffix'),
        # Tag attached to every single tree
        'division'              => undef,

    #default parameters for the geneset qc

        'coverage_threshold' => 50, #percent
        'species_threshold'  => '#expr(#species_count#/2)expr#', #half of ensembl species

    # dependent parameters: updating 'base_dir' should be enough
        'work_dir'              =>  '/nfs/panda/ensembl/production/'.$self->o('ENV', 'USER').'/compara/'.$self->o('pipeline_name'),
        'exe_dir'               =>  '/nfs/panda/ensemblgenomes/production/compara/binaries',
        'fasta_dir'             => $self->o('work_dir') . '/blast_db',  # affects 'dump_subset_create_blastdb' and 'blastp'
        'cluster_dir'           => $self->o('work_dir') . '/cluster',
        'dump_dir'              => $self->o('work_dir') . '/dumps',

    # "Member" parameters:
        'allow_ambiguity_codes'     => 0,
        'allow_missing_coordinates' => 0,
        'allow_missing_cds_seqs'    => 0,
        # highest member_id for a protein member
        'protein_members_range'     => 100000000,
        # Genes with these logic_names will be ignored from the pipeline.
        # Format is { genome_db_id (or name) => [ 'logic_name1', 'logic_name2', ... ] }
        # An empty string can also be used as the key to define logic_names excluded from *all* species
        'exclude_gene_analysis'     => {},

    # blast parameters:
    # Important note: -max_hsps parameter is only available on ncbi-blast-2.3.0 or higher.

        # define blast parameters and evalues for ranges of sequence-length
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
        'gene_blacklist_file'           => '/dev/null',

    # tree building parameters:
        'use_quick_tree_break'      => 1,

        'treebreak_gene_count'      => 400,
        'split_genes_gene_count'    => 5000,

        'mcoffee_short_gene_count'  => 20,
        'mcoffee_himem_gene_count'  => 250,
        'mafft_gene_count'          => 300,
        'mafft_himem_gene_count'    => 400,
        'mafft_runtime'             => 7200,
        'treebest_threshold_n_residues' => 10000,
        'treebest_threshold_n_genes'    => 400,
        'update_threshold_trees'    => 0.2,

    # sequence type used on the phylogenetic inferences
    # It has to be set to 1 for the strains
        'use_dna_for_phylogeny'     => 0,
        #'use_dna_for_phylogeny'     => 1,

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

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'codeml_parameters_file'    => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/protein_trees.codeml.ctl.hash',
        'taxlevels'                 => [],
        # affects 'group_genomes_under_taxa'
        'filter_high_coverage'      => 0,

    # mapping parameters:
        'do_stable_id_mapping'      => 0,
        'do_treefam_xref'           => 0,
        # The TreeFam release to map to
        'tf_release'                => undef,

    # executable locations:
        'hcluster_exe'              => $self->o('exe_dir').'/hcluster_sg',
        'mcoffee_home'              => '/nfs/panda/ensemblgenomes/external/t-coffee',
        'mafft_home'                => '/nfs/panda/ensemblgenomes/external/mafft',
        'treebest_exe'              => $self->o('exe_dir').'/treebest',
        'notung_jar'                => '/nfs/production/xfam/treefam/software/Notung/Notung-2.6/Notung-2.6.jar',
        'quicktree_exe'             => $self->o('exe_dir').'/quicktree',
        'hmmer2_home'               => '/software/ensembl/compara/hmmer-2.3.2/src/',
        'hmmer3_home'               => '/homes/mateus/create_hmm_pipeline/hmmer/hmmer-3.1b2-linux-intel-x86_64/binaries',
        'codeml_exe'                => $self->o('exe_dir').'/codeml',
        'ktreedist_exe'             => $self->o('exe_dir').'/ktreedist',
        'blast_bin_dir'             => '/nfs/panda/ensemblgenomes/external/ncbi-blast-2.3.0+/bin/',
        'pantherScore_path'         => '/nfs/production/xfam/treefam/software/pantherScore1.03/',
        'trimal_exe'                => '/nfs/production/xfam/treefam/software/trimal/source/trimal',
        'noisy_exe'                 => '/nfs/production/xfam/treefam/software/Noisy-1.5.12/noisy',
        'getPatterns_exe'           => '/nfs/production/xfam/treefam/software/RAxML/number_of_patterns/getPatterns',
        'fasttree_mp_exe'           => '/nfs/production/xfam/treefam/software/FastTree/FastTreeMP',
        'prottest_jar'              => '/nfs/production/xfam/treefam/software/ProtTest/prottest-3.4-20140123/prottest-3.4.jar',
        'cafe_shell'                => 'UNDEF',

        # HMM specific parameters
        # The location of the HMM library:
        'hmm_library_basedir'       => '/nfs/panda/ensembl/production/mateus/compara/hmm_panther_11/',
        'min_num_members'           => 4,
        'min_num_species'           => 2,
        'min_taxonomic_coverage'    => 0.5,
        'min_ratio_species_genes'   => 0.5,
        'max_gappiness'             => 0.95,

        #name of the profile to be created:
        'hmm_library_name'          => 'panther_11_1.hmm3',
        
        #URL to find the PANTHER profiles:
        'panther_url'               => 'ftp://ftp.pantherdb.org/panther_library/current_release/',

        #File name in the 'panther_url':
        'panther_file'              => 'PANTHER11.1_hmmscoring.tgz',

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
        'reuse_capacity'            =>  10,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 200,
        'blastpu_capacity'          => 150,
        'mcoffee_capacity'          => 200,
        'split_genes_capacity'      => 400,
        'alignment_filtering_capacity'  => 200,
        'filter_1_capacity'         => 50,
        'filter_2_capacity'         => 50,
        'filter_3_capacity'         => 50,
        'cluster_tagging_capacity'  => 200,
        'loadtags_capacity'         => 200,
        'treebest_capacity'         => 500,
        'copy_tree_capacity'        => 100,
        'ortho_tree_capacity'       => 200,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 100,
        'ktreedist_capacity'        => 150,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 200,
        'hc_capacity'               =>   4,
        'decision_capacity'         =>   4,
        'hc_post_tree_capacity'     => 100,
        'HMMer_classify_capacity'   => 400,
		'HMMer_classifyPantherScore_capacity'=> 1000,
		'HMMer_search_capacity'     => 1000,
        'loadmembers_capacity'      => 30,
        'copy_trees_capacity'       => 50,
        'copy_alignments_capacity'  => 50,
        'mafft_update_capacity'     => 50,
        'ortho_stats_capacity'      => 10,

    # hive priority for non-LOCAL health_check analysis:
        'hc_priority'               => -10,

    # connection parameters to various databases:

        # Uncomment and update the database locations
        eg_prod=> {
            -host => 'mysql-eg-prod-1.ebi.ac.uk',
            -port => 4238,
            -user => 'ensro',
            #-verbose => 1,
            -db_version => 30,
        },

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'mysql-ens-sta-1',
            -port   => 4519,
            -user   => 'ensro',
            -pass   => '',
            # This value works in production. Change it if you want to run the pipeline in another context, but don't commit the change !
            -db_version => Bio::EnsEMBL::ApiVersion::software_version()-1,
        },

        # Production database (for the biotypes)
        'production_db_url'     => 'mysql://ensro@mysql-ens-sta-1:4519/ensembl_production',

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        #'host' => 'mysql-ens-compara-prod-2.ebi.ac.uk',
        'host' => 'mysql-ens-compara-prod-2:4522',

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        #'master_db' => 'mysql://ensro@compara1:3306/mm14_ensembl_compara_master',
        'master_db' => 'mysql://ensro@mysql-treefam-prod.ebi.ac.uk:4401/treefam_master',
        'ncbi_db'   => $self->o('master_db'),
        'master_db_is_missing_dnafrags' => 0,


        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        #'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],
        'curr_core_sources_locs'    => [ $self->o('livemirror_loc') ],
        'curr_core_registry'        => undef,
        'curr_file_sources_locs'    => [  ],    # It can be a list of JSON files defining an additionnal set of species

        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('livemirror_loc') ],
        #'prev_core_sources_locs'   => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],

        # Add the database location of the previous Compara release. Leave commented out if running the pipeline without reuse
        # NOTE: This most certainly has to change every-time you run the pipeline. Only commit the change if it's the production run
        'prev_rel_db' => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_protein_trees_88',

        # By default, the stable ID mapping is done on the previous release database
        'mapping_db'  => $self->o('prev_rel_db'),

    # Configuration of the pipeline worklow

        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   'ortholog' means that the pipeline will use previously inferred orthologs to perform a cluster projection
        #   'hmm' means that the pipeline will run an HMM classification
        #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
        #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<
        'clustering_mode'           => 'hybrid',

        # How much the pipeline will try to reuse from "prev_rel_db"
        # Possible values: 'clusters' (default), 'blastp', 'members'
        #   'members' means that only the members are copied over, and the rest will be re-computed
        #   'hmms' is like 'members', but also copies the HMM profiles. It requires that the clustering mode is not 'blastp'  >> UNIMPLEMENTED <<
        #   'hmm_hits' is like 'hmms', but also copies the HMM hits  >> UNIMPLEMENTED <<
        #   'blastp' is like 'members', but also copies the blastp hits. It requires that the clustering mode is 'blastp'
        #   'ortholog' the orthologs will be copied from the reuse db
        #   'clusters' is like 'hmm_hits' or 'blastp' (depending on the clustering mode), but also copies the clusters
        #   'alignments' is like 'clusters', but also copies the alignments  >> UNIMPLEMENTED <<
        #   'trees' is like 'alignments', but also copies the trees  >> UNIMPLEMENTED <<
        #   'homologies is like 'trees', but also copies the homologies  >> UNIMPLEMENTED <<
        'reuse_level'               => 'members',

        # If all the species can be reused, and if the reuse_level is "clusters" or above, do we really want to copy all the peptide_align_feature / hmm_profile tables ? They can take a lot of space and are not used in the pipeline
        'quick_reuse'   => 1,

    };
}


# This section has to be filled in any derived class
sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         '250Mb_job'        => {'LSF' => '-C0 -M250   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'        => {'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'          => {'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'          => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '4Gb_job'          => {'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
         '4Gb_big_tmp_job'  => {'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000,tmp=102400]"' },
         '8Gb_job'          => {'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
         '16Gb_job'         => {'LSF' => '-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"' },
         '32Gb_job'         => {'LSF' => '-C0 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
    };
}



sub pipeline_create_commands {
    my ($self) = @_;

    # There must be some species on which to compute trees
    die "There must be some species on which to compute trees"
        if ref $self->o('curr_core_sources_locs') and not scalar(@{$self->o('curr_core_sources_locs')})
        and ref $self->o('curr_file_sources_locs') and not scalar(@{$self->o('curr_file_sources_locs')})
        and not $self->o('curr_core_registry');

    # The master db must be defined to allow mapping stable_ids and checking species for reuse
    die "The master dabase must be defined with a mlss_id" if $self->o('master_db') and not $self->o('mlss_id');
    die "mlss_id can not be defined in the absence of a master dabase" if $self->o('mlss_id') and not $self->o('master_db');
    die "Mapping of stable_id is only possible with a master database" if $self->o('do_stable_id_mapping') and not $self->o('master_db');
    die "Species reuse is only possible with a master database" if $self->o('prev_rel_db') and not $self->o('master_db');
    die "Species reuse is only possible with some previous core databases" if $self->o('prev_rel_db') and ref $self->o('prev_core_sources_locs') and not scalar(@{$self->o('prev_core_sources_locs')});

    # Without a master database, we must provide other parameters
    die if not $self->o('master_db') and not $self->o('ncbi_db');

    my %reuse_modes = (clusters => 1, blastp => 1, members => 1);
    die "'reuse_level' must be set to one of: clusters, blastp, members" if not $self->o('reuse_level') or (not $reuse_modes{$self->o('reuse_level')} and not $self->o('reuse_level') =~ /^#:subst/);
    my %clustering_modes = (blastp => 1, ortholog => 1, hmm => 1, hybrid => 1, topup => 1);
    die "'clustering_mode' must be set to one of: blastp, ortholog, hmm, hybrid or topup" if not $self->o('clustering_mode') or (not $clustering_modes{$self->o('clustering_mode')} and not $self->o('clustering_mode') =~ /^#:subst/);

    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables

        'rm -rf '.$self->o('cluster_dir'),
        'mkdir -p '.$self->o('cluster_dir'),
        'mkdir -p '.$self->o('dump_dir'),
        'mkdir -p '.$self->o('dump_dir').'/pafs',
        'mkdir -p '.$self->o('fasta_dir'),
        'mkdir -p '.$self->o('hmm_library_basedir'),

            # perform "lfs setstripe" only if lfs is runnable and the directory is on lustre:
        'which lfs && lfs getstripe '.$self->o('fasta_dir').' >/dev/null 2>/dev/null && lfs setstripe '.$self->o('fasta_dir').' -c -1 || echo "Striping is not available on this system" ',

    ];
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'master_db'     => $self->o('master_db'),
        'ncbi_db'       => $self->o('ncbi_db'),
        'reuse_db'      => $self->o('prev_rel_db'),
        'mapping_db'    => $self->o('mapping_db'),

        'cluster_dir'   => $self->o('cluster_dir'),
        'fasta_dir'     => $self->o('fasta_dir'),
        'dump_dir'      => $self->o('dump_dir'),
        'hmm_library_basedir'   => $self->o('hmm_library_basedir'),

        'clustering_mode'   => $self->o('clustering_mode'),
        'reuse_level'       => $self->o('reuse_level'),
        'binary_species_tree_input_file'   => $self->o('binary_species_tree_input_file'),
        'all_blast_params'          => $self->o('all_blast_params'),

        'use_quick_tree_break'   => $self->o('use_quick_tree_break'),
        'do_stable_id_mapping'   => $self->o('do_stable_id_mapping'),
        'do_treefam_xref'   => $self->o('do_treefam_xref'),
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

    return [

# ---------------------------------------------[backbone]--------------------------------------------------------------------------------

        {   -logic_name => 'backbone_fire_db_prepare',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions',
            -input_ids  => [ { } ],
            -flow_into  => {
                '1->A'  => [ 'copy_ncbi_tables_factory' ],
                'A->1'  => [ 'backbone_fire_genome_load' ],
            },
        },

        {   -logic_name => 'backbone_fire_genome_load',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'output_file'   => '#dump_dir#/snapshot_1_before_genome_load.sql.gz',
                'quick_reuse'   => $self->o('quick_reuse'),
            },
            -flow_into  => {
                '1->A'  => [ 'dnafrag_reuse_factory' ],
                'A->1'  => [ 'backbone_fire_clustering' ],
            },
        },

        {   -logic_name => 'backbone_fire_clustering',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature_%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_3_before_clustering.sql.gz',
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
                'output_file'   => '#dump_dir#/snapshot_4_before_tree_building.sql.gz',
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
                'A->1' => WHEN(
                    '#master_db#' => 'populate_method_links_from_db',
                    ELSE 'populate_method_links_from_file',
                ),
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

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => '#master_db#',   # that's where genome_db_ids come from
                'mlss_id'           => $self->o('mlss_id'),
                'extra_parameters'  => [ 'locator' ],
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
            -parameters => {
                'registry_conf_file'  => $self->o('curr_core_registry'),
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
                'db_version'    => $self->o('ensembl_release'),
                'registry_files'    => $self->o('curr_file_sources_locs'),
            },
            -rc_name => '4Gb_job',
            -flow_into  => [ 'check_reusability' ],
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
            -flow_into      => [ 'load_all_genomedbs_from_registry' ],
        },

        {   -logic_name => 'load_all_genomedbs_from_registry',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadAllGenomeDBsFromRegistry',
            -parameters => {
                'registry_conf_file'  => $self->o('curr_core_registry'),
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
                'db_version'    => $self->o('ensembl_release'),
                'registry_files'    => $self->o('curr_file_sources_locs'),
            },
            -flow_into => [ 'create_mlss_ss' ],
        },
# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability',
            -parameters => {
                'registry_dbs'      => $self->o('prev_core_sources_locs'),
                'do_not_reuse_list' => $self->o('do_not_reuse_list'),
            },
            -batch_size => 5,
            -hive_capacity => 30,
            -rc_name => '8Gb_job',
            -flow_into => {
                2 => '?accu_name=reused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
                3 => '?accu_name=nonreused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
            },
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PrepareSpeciesSetsMLSS',
            -rc_name => '2Gb_job',
            -flow_into => {
                1 => [ 'make_treebest_species_tree' ],
                2 => [ 'check_reuse_db_is_myisam', 'check_reuse_db_is_patched' ],
            },
        },

        {   -logic_name => 'check_reuse_db_is_myisam',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'db_conn'       => '#reuse_db#',
                'description'   => q{The pipeline can only reuse the "other_member_sequence" table if it is in MyISAM. So please run the following MySQL commands on the #reuse_db#: SET FOREIGN_KEY_CHECKS = 0; ALTER TABLE other_member_sequence DROP FOREIGN KEY other_member_sequence_ibfk_1; ALTER TABLE other_member_sequence ENGINE=MyISAM; },
                'query'         => 'SHOW TABLE STATUS WHERE Name = "other_member_sequence" AND Engine NOT LIKE "MyISAM" -- limit',      # -- limit is a trick to ask SqlHealthcheck not to add "LIMIT 1" at the end of the query
            },
        },

        {   -logic_name => 'check_reuse_db_is_patched',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions',
            -parameters => {
                'db_conn'       => '#reuse_db#',
            },
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
                'tree_fmt'      => '%{-x"*"}:%{d}',
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

        {   -logic_name => 'dnafrag_reuse_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'species_set_id'    => '#reuse_ss_id#',
            },
            -flow_into => {
                '2->A' => [ 'dnafrag_table_reuse' ],
                'A->1' => [ 'nonpolyploid_genome_reuse_factory' ],
            },
        },

        {   -logic_name => 'nonpolyploid_genome_reuse_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'component_genomes' => 0,
                'species_set_id'    => '#reuse_ss_id#',
            },
            -flow_into => {
                '2->A' => [ 'sequence_table_reuse' ],
                'A->1' => [ 'polyploid_genome_reuse_factory' ],
            },
        },

        {   -logic_name => 'polyploid_genome_reuse_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'component_genomes' => 0,
                'normal_genomes'    => 0,
                'species_set_id'    => '#reuse_ss_id#',
            },
            -flow_into => {
                '2->A' => [ 'component_genome_dbs_move_factory' ],
                'A->1' => [ 'nonpolyploid_genome_load_fresh_factory' ],
            },
        },

        {   -logic_name => 'component_genome_dbs_move_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComponentGenomeDBFactory',
            -flow_into => {
                '2->A' => {
                    'move_component_genes' => { 'source_gdb_id' => '#principal_genome_db_id#', 'target_gdb_id' => '#component_genome_db_id#'}
                },
                'A->1' => [ 'hc_polyploid_genes' ],
            },
        },

        {   -logic_name => 'move_component_genes',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MoveComponentGenes',
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => {
                    'hc_members_per_genome' => { 'genome_db_id' => '#target_gdb_id#' },
                },
            },
        },

        {   -logic_name => 'hc_polyploid_genes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'description'   => 'All the genes of the polyploid species should be moved to the component genomes',
                'query'         => 'SELECT * FROM gene_member WHERE genome_db_id = #genome_db_id#',
            },
            %hc_analysis_params,
        },


        {   -logic_name => 'sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => '#reuse_db#',
                            'inputquery' => 'SELECT s.* FROM sequence s JOIN seq_member USING (sequence_id) WHERE sequence_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_name => '500Mb_job',
            -flow_into => {
                2 => [ '?table_name=sequence' ],
                1 => [ 'seq_member_table_reuse' ],
            },
        },

        {   -logic_name => 'dnafrag_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#reuse_db#',
                'table'         => 'dnafrag',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
        },

        {   -logic_name => 'seq_member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#reuse_db#',
                'table'         => 'seq_member',
                'where'         => 'seq_member_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'gene_member_table_reuse' ],
            },
        },

        {   -logic_name => 'gene_member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#reuse_db#',
                'table'         => 'gene_member',
                'where'         => 'gene_member_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'other_sequence_table_reuse' ],
            },
        },

        {   -logic_name => 'other_sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => '#reuse_db#',
                            'inputquery' => 'SELECT s.seq_member_id, s.seq_type, s.length, s.sequence FROM other_member_sequence s JOIN seq_member USING (seq_member_id) WHERE genome_db_id = #genome_db_id# AND seq_type IN ("cds", "exon_bounded") AND seq_member_id <= '.$self->o('protein_members_range'),
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_name => '4Gb_job',
            -flow_into => {
                2 => [ '?table_name=other_member_sequence' ],
                1 => [ 'hmm_annot_table_reuse' ],
            },
        },

        {   -logic_name => 'hmm_annot_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => '#reuse_db#',
                            'inputquery' => 'SELECT h.* FROM hmm_annot h JOIN seq_member USING (seq_member_id) WHERE genome_db_id = #genome_db_id# AND seq_member_id <= '.$self->o('protein_members_range'),
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_name => '1Gb_job',
            -flow_into => {
                2 => [ '?table_name=hmm_annot' ],
                1 => [ 'hc_members_per_genome' ],
            },
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_per_genome',
                allow_ambiguity_codes => $self->o('allow_ambiguity_codes'),
                allow_missing_coordinates   => $self->o('allow_missing_coordinates'),
                allow_missing_cds_seqs      => $self->o('allow_missing_cds_seqs'),
            },
            %hc_analysis_params,
        },


# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'nonpolyploid_genome_load_fresh_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'polyploid_genomes' => 0,
                'species_set_id'    => '#nonreuse_ss_id#',
                'extra_parameters'  => [ 'locator' ],
            },
            -flow_into => {
                '2->A' => WHEN(
                    '(#locator# =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/) and  #master_db#' => 'copy_dnafrags_from_master',
                    '(#locator# =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/) and !#master_db#' => 'load_fresh_members_from_db',
                    ELSE 'load_fresh_members_from_file',
                ),
                'A->1' => [ 'polyploid_genome_load_fresh_factory' ],
            },
        },

        {   -logic_name => 'polyploid_genome_load_fresh_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'component_genomes' => 0,
                'normal_genomes'    => 0,
                'species_set_id'    => '#nonreuse_ss_id#',
                'extra_parameters'  => [ 'locator' ],
            },
            -flow_into => {
                '2->A' => WHEN(
                    # Not all the cases are covered
                    '(#locator# =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/) and #master_db#' => 'copy_polyploid_dnafrags_from_master',
                    '!(#locator# =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/)' => 'component_dnafrags_duplicate_factory',
                ),
                'A->1' => [ 'hc_members_globally' ],
            },
        },

        {   -logic_name => 'component_dnafrags_duplicate_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComponentGenomeDBFactory',
            -flow_into => {
                2 => {
                    'duplicate_component_dnafrags' => { 'source_gdb_id' => '#principal_genome_db_id#', 'target_gdb_id' => '#component_genome_db_id#'}
                },
            },
        },

        {   -logic_name => 'duplicate_component_dnafrags',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [
                    'INSERT INTO dnafrag (length, name, genome_db_id, coord_system_name, is_reference) SELECT length, name, #principal_genome_db_id#, coord_system_name, is_reference FROM dnafrag WHERE genome_db_id = #principal_genome_db_id#',
                ],
            },
            -flow_into  => [ 'hc_component_dnafrags' ],
        },

        {   -logic_name => 'copy_polyploid_dnafrags_from_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#master_db#',
                'table'         => 'dnafrag',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into  => [ 'component_dnafrags_hc_factory' ],
        },

        {   -logic_name => 'component_dnafrags_hc_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComponentGenomeDBFactory',
            -flow_into => {
                2 => [ 'hc_component_dnafrags' ],
            },
        },

        {   -logic_name => 'hc_component_dnafrags',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'description'   => 'All the component dnafrags must be in the principal genome',
                'query'         => 'SELECT d1.* FROM dnafrag d1 LEFT JOIN dnafrag d2 ON d2.genome_db_id = #principal_genome_db_id# AND d1.name = d2.name WHERE d1.genome_db_id = #component_genome_db_id# AND d2.dnafrag_id IS NULL',
            },
            %hc_analysis_params,
        },

        {   -logic_name => 'copy_dnafrags_from_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#master_db#',
                'table'         => 'dnafrag',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'load_fresh_members_from_db' ],
        },

        {   -logic_name => 'load_fresh_members_from_db',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {
                'store_related_pep_sequences' => 1,
                'allow_ambiguity_codes'         => $self->o('allow_ambiguity_codes'),
                'find_canonical_translations_for_polymorphic_pseudogene' => 1,
                'store_missing_dnafrags'        => ((not $self->o('master_db')) or $self->o('master_db_is_missing_dnafrags') ? 1 : 0),
                'exclude_gene_analysis'         => $self->o('exclude_gene_analysis'),
            },
            -hive_capacity => $self->o('loadmembers_capacity'),
            -rc_name => '2Gb_job',
            -flow_into => [ 'hc_members_per_genome' ],
        },

        {   -logic_name => 'load_fresh_members_from_file',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembersFromFiles',
            -parameters => {
                'need_cds_seq'  => 1,
            },
            -hive_capacity => $self->o('loadmembers_capacity'),
            -rc_name => '2Gb_job',
            -flow_into => [ 'hc_members_per_genome' ],
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

        { -logic_name     => 'load_PANTHER',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadPanther',
            -rc_name       => '4Gb_big_tmp_job',
            -parameters     => {
                                'hmmer_home'        => $self->o('hmmer3_home'),
                                'library_name'      => $self->o('hmm_library_name'),
                                'hmm_lib'           => $self->o('hmm_library_basedir'),
                                'url'               => $self->o('panther_url'),
                                'file'              => $self->o('panther_file'),
            },
            -flow_into      => [ 'treefam_panther_hmm_overlapping' ],
        },

        { -logic_name     => 'treefam_panther_hmm_overlapping',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HmmOverlap',
            -rc_name       => '4Gb_big_tmp_job',
            -parameters     => {
                                'hmmer_home'        => $self->o('hmmer3_home'),
                                'library_name'      => $self->o('hmm_library_name'),
                                'hmm_lib'           => $self->o('hmm_library_basedir'),
                                'url'               => $self->o('panther_url'),
                                'file'              => $self->o('panther_file'),
            },
            -flow_into      => [ 'HMMer_search_factory' ],
        },

        {   -logic_name => 'HMMer_search_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FactoryUnannotatedMembers',
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
                         'library_name'      => $self->o('hmm_library_name'),
                        },
         -hive_capacity => $self->o('HMMer_search_capacity'),
         -rc_name => '4Gb_job',
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
                        },
         -hive_capacity => $self->o('HMMer_search_capacity'),
         -rc_name => '8Gb_job',
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
                        },
         -hive_capacity => $self->o('HMMer_search_capacity'),
         -rc_name => '32Gb_job',
        },

            {
             -logic_name => 'HMM_clusterize',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClusterize',
             -parameters => {
                 'division'     => $self->o('division'),
                 'extra_tags_file'  => $self->o('extra_model_tags_file'),
                 'only_canonical'   => 1,
             },
             -rc_name => '8Gb_job',
             -flow_into      => [ 'dump_unannotated_members' ],
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
            -rc_name       => '1Gb_job',
            -flow_into  => [ 'unannotated_all_vs_all_factory' ],
        },

        {   -logic_name => 'unannotated_all_vs_all_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastFactoryUnannotatedMembers',
            -rc_name       => '250Mb_job',
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
                'blast_params'              => "#expr( #all_blast_params#->[#param_index#]->[2])expr#",
                'blast_bin_dir'             => $self->o('blast_bin_dir'),
                'evalue_limit'              => "#expr( #all_blast_params#->[#param_index#]->[3])expr#",
            },
            -rc_name       => '250Mb_job',
            -flow_into => {
               -1 => [ 'blastp_unannotated_himem' ],  # MEMLIMIT
            },
            -hive_capacity => $self->o('blastpu_capacity'),
        },

        {   -logic_name         => 'blastp_unannotated_himem',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastpUnannotated',
            -parameters         => {
                'blast_db'                  => '#fasta_dir#/unannotated.fasta',
                'blast_params'              => "#expr( #all_blast_params#->[#param_index#]->[2])expr#",
                'blast_bin_dir'             => $self->o('blast_bin_dir'),
                'evalue_limit'              => "#expr( #all_blast_params#->[#param_index#]->[3])expr#",
            },
            -rc_name       => '1Gb_job',
            -hive_capacity => $self->o('blastpu_capacity'),
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
                'A->1' => [ 'remove_blacklisted_genes' ],
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
            -parameters => {
                'division'                  => $self->o('division'),
            },
            -rc_name => '2Gb_job',
        },

        {   -logic_name     => 'cluster_tagging',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ClusterTagging',
            -hive_capacity  => $self->o('cluster_tagging_capacity'),
            -rc_name    	=> '4Gb_job',
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


        {   -logic_name         => 'remove_blacklisted_genes',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveBlacklistedGenes',
            -parameters         => {
                blacklist_file      => $self->o('gene_blacklist_file'),
            },
            -flow_into          => [ 'create_additional_clustersets' ],
            -rc_name => '500Mb_job',
        },

        {   -logic_name         => 'create_additional_clustersets',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets',
            -parameters         => {
                member_type     => 'protein',
                'additional_clustersets'    => [qw(treebest phyml-aa phyml-nt nj-dn nj-ds nj-mm raxml raxml_parsimony raxml_bl notung copy raxml_update filter_level_1 filter_level_2 filter_level_3 fasttree )],
            },
        },


# ---------------------------------------------[Pluggable QC step]----------------------------------------------------------

        {   -logic_name    => 'clusterset_backup',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => 'INSERT IGNORE INTO gene_tree_backup (seq_member_id, root_id) SELECT seq_member_id, root_id FROM gene_tree_node WHERE seq_member_id IS NOT NULL',
            },
            -flow_into     => {
                1 => [
                    'create_additional_clustersets',
                    'cluster_tagging_factory',
                ],
            },
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
                'inputquery'        => 'SELECT root_id AS gene_tree_id, COUNT(seq_member_id) AS tree_num_genes FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "tree" AND clusterset_id="default" GROUP BY root_id',
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
                '2->A' => WHEN (
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
            -flow_into  => [
                'write_stn_tags',
                WHEN(
                    '#do_stable_id_mapping#' => 'stable_id_mapping',
                    ELSE 'build_HMM_factory',
                ),
                WHEN('#do_treefam_xref#' => 'treefam_xref_idmap'),
            ],
            %hc_analysis_params,
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
                'subject' => "CreateHmmProfiles Pipeline: ( #expr(\$self->hive_pipeline->display_name)expr# ) Gene tree report",
            },
        },


# ---------------------------------------------[Pluggable MSA steps]----------------------------------------------------------

        {   -logic_name => 'mcoffee_short',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                => 'cmcoffee',
                'mcoffee_home'          => $self->o('mcoffee_home'),
                'mafft_home'            => $self->o('mafft_home'),
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
                'method'                => 'cmcoffee',
                'mcoffee_home'          => $self->o('mcoffee_home'),
                'mafft_home'            => $self->o('mafft_home'),
                'escape_branch'         => -1,
            },
            -analysis_capacity    => $self->o('mcoffee_capacity'),
            -rc_name    => '2Gb_job',
            -flow_into => {
               -1 => [ 'mcoffee_himem' ],  # MEMLIMIT
               -2 => [ 'mafft' ],
            },
        },

        {   -logic_name => 'mafft',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_home'                 => $self->o('mafft_home'),
                'escape_branch'              => -1,
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '2Gb_job',
            -flow_into => {
               -1 => [ 'mafft_himem' ],  # MEMLIMIT
            },
        },

        {   -logic_name => 'mcoffee_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                => 'cmcoffee',
                'mcoffee_home'          => $self->o('mcoffee_home'),
                'mafft_home'            => $self->o('mafft_home'),
                'escape_branch'         => -2,
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '8Gb_job',
            -flow_into => {
               -1 => [ 'mafft_himem' ],
               -2 => [ 'mafft_himem' ],
            },
        },

        {   -logic_name => 'mafft_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
            -parameters => {
                'mafft_home'                 => $self->o('mafft_home'),
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_name    => '8Gb_job',
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
            -flow_into  => {
                1 => WHEN(
                     '(#tree_gene_count# <= #threshold_n_genes#) || (#tree_aln_length# <= #threshold_aln_len#)' => 'filter_level_2',
                     '(#tree_gene_count# >= #threshold_n_genes_large# and #tree_aln_length# > #threshold_aln_len#) || (#tree_aln_length# >= #threshold_aln_len_large# and #tree_gene_count# > #threshold_n_genes#)' => 'noisy_large',
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
            -flow_into      => [ 'filter_level_2' ],
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
            -flow_into      => [ 'filter_level_2' ],
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
            get identities from: http://search.cpan.org/dist/BioPerl/Bio/SimpleAlign.pm#average_percentage_identity
            -parameters         => {
                'max_gappiness'           => $self->o('max_gappiness'),
                'fasttree_exe'            => $self->o('fasttree_mp_exe'),
                'treebest_exe'            => $self->o('treebest_exe'),
                'output_clusterset_id'    => 'fasttree',
                'input_clusterset_id'     => 'default',
            },
            -hive_capacity  => $self->o('filter_3_capacity'),
            -rc_name 		=> '2Gb_job',
            -batch_size     => 5,
        },

# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

# ---------------------------------------------[alignment filtering]-------------------------------------------------------------

# ---------------------------------------------[small trees decision]-------------------------------------------------------------

# ---------------------------------------------[model test]-------------------------------------------------------------
           
# ---------------------------------------------[tree building with treebest]-------------------------------------------------------------
           
# ---------------------------------------------[tree building with raxml]-------------------------------------------------------------
  
# ---------------------------------------------[tree reconciliation / rearrangements]-------------------------------------------------------------

# ---------------------------------------------[build HMMs]-------------------------------------------------------------

        {   -logic_name => 'build_HMM_aa_v3',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'hmmer_home'        => $self->o('hmmer2_home'),
                'hmmer_version'     => 2,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -batch_size     => 5,
            -priority       => -20,
            -rc_name        => '250Mb_job',
            -flow_into      => {
                -1  => 'build_HMM_aa_v3_himem'
            },
        },

        {   -logic_name     => 'build_HMM_aa_v3_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                'hmmer_home'        => $self->o('hmmer2_home'),
                'hmmer_version'     => 2,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -priority       => -20,
            -rc_name        => '1Gb_job',
        },

        {   -logic_name => 'build_HMM_cds_v3',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'cdna'              => 1,
                'hmmer_home'        => $self->o('hmmer2_home'),
                'hmmer_version'     => 2,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -batch_size     => 5,
            -priority       => -20,
            -rc_name        => '500Mb_job',
            -flow_into      => {
                -1  => 'build_HMM_cds_v3_himem'
            },
        },

        {   -logic_name     => 'build_HMM_cds_v3_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                'cdna'              => 1,
                'hmmer_home'        => $self->o('hmmer2_home'),
                'hmmer_version'     => 2,
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -priority       => -20,
            -rc_name        => '2Gb_job',
        },

# ---------------------------------------------[Quick tree break steps]-----------------------------------------------------------------------

# -------------------------------------------[name mapping step]---------------------------------------------------------------------

        {
            -logic_name => 'stable_id_mapping',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper',
            -parameters => {
                'prev_rel_db'   => '#mapping_db#',
                'type'          => 't',
            },
            -flow_into          => [ 'hc_stable_id_mapping' ],
            -rc_name => '1Gb_job',
        },

        {   -logic_name         => 'hc_stable_id_mapping',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'stable_id_mapping',
            },
            -flow_into  => [ 'build_HMM_factory' ],
            %hc_analysis_params,
        },

        {   -logic_name    => 'treefam_xref_idmap',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper',
            -parameters    => {
                'tf_release'  => $self->o('tf_release'),
                'tag_prefix'  => '',
            },
            -rc_name => '1Gb_job',
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
    ];
}

sub pipeline_analyses {
    my $self = shift;

    ## The analysis defined in this file
    my $all_analyses = $self->core_pipeline_analyses(@_);
    ## We add some more analyses
    push @$all_analyses, @{$self->extra_analyses(@_)};

    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$all_analyses;
    $self->tweak_analyses(\%analyses_by_name);

    return $all_analyses;
}


## The following methods can be redefined to add more analyses / remove some, and change the parameters of some core ones
sub extra_analyses {
    my $self = shift;
    return [
    ];
}

sub analyses_to_remove {
    return [];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;
}

1;

