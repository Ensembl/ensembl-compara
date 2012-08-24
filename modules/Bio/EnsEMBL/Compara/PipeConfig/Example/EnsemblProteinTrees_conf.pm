=heada LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
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

=head2 rel.63 stats

    sequences to cluster:       1,198,678           [ SELECT count(*) from sequence; ]
    reused core dbs:            48                  [ SELECT count(*) FROM analysis JOIN job USING(analysis_id) WHERE logic_name='paf_table_reuse'; ]
    newly loaded core dbs:       5                  [ SELECT count(*) FROM analysis JOIN job USING(analysis_id) WHERE logic_name='load_fresh_members'; ]

    total running time:         8.7 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM worker;  ]  # NB: stable_id mapping phase not included
    blasting time:              1.9 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM worker JOIN analysis USING (analysis_id) WHERE logic_name='blastp_with_reuse'; ]

=head2 rel.62 stats

    sequences to cluster:       1,192,544           [ SELECT count(*) from sequence; ]
    reused core dbs:            46                  [ number of 'load_reuse_members' jobs ]
    newly loaded core dbs:       7                  [ number of 'load_fresh_members' jobs ]

    total running time:         6 days              [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive;  ]
    blasting time:              2.7 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive JOIN analysis USING (analysis_id) WHERE logic_name='blastp_with_reuse'; ]

=head2 rel.61 stats

    sequences to cluster:       1,173,469           [ SELECT count(*) from sequence; ]
    reused core dbs:            46                  [ number of 'load_reuse_members' jobs ]
    newly loaded core dbs:       6                  [ number of 'load_fresh_members' jobs ]

    total running time:         6 days              [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive;  ]
    blasting time:              1.4 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive JOIN analysis USING (analysis_id) WHERE logic_name like 'blast%' or logic_name like 'SubmitPep%'; ]

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
        'release'               => '68',
        'rel_suffix'            => 'i',    # an empty string by default, a letter otherwise
        'work_dir'              => '/lustre/scratch101/ensembl/'.$self->o('ENV', 'USER').'/protein_trees_'.$self->o('rel_with_suffix'),

    # dependent parameters: updating 'work_dir' should be enough
        'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
        'pipeline_name'         => 'PT_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

    # dump parameters:

    # blast parameters:

    # clustering parameters:
        'outgroups'                     => [127],   # affects 'hcluster_dump_input_per_genome'

    # tree building parameters:

    # homology_dnds parameters:
        'taxlevels'                 => ['Theria', 'Sauria', 'Tetraodontiformes'],
        'filter_high_coverage'      => 1,   # affects 'group_genomes_under_taxa'

    # executable locations:
        'wublastp_exe'              => '/usr/local/ensembl/bin/wublastp',
        'hcluster_exe'              => '/software/ensembl/compara/hcluster/hcluster_sg',
        'mcoffee_exe'               => '/software/ensembl/compara/tcoffee-7.86b/t_coffee',
        'mafft_exe'                 => '/software/ensembl/compara/mafft-6.707/bin/mafft',
        'mafft_binaries'            => '/software/ensembl/compara/mafft-6.707/binaries',
        'sreformat_exe'             => '/usr/local/ensembl/bin/sreformat',
        'treebest_exe'              => '/software/ensembl/compara/treebest.doubletracking',
        'quicktree_exe'             => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
        'buildhmm_exe'              => '/software/ensembl/compara/hmmer3/hmmer-3.0/src/hmmbuild',
        'codeml_exe'                => '/usr/local/ensembl/bin/codeml',

            # HMM specific parameters
            'hmm_clustering'       => 0, ## by default run blastp clustering
            'cm_file_or_directory' => '/lustre/scratch109/sanger/fs9/treefam8_hmms',
#            'cm_file_or_directory' => '/lustre/scratch110/ensembl/mp12/panther_hmms/PANTHER7.2_ascii', ## Panther DB
            'hmm_library_basedir'  => '/lustre/scratch109/sanger/fs9/treefam8_hmms',
#            'hmm_library_basedir'  => '/lustre/scratch110/ensembl/mp12/Panther_hmms',
            'blast_path'           => '/software/ensembl/compara/ncbi-blast-2.2.26+/bin/',
            'pantherScore_path'    => '/software/ensembl/compara/pantherScore1.03',
            'hmmer_path'           => '/software/ensembl/compara/hmmer-2.3.2/src/',

    # hive_capacity values for some analyses:

    # connection parameters to various databases:

        # Uncomment and update the database locations
        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_compara_homology_'.$self->o('rel_with_suffix'),
        },

        'master_db' => {                        # the master database for synchronization of various ids
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_master',
        },

        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
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

        'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],
        'curr_file_sources_locs'    => [  ],    # It can be a list of JSON files defining an additionnal set of species

        # Add the database entries for the reused core databases and update 'reuse_db'
        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },
        'reuse_core_sources_locs'   => [ $self->o('livemirror_loc') ],
        #'reuse_core_sources_locs'   => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],

        'reuse_db' => {   # usually previous release database on compara1
           -host   => 'compara3',
           -port   => 3306,
           -user   => 'ensro',
           -pass   => '',
           -dbname => 'mm14_compara_homology_67',
        },
        #'reuse_db' => {   # current release if we are testing after production
        #    -host   => 'compara1',
        #    -port   => 3306,
        #    -user   => 'ensro',
        #    -pass   => '',
        #    -dbname => 'sf5_ensembl_compara_61',
        #},
        #'prev_release'            => $self->o('release'),

    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         '500Mb_job'    => {'LSF' => '-C0 -M500000   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-C0 -M1000000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-C0 -M2000000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '8Gb_job'      => {'LSF' => '-C0 -M8000000  -R"select[mem>8000]  rusage[mem=8000]"' },
         '24Gb_job'     => {'LSF' => '-C0 -M24000000 -R"select[mem>24000] rusage[mem=24000]" -q long' },
    };
}

1;

