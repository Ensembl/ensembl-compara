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

Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf

=head1 DESCRIPTION

    The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.5;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::GOC;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneSetQC;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # User details
        #'email'                 => 'john.smith@example.com',

    # parameters inherited from EnsemblGeneric_conf and very unlikely to be redefined:
        # It defaults to Bio::EnsEMBL::ApiVersion::software_version()
        #'ensembl_release'       => 88,

    # parameters that are likely to change from execution to another:
        # It is very important to check that this value is current (commented out to make it obligatory to specify)
        #'mlss_id'               => 40077,
        # Change this one to allow multiple runs
        #'rel_suffix'            => 'b',

       #production run or test/development run
       
        'test_mode' => 1, 
        # names of species we don't want to reuse this time
        'do_not_reuse_list'     => [ ],

        # where to find the list of Compara methods. Unlikely to be changed
        'method_link_dump_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/method_link.txt',

    # custom pipeline name, in case you don't like the default one
        # 'rel_with_suffix' is the concatenation of 'ensembl_release' and 'rel_suffix'
        #'pipeline_name'        => 'protein_trees_'.$self->o('rel_with_suffix'),
        # Tag attached to every single tree
        #'division'              => undef,

    # Parameters to allow merging different runs of the pipeline
        'dbID_range_index'      => undef,
        'label_prefix'          => undef,

    #default parameters for the geneset qc
        'coverage_threshold' => 50, #percent
        'species_threshold'  => '#expr(#species_count#/2)expr#', #half of ensembl species

    # dependent parameters: updating 'base_dir' should be enough
        # Note that you can omit the trailing / in base_dir if you want 'pipeline_name' to be added as a suffix
        'work_dir'              => $self->o('base_dir') . $self->o('pipeline_name'),
        'fasta_dir'             => $self->o('work_dir') . '/blast_db',  # affects 'dump_subset_create_blastdb' and 'blastp'
        'cluster_dir'           => $self->o('work_dir') . '/cluster',
        'dump_dir'              => $self->o('work_dir') . '/dumps',
        'examl_dir'             => $self->o('work_dir') . '/examl',

    # "Member" parameters:
        'allow_ambiguity_codes'     => 0,
        'allow_missing_coordinates' => 0,
        'allow_missing_cds_seqs'    => 0,

    # blast parameters:
        'num_sequences_per_blast_job'   => 500,

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
        'gene_blacklist_file'           => '/dev/null',

    # tree building parameters:
        'use_raxml'                 => 0,
        'use_notung'                => 0,
        'use_treerecs'              => 0,
        'do_model_selection'        => 0,
        'use_quick_tree_break'      => 1,

        'treebreak_gene_count'      => 400,
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

    # HMM specific parameters (set to 0 or undef if not in use)
       'hmm_library_basedir'       => undef,

       # Dumps coming from InterPro
       'panther_annotation_file'    => '/dev/null',
       #'panther_annotation_file' => '/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/panther_Interpro_annot_v8_1/loose_dummy.txt',

       # A file that holds additional tags we want to add to the HMM clusters (for instance: Best-fit models)
        'extra_model_tags_file'     => undef,

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   3,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 900,
        'blastpu_capacity'          => 150,
        'mcoffee_capacity'          => 600,
        'split_genes_capacity'      => 600,
        'alignment_filtering_capacity'  => 400,
        'cluster_tagging_capacity'  => 200,
        'prottest_capacity'         => 400,
        'treebest_capacity'         => 400,
        'raxml_capacity'            => 400,
        'examl_capacity'            => 400,
        'copy_tree_capacity'        => 100,
        'notung_capacity'           => 400,
        'ortho_tree_capacity'       => 200,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 200,
        'ktreedist_capacity'        => 150,
        'goc_capacity'              => 30,
        'goc_stats_capacity'        => 5,
        'genesetQC_capacity'        => 100,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 1500,
        'hc_capacity'               =>   4,
        'decision_capacity'         =>   4,
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

    # hive priority for non-LOCAL health_check analysis:
        'hc_priority'               => -10,

    # prioriy for running TreeBest himem:
        'treebest_long_himem_priority' => 20,

    #default maximum retry count:
        'hive_default_max_retry_count' => 1,

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        #'host' => 'compara1',

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        #'master_db' => 'mysql://ensro@compara1:3306/mm14_ensembl_compara_master',
        'master_db' => undef,
        'ncbi_db'   => $self->o('master_db'),

        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        #'prev_rel_db' => 'mysql://ensro@compara3:3306/mm14_compara_homology_67'
        'prev_rel_db' => undef,
        # By default, the stable ID mapping is done on the previous release database
        'mapping_db'  => $self->o('prev_rel_db'),

        # Where the members come from (as loaded by the LoadMembers pipeline)
        #'member_db'   => 'mysql://....',

    # Configuration of the pipeline worklow

        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   'ortholog' means that the pipeline will use previously inferred orthologs to perform a cluster projection
        #   'hmm' means that the pipeline will run an HMM classification
        #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
        #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<
        'clustering_mode'           => 'blastp',

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

    # Ortholog-clustering parameters
        'ref_ortholog_db'           => undef,

    # CAFE parameters
        # Do we want to initialise the CAFE part now ?
        'initialise_cafe_pipeline'  => undef,
        'cafe_lambdas'             => '',  # For now, we don't supply lambdas
        'cafe_struct_tree_str'     => '',  # Not set by default
        'full_species_tree_label'  => 'default',
        'per_family_table'         => 1,
        'cafe_species'             => [],
        #Use Timetree divergence times for the GeneTree internal nodes
        'use_timetree_times'        => 0,

    # GOC parameters
        'goc_taxlevels'                 => [],
        'goc_threshold'                 => undef,
        # Defaults to the global reuse database, but can be set differently
        'goc_reuse_db'                  => $self->o('prev_rel_db'),
        'calculate_goc_distribution'    => 1,

    # Extra analyses
        # Export HMMs ?
        'do_hmm_export'                 => 0,
        # Do we want the Gene QC part to run ?
        'do_gene_qc'                    => 0,
        # Do we extract overall statistics for each pair of species ?
        'do_homology_stats'             => 0,
        # Do we need a mapping between homology_ids of this database to another database ?
        # This parameter is automatically set to 1 when the GOC pipeline is going to run with a reuse database
        'do_homology_id_mapping'                 => 0,
    };
}


=head2 RESOURCE CLASSES

# This section has to be filled in any derived class
sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         '250Mb_job'    => {'LSF' => '-C0 -M250   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '4Gb_job'      => {'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
         '8Gb_job'      => {'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
         '16Gb_job'     => {'LSF' => '-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"' },
         '24Gb_job'     => {'LSF' => '-C0 -M24000 -R"select[mem>24000] rusage[mem=24000]"' },
         '32Gb_job'     => {'LSF' => '-C0 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
         '48Gb_job'     => {'LSF' => '-C0 -M48000 -R"select[mem>48000] rusage[mem=48000]"' },
         '64Gb_job'     => {'LSF' => '-C0 -M64000 -R"select[mem>64000] rusage[mem=64000]"' },
         '512Gb_job'     => {'LSF' => '-C0 -M512000 -R"select[mem>512000] rusage[mem=512000]"' },

         '8Gb_8c_job'  => {'LSF' => '-n 8 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]  span[hosts=1]"' },
         '16Gb_8c_job' => {'LSF' => '-n 8 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_8c_job' => {'LSF' => '-n 8 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"' },

         '16Gb_16c_job' => {'LSF' => '-n 16 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_16c_job' => {'LSF' => '-n 16 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"' },
         '64Gb_16c_job' => {'LSF' => '-n 16 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"' },

         '16Gb_32c_job' => {'LSF' => '-n 32 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_32c_job' => {'LSF' => '-n 32 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"' },

         '16Gb_64c_job' => {'LSF' => '-n 64 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_64c_job' => {'LSF' => '-n 64 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"' },
         '256Gb_64c_job' => {'LSF' => '-n 64 -C0 -M256000 -R"select[mem>256000] rusage[mem=256000] span[hosts=1]"' },

         '8Gb_8c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 8 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=8]"' },
         '8Gb_16c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 16 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },
         '8Gb_24c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 24 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=12]"' },
         '8Gb_32c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 32 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },

         '16Gb_64c_mpi' => {'LSF' => '-q parallel -a openmpi -n 64 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=4]"' },

         '32Gb_8c_mpi' => {'LSF' => '-q parallel -a openmpi -n 8 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=8]"' },
         '32Gb_16c_mpi' => {'LSF' => '-q parallel -a openmpi -n 16 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },
         '32Gb_24c_mpi' => {'LSF' => '-q parallel -a openmpi -n 24 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=12]"' },
         '32Gb_32c_mpi' => {'LSF' => '-q parallel -a openmpi -n 32 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },

         '8Gb_long_job'      => {'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"  -q long' },

         '8Gb_64c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 64 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },
         '32Gb_64c_mpi' => {'LSF' => '-q parallel -a openmpi -n 64 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },
    };
}

=cut


sub pipeline_checks_pre_init {
    my ($self) = @_;

    # The master db must be defined to allow mapping stable_ids and checking species for reuse
    die "The master dabase must be defined with a mlss_id" if $self->o('master_db') and not $self->o('mlss_id');
    die "mlss_id can not be defined in the absence of a master dabase" if $self->o('mlss_id') and not $self->o('master_db');
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

        'rm -rf '.$self->o('cluster_dir'),
        'mkdir -p '.$self->o('cluster_dir'),
        'mkdir -p '.$self->o('dump_dir'),
        'mkdir -p '.$self->o('dump_dir').'/pafs',
        'mkdir -p '.$self->o('examl_dir'),
        'mkdir -p '.$self->o('fasta_dir'),

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
        'member_db'     => $self->o('member_db'),
        'reuse_db'      => $self->o('prev_rel_db'),
        'mapping_db'    => $self->o('mapping_db'),

        'cluster_dir'   => $self->o('cluster_dir'),
        'fasta_dir'     => $self->o('fasta_dir'),
        'examl_dir'     => $self->o('examl_dir'),
        'dump_dir'      => $self->o('dump_dir'),
        'hmm_library_basedir'   => $self->o('hmm_library_basedir'),
        'hmm_library_version'   => $self->o('hmm_library_version'),

        'clustering_mode'   => $self->o('clustering_mode'),
        'reuse_level'       => $self->o('reuse_level'),
        'goc_threshold'                 => $self->o('goc_threshold'),
        'goc_reuse_db'                  => $self->o('goc_reuse_db'),
        'calculate_goc_distribution'    => $self->o('calculate_goc_distribution'),
        'do_homology_id_mapping'        => $self->o('do_homology_id_mapping'),
        'binary_species_tree_input_file'   => $self->o('binary_species_tree_input_file'),
        'all_blast_params'          => $self->o('all_blast_params'),

        'use_quick_tree_break'   => $self->o('use_quick_tree_break'),
        'use_notung'   => $self->o('use_notung'),
        'use_treerecs' => $self->o('use_treerecs'),
        'use_raxml'    => $self->o('use_raxml'),
        'initialise_cafe_pipeline'   => $self->o('initialise_cafe_pipeline'),
        'do_stable_id_mapping'   => $self->o('do_stable_id_mapping'),
        'do_treefam_xref'   => $self->o('do_treefam_xref'),
        'do_homology_stats' => $self->o('do_homology_stats'),
        'do_hmm_export'     => $self->o('do_hmm_export'),
        'do_gene_qc'        => $self->o('do_gene_qc'),
        'dbID_range_index'  => $self->o('dbID_range_index'),
    };
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my %hc_analysis_params = (
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
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
                'output_file'   => '#dump_dir#/snapshot_1_before_clustering.sql.gz',
            },
            -flow_into  => {
                '1->A'  => WHEN(
                    '#are_all_species_reused# and (#reuse_level# eq "clusters")' => 'copy_clusters',
                    ELSE 'clustering_method_decision',
                ),
                'A->1'  => [ 'backbone_fire_tree_building' ],
            },
        },

        {   -logic_name => 'backbone_fire_tree_building',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_2_before_tree_building.sql.gz',
            },
            -flow_into  => {
                '1->A'  => [ 'cluster_factory' ],
                'A->1'  => [ 'backbone_fire_posttree' ],
            },
        },

        {   -logic_name => 'backbone_fire_posttree',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature_%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_3_after_tree_building.sql.gz',
            },
            -flow_into  => {
                '1->A'  => [ 'polyploid_move_back_factory' ],
                'A->1'  => [ 'backbone_pipeline_finished' ],
            },
        },

        {   -logic_name => 'backbone_pipeline_finished',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'table_list'    => 'peptide_align_feature_%',
                'exclude_list'  => 1,
                'output_file'   => '#dump_dir#/snapshot_4_pipeline_finished.sql.gz',
            },
            -flow_into  => [ 'notify_pipeline_completed' ],
        },

        {   -logic_name => 'notify_pipeline_completed',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
            -parameters => {
                'subject' => "Protein-Tree pipeline (".$self->o('pipeline_name').") has completed",
                'text' => "This is an automatic message.\n Protein-Tree Pipeline for release  #expr(\$self->hive_pipeline->display_name)expr#  has completed.",
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

# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckBlastReusability',
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

        {   -logic_name => 'genome_member_copy',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyCanonRefMembersByGenomeDB',
            -parameters => {
                'reuse_db'              => '#member_db#',
                'biotype_filter'        => 'biotype_group = "coding"',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => WHEN( '#is_polyploid#' => 'hc_members_per_genome',
                                ELSE                'check_reusability' ),
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
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'INSERT INTO seq_member_projection (target_seq_member_id, source_seq_member_id) SELECT target_seq_member_id, canonical_member_id FROM seq_member_projection_stable_id JOIN gene_member ON source_stable_id = stable_id',
                ],
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
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
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
                'A->1' => [ 'HMM_clusterize' ],
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
             -rc_name => '4Gb_job',
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
                         'library_basedir'   => $self->o('hmm_library_basedir'),
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
                         'library_basedir'   => $self->o('hmm_library_basedir'),
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
                         'library_basedir'   => $self->o('hmm_library_basedir'),
                         'hmmer_cutoff'      => $self->o('hmmer_search_cutoff'),
                        },
         -hive_capacity => $self->o('HMMer_search_capacity'),
         -rc_name => '64Gb_job',
         -priority=> 25,
        },

            {
             -logic_name => 'HMM_clusterize',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClusterize',
             -parameters => {
                 'division'     => $self->o('division'),
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
            -rc_name       => '1Gb_job',
            -flow_into  => [ 'unannotated_all_vs_all_factory' ],
        },

        {   -logic_name => 'unannotated_all_vs_all_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastFactoryUnannotatedMembers',
            -parameters => {
                'step'              => $self->o('num_sequences_per_blast_job'),
            },
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
            -rc_name       => '500Mb_job',
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
            -rc_name    => '500Mb_job',
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
            -rc_name       => '500Mb_job',
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
            -rc_name       => '500Mb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A' => { 'blastp' => INPUT_PLUS() },
                'A->1' => [ 'hc_pafs' ],
            },
        },

        {   -logic_name         => 'blastp',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse',
            -parameters         => {
                'blast_params'              => "#expr( #all_blast_params#->[#param_index#]->[2])expr#",
                'blast_bin_dir'             => $self->o('blast_bin_dir'),
                'evalue_limit'              => "#expr( #all_blast_params#->[#param_index#]->[3])expr#",
                'allow_same_species_hits'   => 1,
            },
            -batch_size    => 25,
            -rc_name       => '250Mb_job',
            -flow_into => {
               -1 => [ 'blastp_himem' ],  # MEMLIMIT
            },
            -hive_capacity => $self->o('blastp_capacity'),
        },

        {   -logic_name         => 'blastp_himem',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse',
            -parameters         => {
                'blast_params'              => "#expr( #all_blast_params#->[#param_index#]->[2])expr#",
                'blast_bin_dir'             => $self->o('blast_bin_dir'),
                'evalue_limit'              => "#expr( #all_blast_params#->[#param_index#]->[3])expr#",
                'allow_same_species_hits'   => 1,
            },
            -batch_size    => 25,
            -rc_name       => '1Gb_job',
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
                'output_file'   => '#dump_dir#/pafs/peptide_align_feature_#genome_db_id#.sql.gz',
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
                'A->1' => [ 'expand_clusters_with_projections' ],
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
            -rc_name    => '2Gb_job',
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
            -rc_name => '32Gb_job',
        },

        {   -logic_name => 'hcluster_parse_output',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput',
            -parameters => {
                'division'                  => $self->o('division'),
            },
            -rc_name => '4Gb_job',
        },

        {   -logic_name     => 'cluster_tagging',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ClusterTagging',
            -hive_capacity  => $self->o('cluster_tagging_capacity'),
            -rc_name    	=> '4Gb_job',
            -batch_size     => 50,
        },

        {   -logic_name => 'copy_clusters',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyClusters',
            -parameters => {
                'tags_to_copy'              => [ 'division' ],
            },
            -flow_into  => [ 'remove_blacklisted_genes' ],
            -rc_name => '4Gb_job',
        },

        {   -logic_name         => 'expand_clusters_with_projections',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExpandClustersWithProjections',
            -rc_name            => '250Mb_job',
            -flow_into          => [ 'remove_blacklisted_genes' ],
        },

        {   -logic_name         => 'remove_blacklisted_genes',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveBlacklistedGenes',
            -parameters         => {
                blacklist_file      => $self->o('gene_blacklist_file'),
            },
            -flow_into          => [ 'hc_clusters' ],
            -rc_name => '500Mb_job',
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
                member_type     => 'protein',
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
                'A->1' => [ 'clusterset_backup' ],
            },
        },

        {   -logic_name => 'overall_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OverallGroupsetQC',
            -parameters => {
                'reuse_db'  => '#mapping_db#',
            },
            -hive_capacity  => $self->o('reuse_capacity'),
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'per_genome_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PerGenomeGroupsetQC',
            -parameters => {
                'reuse_db'  => '#mapping_db#',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_name    => '4Gb_job',
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
                'A->1' => [ 'hc_global_tree_set' ],
            },
            -rc_name    => '1Gb_job',
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
                'A->1' => 'exon_boundaries_prep',
            },
            %decision_analysis_params,
        },

        {   -logic_name         => 'hc_global_tree_set',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -flow_into      => [ 'compute_statistics' ],
            %hc_analysis_params,
        },

        {   -logic_name    => 'compute_statistics',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ComputeStatistics',
            -rc_name       => '500Mb_job',
            -flow_into  => [
                    'write_stn_tags',
                    WHEN('#do_stable_id_mapping#' => 'stable_id_mapping'),
                    WHEN('#do_treefam_xref#' => 'treefam_xref_idmap'),
                    WHEN('#clustering_mode# eq "ortholog"' => 'remove_overlapping_homologies'),
                ],
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
                'subject' => "Protein tree Pipeline: ( #expr(\$self->hive_pipeline->display_name)expr# ) Gene tree report: ",
            },
        },


# ---------------------------------------------[Pluggable MSA steps]----------------------------------------------------------

        {   -logic_name => 'mcoffee_short',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                => 'cmcoffee',
                'mcoffee_home'          => $self->o('mcoffee_home'),
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
                'method'                => 'cmcoffee',
                'mcoffee_home'          => $self->o('mcoffee_home'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
                'escape_branch'         => -1,
            },
            -hive_capacity => $self->o('mcoffee_capacity'),
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

        {   -logic_name => 'mafft_update',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft_update',
            -parameters => {
                'mafft_home'                 => $self->o('mafft_home'),
            },
            -hive_capacity        => $self->o('mafft_update_capacity'),
            -rc_name    => '2Gb_job',
            -flow_into      => [ 'raxml_update_decision' ],
        },

        {   -logic_name => 'mcoffee_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                => 'cmcoffee',
                'mcoffee_home'          => $self->o('mcoffee_home'),
                'extaligners_exe_dir'   => $self->o('extaligners_exe_dir'),
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

        {   -logic_name     => 'exon_boundaries_prep',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnExonBoundaries',
            -parameters => {
                'treebreak_gene_count'      => $self->o('treebreak_gene_count'),
            },
            -flow_into      => WHEN(
                '#use_quick_tree_break# and (#tree_num_genes# > #treebreak_gene_count#)' => 'quick_tree_break',
                ELSE 'split_genes',
            ),
            -rc_name    => '500Mb_job',
            -hive_capacity  => $self->o('split_genes_capacity'),
            -batch_size     => 20,
        },

# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

        {   -logic_name     => 'split_genes',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -parameters     => {
                split_genes_gene_count  => $self->o('split_genes_gene_count'),
            },
            -hive_capacity  => $self->o('split_genes_capacity'),
            -rc_name        => '500Mb_job',
            -batch_size     => 20,
            -flow_into      => {
                '2->A' => 'split_genes_per_species',
                'A->1' => 'tree_building_entry_point',
                -1  => 'split_genes_himem',
            },
        },

        {   -logic_name     => 'split_genes_per_species',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -hive_capacity  => $self->o('split_genes_capacity'),
            -rc_name        => '500Mb_job',
        },

        {   -logic_name     => 'split_genes_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -hive_capacity  => $self->o('split_genes_capacity'),
            -rc_name        => '4Gb_job',
            -flow_into      => [ 'tree_building_entry_point' ],
        },

        {   -logic_name => 'tree_building_entry_point',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => WHEN(
                    '#use_raxml#' => 'filter_decision',
                    ELSE 'treebest_decision',
                ),
                'A->1' => WHEN(
                    '#use_notung#'      => 'notung_decision',
                    '#use_treerecs#'    => 'treerecs',
                    ELSE 'hc_post_tree',
                ),
            },
            %decision_analysis_params,
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
            #-rc_name        => '500Mb_job',
            #-batch_size     => 5,
            #-flow_into      => [ 'aln_filtering_tagging' ],
        #},

        {   -logic_name     => 'aln_filtering_tagging',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::AlignmentFilteringTagging',
            -hive_capacity  => $self->o('alignment_filtering_capacity'),
            -rc_name    	=> '4Gb_job',
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
            -rc_name    => '500Mb_job',
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
            -rc_name    => '2Gb_job',
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
            -rc_name    => '8Gb_job',
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
                'raxml_patterns_per_core'  => $self->o('use_dna_for_phylogeny') ? '500' : '150',
                'raxml_cores'  => '#expr(#tree_aln_num_of_patterns# / #raxml_patterns_per_core# )expr#',

                'tags'  => {
                    #The default value matches the default dataflow we want: _8_cores analysis.
                    'aln_num_of_patterns' => 200,
                    'gene_count'          => 0,
                },
            },
            %decision_analysis_params,

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

            -flow_into  => {
                '1->A' => WHEN (
                    '( #raxml_cores# <= 1 ) && (#tree_gene_count# <= 500)'                          => 'raxml_parsimony',
                    '( #raxml_cores# <= 1 ) && (#tree_gene_count# > 500)'                           => 'raxml_parsimony',

                    '( #raxml_cores# > 1 ) && ( #raxml_cores# <= 8 ) && (#tree_gene_count# <= 500)' => 'raxml_parsimony_8_cores',
                    '( #raxml_cores# > 1 ) && (  #raxml_cores# <= 8 ) && (#tree_gene_count# > 500)' => 'raxml_parsimony_8_cores',

                    '( #raxml_cores# > 8) && (#raxml_cores# <= 16 ) && (#tree_gene_count# <= 500)'  => 'raxml_parsimony_8_cores',
                    '( #raxml_cores# > 8) && (#raxml_cores# <= 16 ) && (#tree_gene_count# > 500)'   => 'raxml_parsimony_16_cores',

                    '( #raxml_cores# > 16) && (#raxml_cores# <= 32 ) && (#tree_gene_count# <= 500)' => 'raxml_parsimony_16_cores',
                    '( #raxml_cores# > 16) && (#raxml_cores# <= 32 ) && (#tree_gene_count# > 500)'  => 'raxml_parsimony_32_cores',

                    '( #raxml_cores# > 32) ' => 'raxml_parsimony_64_cores',
                ),
                'A->1' => 'raxml_decision',
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

        {   -logic_name => 'raxml_parsimony_8_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 8,
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '16Gb_8c_job',
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

        {   -logic_name => 'raxml_parsimony_64_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 64,
                'cmd_max_runtime'           => '518400',
                'escape_branch'             => -1,
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '16Gb_64c_job',
            -flow_into      => {
                -1 => [ 'raxml_parsimony_64_cores_himem' ],
                -2 => [ 'fasttree' ],
            }
        },

        {   -logic_name => 'raxml_parsimony_64_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_parsimony',
            -parameters => {
                %raxml_parsimony_parameters,
                'raxml_number_of_cores'     => 64,
                'cmd_max_runtime'           => '518400',
            },
            -hive_capacity  => $self->o('raxml_capacity'),
            -rc_name 		=> '32Gb_64c_job',
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
            -rc_name 		=> '32Gb_32c_job',
        },

        {   -logic_name => 'raxml_decision',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags',
            -parameters => {
                'examl_patterns_per_core'  => $self->o('use_dna_for_phylogeny') ? '3500' : '1000',
                'raxml_patterns_per_core'  => $self->o('use_dna_for_phylogeny') ? '500' : '150',

                'examl_cores'  => '#expr(#tree_aln_num_of_patterns# / #examl_patterns_per_core# )expr#',
                'raxml_cores'  => '#expr(#tree_aln_num_of_patterns# / #raxml_patterns_per_core# )expr#',

                'tags'  => {
                    #The default value matches the default dataflow we want: _8_cores analysis.
                    'aln_num_of_patterns' => 200,
                    'gene_count'          => 0,
                },
            },
            %decision_analysis_params,

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

            -flow_into  => {
                1 => WHEN (
                    '( #raxml_cores# <= 1 ) && (#tree_gene_count# <= 500)'                                                      => 'raxml',
                    '( #raxml_cores# <= 1 ) && (#tree_gene_count# > 500)'                                                       => 'raxml_8_cores',

                    '( #raxml_cores# > 1 ) && ( #raxml_cores# <= 8 ) && (#tree_gene_count# <= 500)'                             => 'raxml_8_cores',
                    '( #raxml_cores# > 1 ) && (  #raxml_cores# <= 8 ) && (#tree_gene_count# > 500)'                             => 'raxml_16_cores',

                    '( #raxml_cores# > 8) && (#raxml_cores# <= 16 ) && (#tree_gene_count# <= 500)'                              => 'raxml_16_cores',
                    '( #raxml_cores# > 8) && (#raxml_cores# <= 16 ) && (#tree_gene_count# > 500)'                               => 'examl_8_cores',

                    '( #raxml_cores# > 16) && (#examl_cores# <= 8 ) && (#tree_gene_count# <= 500)'                              => 'examl_8_cores',
                    '( #raxml_cores# > 16) && (#examl_cores# <= 8 ) && (#tree_gene_count# > 500)'                               => 'examl_16_cores',

                    '( #raxml_cores# > 16) && ( #examl_cores# > 8 ) && (#examl_cores# <= 16 ) && (#tree_gene_count# <= 500)'    => 'examl_16_cores',
                    '( #raxml_cores# > 16) && ( #examl_cores# > 8 ) && (#examl_cores# <= 16 ) && (#tree_gene_count# > 500)'     => 'examl_32_cores',

                    '( #raxml_cores# > 16) && ( #examl_cores# > 16 ) && (#examl_cores# <= 32 ) && (#tree_gene_count# <= 500)'   => 'examl_32_cores',
                    '( #raxml_cores# > 16) && ( #examl_cores# > 16 ) && (#examl_cores# <= 32 ) && (#tree_gene_count# > 500)'    => 'examl_64_cores',

                    '( #examl_cores# > 32 )'    => 'examl_64_cores',
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
            -rc_name => '8Gb_8c_mpi',
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
            -rc_name => '32Gb_8c_mpi',
        },

        {   -logic_name => 'examl_16_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '8Gb_16c_mpi',
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
            -rc_name => '32Gb_16c_mpi',
        },

        {   -logic_name => 'examl_32_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '8Gb_32c_mpi',
            -flow_into => {
               -1 => [ 'examl_32_cores_himem' ],  # MEMLIMIT
               -2 => [ 'examl_64_cores' ],  	  # RUNTIME
            }
        },

        {   -logic_name => 'examl_32_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '32Gb_32c_mpi',
        },

        {   -logic_name => 'examl_64_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
                'escape_branch'         => -2,
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '8Gb_64c_mpi',
            -max_retry_count => 3, #We restart this jobs 3 times then they will run in FastTree. After 18 days (3*518400) of ExaML 64 cores. It will probably not converge. 
            -flow_into => {
               -1 => [ 'examl_64_cores_himem' ],  # MEMLIMIT
               -2 => [ 'fasttree' ],  # RUNLIMIT
            }
        },

        {   -logic_name => 'examl_64_cores_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML',
            -parameters => {
                %examl_parameters,
                'cmd_max_runtime'       => '518400',
                'escape_branch'         => -2,
            },
            -hive_capacity        => $self->o('examl_capacity'),
            -rc_name => '32Gb_64c_mpi',
            -max_retry_count => 3, #We restart this jobs 3 times then they will run in FastTree. After 18 days (3*518400) of ExaML 64 cores. It will probably not converge.
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

        {   -logic_name => 'raxml_8_cores',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML',
            -parameters => {
                %raxml_parameters,
                'raxml_number_of_cores'     => 8,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name 		=> '16Gb_8c_job',
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
            -rc_name 		=> '16Gb_16c_job',
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
            -rc_name 		=> '32Gb_16c_job',
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
                    '(#tree_gene_count# > 10000)'                                => 'raxml_bl_64',
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

        {   -logic_name => 'raxml_bl_64',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_bl',
            -parameters => {
                %raxml_bl_parameters,
                'raxml_number_of_cores'     => 64,
            },
            -hive_capacity        => $self->o('raxml_capacity'),
            -rc_name    => '256Gb_64c_job',
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
                'tag_split_genes'   => 1,
                'input_clusterset_id'   => $self->o('use_notung') ? 'raxml_bl' : 'default',
            },
            -hive_capacity  => $self->o('ortho_tree_capacity'),
            -rc_name        => '250Mb_job',
            -flow_into      => {
                1   => [ 'hc_tree_homologies' ],
                -1  => 'ortho_tree_himem',
            },
        },

        {   -logic_name => 'ortho_tree_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'tag_split_genes'   => 1,
                'input_clusterset_id'   => $self->o('use_notung') ? 'raxml_bl' : 'default',
            },
            -hive_capacity  => $self->o('ortho_tree_capacity'),
            -priority       => 20,
            -rc_name        => '2Gb_job',
            -flow_into      => [ 'hc_tree_homologies' ],
        },

        {   -logic_name         => 'hc_tree_homologies',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_homologies',
            },
            -flow_into      => [ 'ktreedist', 'consensus_cigar_line_prep' ],
            %hc_analysis_params,
        },

        {   -logic_name    => 'ktreedist',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Ktreedist',
            -parameters    => {
                               'treebest_exe'  => $self->o('treebest_exe'),
                               'ktreedist_exe' => $self->o('ktreedist_exe'),
                              },
            -hive_capacity => $self->o('ktreedist_capacity'),
            -batch_size    => 5,
            -rc_name       => '500Mb_job',
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
            -rc_name       => '4Gb_job',
        },

        {   -logic_name     => 'consensus_cigar_line_prep',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnConsensusCigarLine',
            -rc_name        => '500Mb_job',
            -hive_capacity  => $self->o('ktreedist_capacity'),
            -batch_size     => 20,
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
            -rc_name        => '250Mb_job',
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
            -rc_name        => '1Gb_job',
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
            -rc_name        => '500Mb_job',
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
                'quicktree_exe'     => $self->o('quicktree_exe'),
                'treebreak_gene_count'  => $self->o('treebreak_gene_count'),
            },
            -hive_capacity        => $self->o('quick_tree_break_capacity'),
            -rc_name   => '2Gb_job',
            -flow_into => [ 'other_paralogs' ],
        },

        {   -logic_name     => 'other_paralogs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
            -parameters     => {
                'dataflow_subclusters' => 1,
            },
            -hive_capacity  => $self->o('other_paralogs_capacity'),
            -rc_name        => '250Mb_job',
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
            -rc_name => '1Gb_job',
        },

# ---------------------------------------------[homology step]-----------------------------------------------------------------------

        {   -logic_name => 'polyploid_move_back_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'component_genomes' => 0,
                'normal_genomes'    => 0,
            },
            -flow_into => {
                '2->A' => [ 'component_genome_dbs_move_back_factory' ],
                'A->1' => [ 'group_genomes_under_taxa' ],
                
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

        {   -logic_name => 'rib_fire_gene_qc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => WHEN('#do_gene_qc#' => 'get_species_set'),
                'A->1' => 'rib_fire_cafe',
            },
        },

        {   -logic_name => 'rib_fire_cafe',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => WHEN('#initialise_cafe_pipeline#' => 'CAFE_species_tree'),
                'A->1' => 'rib_fire_homology_stats',
            },
        },

        {   -logic_name => 'rib_fire_homology_stats',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => WHEN('#do_homology_stats#' => 'homology_stats_factory'),
                'A->1' => 'rib_fire_hmm_build',
            },
        },

        {   -logic_name => 'rib_fire_hmm_build',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => WHEN('#do_hmm_export#' => 'build_HMM_factory'),
                'A->1' => 'rib_fire_homology_id_mapping',
            },
        },

        {   -logic_name => 'rib_fire_homology_id_mapping',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -parameters => {
                'goc_taxlevels'         => $self->o('goc_taxlevels'),
            },
            -flow_into  => {
                '1->A' => WHEN('(scalar(@{#goc_taxlevels#}) && #goc_reuse_db#) || #do_homology_id_mapping#' => 'id_map_mlss_factory'),
                'A->1' => 'rib_fire_rename_labels',
            },
        },

        {   -logic_name => 'rib_fire_rename_labels',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -parameters => {
                'label_prefix' => $self->o('label_prefix'),
            },
            -flow_into  => {
                '1->A' => WHEN('#label_prefix#' => 'rename_labels'),
                'A->1' => 'rib_fire_goc',
            },
        },

        {   -logic_name => 'floating_rib',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

        {   -logic_name => 'group_genomes_under_taxa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupGenomesUnderTaxa',
            -parameters => {
                'taxlevels'             => $self->o('taxlevels'),
                'filter_high_coverage'  => $self->o('filter_high_coverage'),
            },
            -flow_into => {
                '2->A' => [ 'mlss_factory' ],
                'A->1' => [ 'rib_fire_gene_qc' ],
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
            -flow_into => { 1 => { 'homology_id_mapping' => INPUT_PLUS() } },
        },

        {   -logic_name => 'mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory',
            -flow_into => {
                2 => [ 'homology_factory' ],
            },
        },

        {   -logic_name => 'homology_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory',
            -hive_capacity => $self->o('homology_dNdS_capacity'),
            -flow_into => {
                'A->1' => [ 'hc_dnds' ],
                '2->A' => [ 'homology_dNdS' ],
            },
        },

        {   -logic_name => 'homology_id_mapping',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -parameters => {
                'prev_rel_db'   => '#mapping_db#',
            },
            -rc_name    => '1Gb_job',
            -flow_into  => {
                -1 => [ 'homology_id_mapping_himem' ],
            },
            -analysis_capacity => 100,
        },

        {   -logic_name => 'homology_id_mapping_himem',
            -parameters => {
                'prev_rel_db'   => '#mapping_db#',
            },
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping',
            -analysis_capacity => 20,
            -rc_name => '4Gb_job',
        },

        {   -logic_name => 'homology_dNdS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Homology_dNdS',
            -parameters => {
                'codeml_parameters_file'    => $self->o('codeml_parameters_file'),
                'codeml_exe'                => $self->o('codeml_exe'),
            },
            -hive_capacity        => $self->o('homology_dNdS_capacity'),
            -rc_name => '500Mb_job',
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
            -rc_name => '250Mb_job',
        },

        {   -logic_name => 'rib_fire_goc',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -parameters => {
                'taxlevels'             => $self->o('goc_taxlevels'),
            },
            -flow_into  => {
                '1->A' => WHEN( 'scalar(@{#taxlevels#})' => 'goc_entry_point' ),
                'A->1' => ['floating_rib'],
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
                'member_type'           => 'protein',
            },
            -hive_capacity => $self->o('ortho_stats_capacity'),
        },


        {   -logic_name => 'paralogy_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats',
            -parameters => {
                'member_type'           => 'protein',
                'species_tree_label'    => $self->o('use_notung') ? 'binary' : 'default',
            },
            -hive_capacity => $self->o('ortho_stats_capacity'),
        },

        {
             -logic_name => 'rename_labels',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RenameLabelsBeforMerge',
             -parameters => {
                 'division'     => $self->o('division'),
                 'label_prefix' => $self->o('label_prefix'),
             },
        },

        {
             -logic_name => 'remove_overlapping_homologies',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveOverlappingHomologies',
        },

            @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE::pipeline_analyses_cafe($self) },

            # initialise_goc_pipeline
            @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::GOC::pipeline_analyses_goc($self)  },
            @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneSetQC::pipeline_analyses_GeneSetQC($self)  },

    ];
}

1;

