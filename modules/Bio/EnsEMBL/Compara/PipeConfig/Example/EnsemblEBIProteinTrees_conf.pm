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

  Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblEBIProteinTrees_conf

=head1 DESCRIPTION

    The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.


=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblEBIProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # User details
        'email'                 => $self->o('ENV', 'USER').'@ebi.ac.uk',

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
        'base_dir'              => '/hps/nobackup/production/ensembl/'.$self->o('ENV', 'USER').'/',

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,

    # blast parameters:

    # clustering parameters:
        # affects 'hcluster_dump_input_per_genome'
        'outgroups'                     => { 'saccharomyces_cerevisiae' => 2 },
        # (half of the previously used 'clutering_max_gene_count=1500) affects 'hcluster_run'
        'gene_blacklist_file'           => '/nfs/production/panda/ensembl/warehouse/compara/proteintree_blacklist.e82.txt',

    # tree building parameters:
        'use_quick_tree_break'      => 0,
        'use_notung'                => 0,

    # alignment filtering options

    # species tree reconciliation
        # you can define your own species_tree for 'treebest'. It can contain multifurcations
#        'species_tree_input_file'   => '/homes/muffato/workspace/species_tree/tf10.347.nh',
        # you can define your own species_tree for 'notung'. It *has* to be binary
        'binary_species_tree_input_file'   => undef,

# homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => ['Theria', 'Sauria', 'Tetraodontiformes'],
        # affects 'group_genomes_under_taxa'
        'filter_high_coverage'      => 1,

    #CAFE pipeline
    'initialise_cafe_pipeline'      => 1,

    # GOC parameters
        'goc_taxlevels'                 => ["Euteleostomi","Ciona"],
	      'goc_threshold'                 => undef,
	      'reuse_goc'                     => undef,
        
    # mapping parameters:
        'do_stable_id_mapping'      => 1,
        'do_treefam_xref'           => 1,
        # The TreeFam release to map to
        'tf_release'                => '9_69',
        
    # executable locations:
        'hcluster_exe'              => $self->o('ensembl_cellar').'/hclustersg/0.5.0/bin/hcluster_sg',
        'mcoffee_home'              => $self->o('ensembl_cellar').'/t-coffee/9.03.r1336/',
        'mafft_home'                => $self->o('ensembl_cellar').'/mafft/7.305/',
        'trimal_exe'                => $self->o('ensembl_cellar').'/trimal/1.4.1/bin/trimal',
        'noisy_exe'                 => $self->o('ensembl_cellar').'/noisy/1.5.12/bin/noisy',
        'prottest_jar'              => $self->o('ensembl_cellar').'/prottest3/3.4.2/libexec/prottest-3.4.2.jar',
        'treebest_exe'              => $self->o('ensembl_cellar').'/treebest/84/bin/treebest',
        'raxml_exe'                 => $self->o('ensembl_cellar').'/raxml/8.2.8/bin/raxmlHPC-SSE3',
        'raxml_pthreads_exe'        => $self->o('ensembl_cellar').'/raxml/8.2.8/bin/raxmlHPC-PTHREADS-SSE3',
        'examl_exe_avx'             => $self->o('ensembl_cellar').'/examl/3.0.17/bin/examl-AVX',
        'examl_exe_sse3'            => $self->o('ensembl_cellar').'/examl/3.0.17/bin/examl',
        'parse_examl_exe'           => $self->o('ensembl_cellar').'/examl/3.0.17/bin/parse-examl',
        'notung_jar'                => $self->o('ensembl_cellar').'/notung/2.6.0/libexec/Notung-2.6.jar',
        'quicktree_exe'             => $self->o('ensembl_cellar').'/quicktree/1.1.0/bin/quicktree',
        'hmmer2_home'               => $self->o('ensembl_cellar').'/hmmer2/2.3.2/bin/',
        'hmmer3_home'               => $self->o('ensembl_cellar').'/hmmer/3.1b2_1/bin/',
        'codeml_exe'                => $self->o('ensembl_cellar').'/paml43/4.3.0/bin/codeml',
        'ktreedist_exe'             => $self->o('ensembl_cellar').'/ktreedist/1.0.0/bin/Ktreedist.pl',
        'blast_bin_dir'             => $self->o('ensembl_cellar').'/blast-2230/2.2.30/bin/',
        'pantherScore_path'         => '/nfs/production/xfam/treefam/software/pantherScore1.03/',
        'cafe_shell'                => $self->o('ensembl_cellar').'/cafe/2.2/bin/cafeshell',
        'fasttree_mp_exe'           => 'UNDEF',
        'getPatterns_exe'           => $self->o('ensembl_cellar').'/raxml-get-patterns/1.0/bin/getPatterns',

    # HMM specific parameters (set to 0 or undef if not in use)
        'hmm_library_basedir'       => '/hps/nobackup/production/ensembl/compara_ensembl/treefam_hmms/2015-12-18',
       # List of directories that contain Panther-like databases (with books/ and globals/)
       # It requires two more arguments for each file: the name of the library, and whether subfamilies should be loaded

       # List of MultiHMM files to load (and their names)

       # Dumps coming from InterPro

       # A file that holds additional tags we want to add to the HMM clusters (for instance: Best-fit models)

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   3,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 1500,
        'blastpu_capacity'          => 150,
        'mcoffee_capacity'          => 600,
        'split_genes_capacity'      => 600,
        'alignment_filtering_capacity'  => 200,
        'cluster_tagging_capacity'  => 200,
        'loadtags_capacity'         => 200,
        'prottest_capacity'         => 200,
        'treebest_capacity'         => 400,
        'raxml_capacity'            => 200,
        'examl_capacity'            => 400,
        'notung_capacity'           => 200,
        'copy_tree_capacity'        => 100,
        'ortho_tree_capacity'       => 250,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 200,
        'ktreedist_capacity'        => 150,
        'other_paralogs_capacity'   => 150,
        'homology_dNdS_capacity'    => 300,
        'hc_capacity'               => 150,
        'decision_capacity'         => 150,
        'hc_post_tree_capacity'     => 100,
        'HMMer_classify_capacity'   => 400,
        'loadmembers_capacity'      =>  30,
        'HMMer_classifyPantherScore_capacity'   => 1000,
        'copy_trees_capacity'       => 50,
        'copy_alignments_capacity'  => 50,
        'mafft_update_capacity'     => 50,
        'raxml_update_capacity'     => 50,
        'ortho_stats_capacity'      => 10,
        'goc_capacity'              => 30,
	      'genesetQC_capacity'        => 100,
    # hive priority for non-LOCAL health_check analysis:

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'

        'host'  => 'mysql-ens-compara-prod-2.ebi.ac.uk',
        'port'  => 4522,

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        #'master_db' => 'mysql://ensro@mysql-e-farm-test56.ebi.ac.uk:4449/muffato_compara_master_20140317',
        'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master',
        # Production database (for the biotypes)
        'reuse_db'              => "mysql://ensadmin:$ENV{ENSADMIN_PSW}\@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_protein_trees_87_copy",
        'mapping_db'            => "mysql://ensadmin:$ENV{ENSADMIN_PSW}\@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_protein_trees_87_copy",
        'production_db_url'     => 'mysql://ensro@mysql-ens-sta-1:4519/ensembl_production',


        # Ensembl-specific databases
        'staging_loc' => {                     # general location of half of the current release core databases
            -host   => 'mysql-ens-sta-1',
            -port   => 4519,
            -user   => 'ensro',
            -pass   => '',
        },

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'mysql-ensembl-mirror.ebi.ac.uk',
            -port   => 4240,
            -user   => 'anonymous',
            -pass   => '',
        },

        'egmirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'mysql-eg-mirror.ebi.ac.uk',
            -port   => 4157,
            -user   => 'ensro',
            -pass   => '',
        },

        'triticum_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'mysql-cluster-eg-prod-1.ebi.ac.uk',
            -port   => 4238,
            -user   => 'ensro',
            -pass   => '',
        },

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs'    => [ $self->o('staging_loc')],

        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('livemirror_loc') ],

        # Add the database location of the previous Compara release. Leave commented out if running the pipeline without reuse
        #'prev_rel_db' => 'mysql://anonymous@mysql-ensembl-mirror.ebi.ac.uk:4240/ensembl_compara_74',
        #'prev_rel_db' => 'mysql://ensro@mysql-e-farm-test56.ebi.ac.uk:4449/mm14_treefam10_snapshot',

        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   'hmm' means that the pipeline will run an HMM classification
        #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
        #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<
        'clustering_mode'           => 'blastp',

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

        # Do we want to initialise the CAFE part now ?

        #Use Timetree divergence times for the GeneTree internal nodes
        'use_timetree_times'        => 0,
    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         'default'      => {'LSF' => '-q production-rh7 -R"select[gpfs]"' },
         '250Mb_job'    => {'LSF' => '-C0 -q production-rh7 -M250   -R"select[gpfs&&mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-C0 -q production-rh7 -M500   -R"select[gpfs&&mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-C0 -q production-rh7 -M1000  -R"select[gpfs&&mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-C0 -q production-rh7 -M2000  -R"select[gpfs&&mem>2000]  rusage[mem=2000]"' },
         '4Gb_job'      => {'LSF' => '-C0 -q production-rh7 -M4000  -R"select[gpfs&&mem>4000]  rusage[mem=4000]"' },
         '4Gb_8c_job'   => {'LSF' => '-C0 -q production-rh7 -M4000  -R"select[gpfs&&mem>4000]  rusage[mem=4000]"  -n 8 span[hosts=1]' },
         '8Gb_job'      => {'LSF' => '-C0 -q production-rh7 -M8000  -R"select[gpfs&&mem>8000]  rusage[mem=8000]"' },
         '8Gb_8c_job'   => {'LSF' => '-q production-rh7 -M8000  -R"select[gpfs&&mem>8000]  rusage[mem=8000]"  -n 8 span[hosts=1]' },
         '16Gb_job'     => {'LSF' => '-q production-rh7 -M16000 -R"select[gpfs&&mem>16000] rusage[mem=16000]"' },
         '24Gb_job'     => {'LSF' => '-q production-rh7 -M24000 -R"select[gpfs&&mem>24000] rusage[mem=24000]"' },
         '32Gb_job'     => {'LSF' => '-q production-rh7 -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000]"' },
         '64Gb_job'     => {'LSF' => '-q production-rh7 -M64000 -R"select[gpfs&&mem>64000] rusage[mem=64000]"' },
         '512Gb_job'     => {'LSF' => '-q production-rh7 -M512000 -R"select[gpfs&&mem>512000] rusage[mem=512000]"' },

         '16Gb_8c_job' => {'LSF' => '-q production-rh7 -n 8 -C0 -M16000 -R"select[gpfs&&mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_8c_job' => {'LSF' => '-q production-rh7 -n 8 -C0 -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000] span[hosts=1]"' },
         '16Gb_16c_job' => {'LSF' => '-q production-rh7 -n 16 -C0 -M16000 -R"select[gpfs&&mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_16c_job' => {'LSF' => '-q production-rh7 -n 16 -C0 -M16000 -R"select[gpfs&&mem>32000] rusage[mem=32000] span[hosts=1]"' },
         '64Gb_16c_job' => {'LSF' => '-q production-rh7 -n 16 -C0 -M64000 -R"select[gpfs&&mem>64000] rusage[mem=64000] span[hosts=1]"' },

        '16Gb_32c_job' => {'LSF' => '-q production-rh7 -n 32 -C0 -M16000 -R"select[gpfs&&mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_32c_job' => {'LSF' => '-q production-rh7 -n 32 -C0 -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000] span[hosts=1]"' },
         '16Gb_64c_job' => {'LSF' => '-q production-rh7 -n 64 -C0 -M16000 -R"select[gpfs&&mem>16000] rusage[mem=16000] span[hosts=1]"' },
         '32Gb_64c_job' => {'LSF' => '-q production-rh7 -n 64 -C0 -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000] span[hosts=1]"' },
         '256Gb_64c_job' => {'LSF' => '-q production-rh7 -n 64 -C0 -M256000 -R"select[gpfs&&mem>256000] rusage[mem=256000] span[hosts=1]"' },

         '8Gb_64c_mpi'  => {'LSF' => '-q mpi -n 64 -a openmpi -M8000 -R"select[gpfs&&mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },
         '32Gb_64c_mpi' => {'LSF' => '-q mpi -n 64 -a openmpi -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },

         '8Gb_8c_mpi'  => {'LSF' => '-q mpi -n 8 -M8000 -R"select[gpfs&&mem>8000] rusage[mem=8000] same[model] span[ptile=8]"' },
         '8Gb_16c_mpi'  => {'LSF' => '-q mpi -n 16 -M8000 -R"select[gpfs&&mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },
         '8Gb_24c_mpi'  => {'LSF' => '-q mpi -n 24 -M8000 -R"select[gpfs&&mem>8000] rusage[mem=8000] same[model] span[ptile=12]"' },
         '8Gb_32c_mpi'  => {'LSF' => '-q mpi -n 32 -M8000 -R"select[gpfs&&mem>8000] rusage[mem=8000] same[model] span[ptile=16]"' },

         '32Gb_8c_mpi' => {'LSF' => '-q mpi -n 8 -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000] same[model] span[ptile=8]"' },
         '32Gb_16c_mpi' => {'LSF' => '-q mpi -n 16 -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },
         '32Gb_24c_mpi' => {'LSF' => '-q mpi -n 24 -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000] same[model] span[ptile=12]"' },
         '32Gb_32c_mpi' => {'LSF' => '-q mpi -n 32 -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000] same[model] span[ptile=16]"' },


         'msa'          => {'LSF' => '-C0 -q production-rh7 -M2000  -R"select[gpfs&&mem>2000]  rusage[mem=2000]"' },
         'msa_himem'    => {'LSF' => '-C0 -q production-rh7 -M8000  -R"select[gpfs&&mem>8000]  rusage[mem=8000]"' },

         'urgent_hcluster'      => {'LSF' => '-C0 -q production-rh7 -M32000 -R"select[gpfs&&mem>32000] rusage[mem=32000]"' },
         '4Gb_job_gpfs' => {},
    };
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    my %overriden_rc_names = (
        'CAFE_table'                => '24Gb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
    $analyses_by_name->{'CAFE_analysis'}->{'-parameters'}{'pvalue_lim'} = 1;
}


1;

