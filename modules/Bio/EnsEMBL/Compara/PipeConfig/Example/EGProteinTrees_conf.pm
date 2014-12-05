=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id> \
        -division <eg_division> -eg_release <egrelease>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

    The PipeConfig example file for Ensembl Genomes group's version of
    ProteinTrees pipeline. This file is inherited from & customised further
    within the Ensembl Genomes infrastructure but this file serves as
    an example of the type of configuration we perform.

=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf;

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
        # It is very important to check that this value is current (commented out to make it obligatory to specify)
        #mlss_id => 40043,
        # names of species we don't want to reuse this time
        #'do_not_reuse_list' => ['guillardia_theta'],

    # custom pipeline name, in case you don't like the default one
        # Used to prefix the database name (in HiveGeneric_conf)
        pipeline_name => $self->o('division').'_hom_'.$self->o('eg_release').'_'.$self->o('ensembl_release'),

    # dependent parameters: updating 'work_dir' should be enough
        'work_dir'              =>  '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/compara/ensembl_compara_'.$self->o('pipeline_name'),
        'exe_dir'               =>  '/nfs/panda/ensemblgenomes/production/compara/binaries',

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,

    # blast parameters:

    # clustering parameters:

    # tree building parameters:

    # species tree reconciliation
        # you can define your own species_tree for 'treebest'. It can contain multifurcations
        'tree_dir'                  =>  $self->o('ensembl_cvs_root_dir').'/ensembl_genomes/EGCompara/config/prod/trees/Version'.$self->o('eg_release').'Trees',
        'species_tree_input_file'   =>  $self->o('tree_dir').'/'.$self->o('division').'.peptide.nh',
        # you can define your own species_tree for 'notung'. It *has* to be binary


    # homology assignment for polyploid genomes
        # This parameter is an array of groups of genome_db names / IDs.
        # Each group represents the components of a polyploid genome
        # e.g. bread wheat for the "plants" division
        'homoeologous_genome_dbs'   => $self->o('division') eq 'plants' ? [ [ 'triticum_aestivum_a', 'triticum_aestivum_b', 'triticum_aestivum_d' ] ] : [],

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'codeml_parameters_file'    => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/homology/codeml.ctl.hash',
        'taxlevels'                 => $self->o('division') eq 'plants' ? ['Liliopsida', 'eudicotyledons', 'Chlorophyta'] : ['cellular organisms'],

    # mapping parameters:
        'do_stable_id_mapping'      => 1,
        'do_treefam_xref'           => 1,
        # The TreeFam release to map to
        'tf_release'                => '9_69',

    # executable locations:
        'hcluster_exe'              => $self->o('exe_dir').'/hcluster_sg',
        'mcoffee_home'              => '/nfs/panda/ensemblgenomes/external/t-coffee',
        'mafft_home'                => '/nfs/panda/ensemblgenomes/external/mafft',
        'treebest_exe'              => $self->o('exe_dir').'/treebest',
        'quicktree_exe'             => $self->o('exe_dir').'/quicktree',
        'hmmer2_home'               => '/nfs/panda/ensemblgenomes/external/hmmer-2/bin/',
        'hmmer3_home'               => '/nfs/panda/ensemblgenomes/external/hmmer-3/bin/',
        'codeml_exe'                => $self->o('exe_dir').'/codeml',
        'ktreedist_exe'             => $self->o('exe_dir').'/ktreedist',
        'blast_bin_dir'             => '/nfs/panda/ensemblgenomes/external/ncbi-blast-2+/bin/',

        # The following ones are currently installed by TreeFam, but should
        # also be under /nfs/panda/ensemblgenomes/external/
        'pantherScore_path'         => '/nfs/production/xfam/treefam/software/pantherScore1.03/',
        'noisy_exe'                 => '/nfs/production/xfam/treefam/software/Noisy-1.5.12/noisy',
        'notung_jar'                => '/nfs/production/xfam/treefam/software/Notung/Notung-2.6/Notung-2.6.jar',
        'prottest_jar'              => '/nfs/production/xfam/treefam/software/ProtTest/prottest-3.4-20140123/prottest-3.4.jar',
        'raxml_exe'                 => '/nfs/production/xfam/treefam/software/RAxML/raxmlHPC-SSE3',
        'trimal_exe'                => '/nfs/production/xfam/treefam/software/trimal/source/trimal',
        'raxml_pthreads_exe'        => '/nfs/production/xfam/treefam/software/RAxML/raxmlHPC-PTHREADS-SSE3',
        'examl_exe_avx'             => '/nfs/production/xfam/treefam/software/ExaML/examl',
        'examl_exe_sse3'            => '/nfs/production/xfam/treefam/software/ExaML/examl',
        'parse_examl_exe'           => '/nfs/production/xfam/treefam/software/ExaML/parse-examl',

    # HMM specific parameters (set to 0 or undef if not in use)
       # List of directories that contain Panther-like databases (with books/ and globals/)
       # It requires two more arguments for each file: the name of the library, and whether subfamilies should be loaded

       # List of MultiHMM files to load (and their names)

       # Dumps coming from InterPro

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   3,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 200,
        'blastpu_capacity'          => 100,
        'mcoffee_capacity'          => 200,
        'split_genes_capacity'      => 200,
        'alignment_filtering_capacity'  => 200,
        'prottest_capacity'         => 200,
        'treebest_capacity'         => 200,
        'raxml_capacity'            => 200,
        'examl_capacity'            => 400,
        'notung_capacity'           => 200,
        'ortho_tree_capacity'       => 200,
        'ortho_tree_annot_capacity' => 300,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 200,
        'ktreedist_capacity'        => 150,
        'merge_supertrees_capacity' => 100,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 200,
        'qc_capacity'               =>   4,
        'hc_capacity'               =>   4,
        'HMMer_classify_capacity'   => 400,
        'loadmembers_capacity'      =>  30,

    # hive priority for non-LOCAL health_check analysis:

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        'dbowner' => 'ensembl_compara',

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',
        'master_db_is_missing_dnafrags' => 1,

    ######## THESE ARE PASSED INTO LOAD_REGISTRY_FROM_DB SO PASS IN DB_VERSION
    ######## ALSO RAISE THE POINT ABOUT LOAD_FROM_MULTIPLE_DBs

    prod_1 => {
      -host   => 'mysql-eg-prod-1.ebi.ac.uk',
      -port   => 4238,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

    staging_1 => {
      -host   => 'mysql-eg-staging-1.ebi.ac.uk',
      -port   => 4160,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

    staging_2 => {
      -host   => 'mysql-eg-staging-2.ebi.ac.uk',
      -port   => 4275,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs' => [ $self->o('prod_1') ],
        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('staging_1') ],

        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        'prev_rel_db' => 'mysql://ensro@mysql-eg-staging-1.ebi.ac.uk:4160/ensembl_compara_fungi_19_72',

        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   blastp means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   hmm means that the pipeline will run an HMM classification
        #   hybrid is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage

        # How much the pipeline will try to reuse from "prev_rel_db"
        # Possible values: 'clusters' (default), 'blastp', 'members'
        #   clusters means that the members, the blastp hits and the clusters are copied over. In this case, the blastp hits are actually not copied over if "skip_blast_copy_if_possible" is set
        #   blastp means that only the members and the blastp hits are copied over
        #   members means that only the members are copied over
        # If all the species can be reused, and if the reuse_level is "clusters", do we really want to copy all the peptide_align_feature tables ? They can take a lot of space and are not used in the pipeline

    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         'default'      => {'LSF' => '-q production-rh6' },
         '250Mb_job'    => {'LSF' => '-q production-rh6 -M250   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-q production-rh6 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-q production-rh6 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-q production-rh6 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '4Gb_job'      => {'LSF' => '-q production-rh6 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
         '8Gb_job'      => {'LSF' => '-q production-rh6 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
         '16Gb_job'     => {'LSF' => '-q production-rh6 -M16000 -R"select[mem>16000] rusage[mem=16000]"' },
         '32Gb_job'     => {'LSF' => '-q production-rh6 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
         '64Gb_job'     => {'LSF' => '-q production-rh6 -M64000 -R"select[mem>64000] rusage[mem=64000]"' },

         '16Gb_16c_job' => {'LSF' => '-q production-rh6 -n 16 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"' },
         '64Gb_16c_job' => {'LSF' => '-q production-rh6 -n 16 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000]"' },

         '4Gb_64c_mpi'  => {'LSF' => '-q mpi -n 64 -a openmpi -M4000  -R"select[mem>4000]  rusage[mem=4000]  same[model] span[ptile=4]"' },
         '16Gb_64c_mpi' => {'LSF' => '-q mpi -n 64 -a openmpi -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=4]"' },
  };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    $analyses_by_name->{'mcoffee'}->{'-rc_name'} = '8Gb_job';
    $analyses_by_name->{'mcoffee'}->{'-parameters'}{'cmd_max_runtime'} = 82800;
    $analyses_by_name->{'mcoffee_himem'}->{'-rc_name'} = '32Gb_job';
    $analyses_by_name->{'mcoffee_himem'}->{'-parameters'}{'cmd_max_runtime'} = 82800;
    $analyses_by_name->{'mafft'}->{'-rc_name'} = '8Gb_job';
    $analyses_by_name->{'mafft_himem'}->{'-rc_name'} = '32Gb_job';
    $analyses_by_name->{'hcluster_parse_output'}->{'-rc_name'} = '500Mb_job';
    $analyses_by_name->{'raxml_epa_longbranches_himem'}->{'-rc_name'} = '16Gb_job';

    # Some parameters can be division-specific
    if ($self->o('division') eq 'plants') {
        $analyses_by_name->{'dump_canonical_members'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name->{'members_against_allspecies_factory'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name->{'blastp'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name->{'ktreedist'}->{'-rc_name'} = '4Gb_job';
    }
}


1;

