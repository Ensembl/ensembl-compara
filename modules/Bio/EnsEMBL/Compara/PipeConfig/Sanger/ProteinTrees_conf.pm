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

Bio::EnsEMBL::Compara::PipeConfig::Sanger::ProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Sanger::ProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 DESCRIPTION

The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::ProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion ();

use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # User details
        'email'                 => $self->o('ENV', 'USER').'@sanger.ac.uk',

    # parameters that are likely to change from execution to another:
        # You can add a letter to distinguish this run from other runs on the same release
        'rel_suffix'            => '',
        # names of species we don't want to reuse this time
        'do_not_reuse_list'     => [ ],

    # custom pipeline name, in case you don't like the default one
        'pipeline_name'         => 'protein_trees_'.$self->o('rel_with_suffix'),
        # Tag attached to every single tree
        'division'              => 'ensembl',

    # dependent parameters: updating 'base_dir' should be enough
        'base_dir'              => '/lustre/scratch109/ensembl/'.$self->o('ENV', 'USER').'/',

    # "Member" parameters:

    # blast parameters:

    # clustering parameters:
        # affects 'hcluster_dump_input_per_genome'
        'outgroups'                     => { 'saccharomyces_cerevisiae' => 2 },
        # File with gene / peptide names that must be excluded from the
        # clusters (e.g. know to disturb the trees)
        'gene_blacklist_file'           => '/nfs/users/nfs_m/mm14/workspace/proteintree_blacklist.e82.txt',

    # tree building parameters:
        'use_quick_tree_break'      => 0,

    # sequence type used on the phylogenetic inferences
    # It has to be set to 1 for the strains
        'use_dna_for_phylogeny'     => 0,
        #'use_dna_for_phylogeny'     => 1,

    # alignment filtering options

    # species tree reconciliation
        # you can define your own species_tree for 'notung'. It *has* to be binary
        'binary_species_tree_input_file'   => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.ensembl.topology.nw',

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => ['Theria', 'Sauria', 'Tetraodontiformes'],
        # affects 'group_genomes_under_taxa'
        'filter_high_coverage'      => 1,
        
    # GOC parameters
        'goc_taxlevels'                 => ['Carnivora','Ciona'], #['Euteleostomi','Ciona'],
        'goc_threshold'                 => undef,

    # mapping parameters:
        'do_stable_id_mapping'      => 1,
        'do_treefam_xref'           => 1,
        # The TreeFam release to map to
        'tf_release'                => '9_69',

    # executable locations:
        'hcluster_exe'              => '/software/ensembl/compara/hcluster/hcluster_sg',
        'mcoffee_home'              => '/software/ensembl/compara/tcoffee/Version_9.03.r1318/',
        'mafft_home'                => '/software/ensembl/compara/mafft-7.221/',
        'trimal_exe'                => '/software/ensembl/compara/trimAl/trimal-1.2',
        'noisy_exe'                 => '/software/ensembl/compara/noisy/noisy-1.5.12',
        'prottest_jar'              => '/software/ensembl/compara/prottest/prottest-3.4.jar',
        'treebest_exe'              => '/software/ensembl/compara/treebest',
        'raxml_exe'                 => '/software/ensembl/compara/raxml/raxmlHPC-SSE3-8.1.3',
        'examl_exe_avx'             => 'UNDEF',
        'examl_exe_sse3'            => 'UNDEF',
        'parse_examl_exe'           => 'UNDEF',
        'notung_jar'                => '/software/ensembl/compara/notung/Notung-2.6.jar',
        'quicktree_exe'             => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
        'hmmer2_home'               => '/software/ensembl/compara/hmmer-2.3.2/src/',
        'hmmer3_home'               => '/software/ensembl/compara/hmmer-3.1b1/binaries/',
        'codeml_exe'                => '/software/ensembl/compara/paml43/bin/codeml',
        'ktreedist_exe'             => '/software/ensembl/compara/ktreedist/Ktreedist.pl',
        'blast_bin_dir'             => '/software/ensembl/compara/ncbi-blast-2.2.30+/bin',
        'pantherScore_path'         => '/software/ensembl/compara/pantherScore1.03',
        'getPatterns_exe'           => 'UNDEF',
        'cafe_shell'                => '/software/ensembl/compara/cafe/cafe.2.2/cafe/bin/shell',
        'fasttree_mp_exe'           => 'UNDEF',

    # HMM specific parameters (set to 0 or undef if not in use)

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   3,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 900,
        'blastpu_capacity'          => 700,
        'mcoffee_capacity'          => 600,
        'split_genes_capacity'      => 600,
        'alignment_filtering_capacity'  => 400,
        'loadtags_capacity'         => 200,
        'prottest_capacity'         => 400,
        'treebest_capacity'         => 400,
        'raxml_capacity'            => 500,
        'examl_capacity'            => 800,
        'notung_capacity'           => 400,
        'ortho_tree_capacity'       => 200,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 200,
        'ktreedist_capacity'        => 150,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 1500,
        'hc_capacity'               => 150,
        'decision_capacity'         => 150,
        'hc_post_tree_capacity'     => 100,
        'HMMer_classify_capacity'   => 100,
        'loadmembers_capacity'      =>  30,
        'HMMer_classifyPantherScore_capacity'   => 1000,
        'copy_trees_capacity'       => 50,
        'copy_alignments_capacity'  => 50,
        'mafft_update_capacity'     => 50,
        'raxml_update_capacity'     => 50,
        'ortho_stats_capacity'      => 10,
        'copy_tree_capacity'        => 100,
        'cluster_tagging_capacity'  => 200,
        'goc_capacity'              => 200,
        'genesetQC_capacity'        => 200,

    # hive priority for non-LOCAL health_check analysis:

    # connection parameters to various databases:

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        'host' => 'compara2',

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://ensro@compara1:3306/mm14_ensembl_compara_master',

        # Ensembl-specific databases
        'staging_loc1' => {                     # general location of half of the current release core databases
            -host   => 'ens-staging',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'staging_loc2' => {                     # general location of the other half of the current release core databases
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            # This value works in production. Change it if you want to run the pipeline in another context, but don't commit the change !
            -db_version => Bio::EnsEMBL::ApiVersion::software_version()-1,
        },

        'eg_live' => {
            -host => 'mysql-eg-publicsql.ebi.ac.uk',
            -port => 4157,
            -user => 'anonymous',
            -db_version => Bio::EnsEMBL::ApiVersion::software_version()-1,
        },

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],
        #'curr_core_sources_locs'    => [ $self->o('livemirror_loc') ],
        'curr_file_sources_locs'    => [  ],    # It can be a list of JSON files defining an additionnal set of species

        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('livemirror_loc') ],
        #'prev_core_sources_locs'   => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],

        # Add the database location of the previous Compara release. Leave commented out if running the pipeline without reuse
        # NOTE: This most certainly has to change every-time you run the pipeline. Only commit the change if it's the production run
        'prev_rel_db' => 'mysql://ensro@compara5:3306/wa2_ensembl_compara_85',

        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   'hmm' means that the pipeline will run an HMM classification
        #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
        #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<

        # How much the pipeline will try to reuse from "prev_rel_db"
        # Possible values: 'clusters' (default), 'blastp', 'members'
        #   'members' means that only the members are copied over, and the rest will be re-computed
        #   'hmms' is like 'members', but also copies the HMM profiles. It requires that the clustering mode is not 'blastp'  >> UNIMPLEMENTED <<
        #   'hmm_hits' is like 'hmms', but also copies the HMM hits  >> UNIMPLEMENTED <<
        #   'blastp' is like 'members', but also copies the blastp hits. It requires that the clustering mode is 'blastp'
        #   'clusters' is like 'hmm_hits' or 'blastp' (depending on the clustering mode), but also copies the clusters
        #   'alignments' is like 'clusters', but also copies the alignments  >> UNIMPLEMENTED <<
        #   'trees' is like 'alignments', but also copies the trees  >> UNIMPLEMENTED <<
        #   'homologies is like 'trees', but also copies the homologies  >> UNIMPLEMENTED <<

        # To run without a master database
        #'master_db'                 => undef,
        #'do_stable_id_mapping'      => 0,
        #'mlss_id'                   => undef,
        #'ncbi_db'                   => 'mysql://ensro@ens-livemirror:3306/ncbi_taxonomy',
        #'prev_rel_db'               => undef,

        # Do we want to initialise the CAFE part now ?
        'initialise_cafe_pipeline'  => 1,

        #Use Timetree divergence times for the GeneTree internal nodes
        'use_timetree_times'        => 1,
    };
}


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
         '512Gb_job'    => {'LSF' => '-C0 -M512000 -R"select[mem>512000] rusage[mem=512000]"' },

         '8Gb_8c_job'  => {'LSF' => '-n 8 -C0 -M8000 -R"select[mem>8000] rusage[mem=8000] span[hosts=1]"' },
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

         '8Gb_8c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 8 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=8] span[hosts=1]"' },
         '8Gb_16c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 16 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16] span[hosts=1]"' },
         '8Gb_24c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 24 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=12]"' },
         '8Gb_32c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 32 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },

         '16Gb_64c_mpi' => {'LSF' => '-q parallel -a openmpi -n 64 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=4]"' },

         '32Gb_8c_mpi' => {'LSF' => '-q parallel -a openmpi -n 8 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=8]"' },
         '32Gb_16c_mpi' => {'LSF' => '-q parallel -a openmpi -n 16 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },
         '32Gb_24c_mpi' => {'LSF' => '-q parallel -a openmpi -n 24 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=12]"' },
         '32Gb_32c_mpi' => {'LSF' => '-q parallel -a openmpi -n 32 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },

         '8Gb_long_job'      => {'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"  -q long' },
         '32Gb_urgent_job'   => {'LSF' => '-C0 -M32000 -R"select[mem>32000] rusage[mem=32000]" -q yesterday' },

         '8Gb_64c_mpi'  => {'LSF' => '-q parallel -a openmpi -n 64 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },
         '32Gb_64c_mpi' => {'LSF' => '-q parallel -a openmpi -n 64 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },

    };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'hcluster_run'              => '32Gb_urgent_job',
        'treebest_long_himem'       => '8Gb_long_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
    $analyses_by_name->{'mcoffee'}->{'-parameters'}{'cmd_max_runtime'} = 39600;
    $analyses_by_name->{'mcoffee_himem'}->{'-parameters'}{'cmd_max_runtime'} = 39600;
    $analyses_by_name->{'CAFE_analysis'}->{'-parameters'}{'pvalue_lim'} = 1;
}

1;

