=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblProteinTrees_conf

=head1 DESCRIPTION

    The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblProteinTrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
#       'mlss_id'               => 40077,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
        'rel_suffix'            => '',    # an empty string by default, a letter otherwise
        'work_dir'              => '/lustre/scratch109/ensembl/'.$self->o('ENV', 'USER').'/protein_trees_'.$self->o('rel_with_suffix'),

    # dependent parameters: updating 'work_dir' should be enough
        'rel_with_suffix'       => $self->o('ensembl_release').$self->o('rel_suffix'),
        'pipeline_name'         => $self->o('pipeline_basename') . '_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

    # blast parameters:

    # clustering parameters:
        'outgroups'             => { 'saccharomyces_cerevisiae' => 2},   # affects 'hcluster_dump_input_per_genome'

    # tree building parameters:

    # homology_dnds parameters:
        'taxlevels'                 => ['Theria', 'Sauria', 'Tetraodontiformes'],
        'filter_high_coverage'      => 1,   # affects 'group_genomes_under_taxa'

    # mapping parameters:
        'do_treefam_xref'           => 1,

    # executable locations:
        'hcluster_exe'              => '/software/ensembl/compara/hcluster/hcluster_sg',
        'mcoffee_home'              => '/software/ensembl/compara/tcoffee/Version_9.03.r1318/',
        'mafft_home'                => '/software/ensembl/compara/mafft-7.017/',
        'treebest_exe'              => '/software/ensembl/compara/treebest.doubletracking',
        'quicktree_exe'             => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
        'buildhmm_exe'              => '/software/ensembl/compara/hmmer-3.0/binaries/hmmbuild',
        'codeml_exe'                => '/software/ensembl/compara/paml43/bin/codeml',
        'ktreedist_exe'             => '/software/ensembl/compara/ktreedist/Ktreedist.pl',

        'blast_bin_dir'             => '/software/ensembl/compara/ncbi-blast-2.2.27+/bin',

    # HMM specific parameters
        'hmm_clustering'            => 0, ## by default run blastp clustering
        'cm_file_or_directory'      => '/lustre/scratch109/sanger/fs9/treefam8_hmms',
        'hmm_library_basedir'       => '/lustre/scratch109/sanger/fs9/treefam8_hmms',
        #'cm_file_or_directory'      => '/lustre/scratch110/ensembl/mp12/panther_hmms/PANTHER7.2_ascii', ## Panther DB
        #'hmm_library_basedir'       => '/lustre/scratch110/ensembl/mp12/Panther_hmms',
        'pantherScore_path'         => '/software/ensembl/compara/pantherScore1.03',
        'hmmer_path'                => '/software/ensembl/compara/hmmer-2.3.2/src/',

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   4,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 900,
        'mcoffee_capacity'          => 600,
        'split_genes_capacity'      => 600,
        'njtree_phyml_capacity'     => 400,
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
        'HMMer_classify_capacity'   => 100,

    # hive priority for non-LOCAL health_check analysis:
        'hc_priority'               => 10,

    # connection parameters to various databases:

        # Uncomment and update the database locations

        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_compara_homology_'.$self->o('rel_with_suffix'),
            -driver => 'mysql',
        },

        # the master database for synchronization of various ids
        'master_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_master',
        },

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
        },

        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],
        #'curr_core_sources_locs'    => [ $self->o('livemirror_loc') ],
        'curr_file_sources_locs'    => [  ],    # It can be a list of JSON files defining an additionnal set of species

        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('livemirror_loc') ],
        #'prev_core_sources_locs'   => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],

        # Add the database location of the previous Compara release
        'prev_rel_db' => {
           -host   => 'compara3',
           -port   => 3306,
           -user   => 'ensro',
           -pass   => '',
           -dbname => 'kb3_ensembl_compara_72',
        },

        # Are we reusing the blastp alignments ?
        'reuse_from_prev_rel_db'    => 1,

        # To run without a master database
        #'use_master_db'             => 0,
        #'do_stable_id_mapping'      => 0,
        #'reuse_from_prev_rel_db'    => 0,
        #'mlss_id'                   => undef,
        #'ncbi_db'                   => $self->o('livemirror_loc'),

        #'prev_release'              => 0,   # 0 is the default and it means "take current release number and subtract 1"
        #'prev_release'            => $self->o('release'),

    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         '250Mb_job'    => {'LSF' => '-C0 -M250000   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-C0 -M500000   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-C0 -M1000000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-C0 -M2000000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '4Gb_job'      => {'LSF' => '-C0 -M4000000  -R"select[mem>4000]  rusage[mem=4000]"' },
         '8Gb_job'      => {'LSF' => '-C0 -M8000000  -R"select[mem>8000]  rusage[mem=8000]"' },

         'msa'          => {'LSF' => '-C0 -M2000000  -R"select[mem>2000]  rusage[mem=2000]"' },
         'msa_himem'    => {'LSF' => '-C0 -M8000000  -R"select[mem>8000]  rusage[mem=8000]"' },

         'urgent_hcluster'   => {'LSF' => '-C0 -M32000000 -R"select[mem>32000] rusage[mem=32000]" -q yesterday' },
    };
}

1;

