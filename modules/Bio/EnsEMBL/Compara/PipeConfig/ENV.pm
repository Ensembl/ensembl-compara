=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::ENV

=head1 DESCRIPTION

Environment-dependent pipeline configuration,

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ENV;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion ();
use Bio::EnsEMBL::Hive::Utils ('whoami');

=head2 shared_options

  Description : Options available within "default_options", i.e. $self->o(),
                on all Compara pipelines

=cut

sub shared_default_options {
    my ($self) = @_;
    return {

        # Same as in HiveGeneric_conf, but also considering $SUDO_USER as
        # we sometimes initialise pipelines with a shared user
        'dbowner'               => $ENV{'EHIVE_USER'} || $ENV{'SUDO_USER'} || whoami() || $self->o('dbowner'),

        # Since we run the same pipeline for multiple divisions, include the division name in the pipeline name
        'pipeline_name'         => $self->o('division').'_'.$self->default_pipeline_name().'_'.$self->o('rel_with_suffix'),

        # User details
        'email'                 => $self->o('dbowner').'@ebi.ac.uk',

        # Shared user used for shared files across all of Compara
        'shared_user'           => 'compara_ensembl',

        # Previous EnsEMBL release number
        'prev_release'          => Bio::EnsEMBL::ApiVersion::software_version()-1,

        # EG release number
        'eg_release'            => Bio::EnsEMBL::ApiVersion::software_version()-53,

        # TODO: make a $self method that checks whether this already exists, to prevent clashes like in the LastZ pipeline
        'pipeline_dir'          => '/home/' . $ENV{'USER'} . '/' . $self->o('pipeline_name'),
        'shared_hps_dir'        => '/home/' . $self->o('shared_user'),
        'warehouse_dir'         => '/nfs/production/panda/ensembl/warehouse/compara/',

        # Where to find the linuxbrew installation
        'linuxbrew_home'        => $ENV{'LINUXBREW_HOME'},
        'compara_software_home' => '/apps/compara/software/',

        # All the fixed parameters that depend on a "division" parameter
        'config_dir'            => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/conf/'.$self->o('division'),
        # NOTE: Can't use $self->check_file_in_ensembl as long as we don't produce a file for each division
        'reg_conf'              => $self->o('config_dir').'/production_reg_conf.pl',
        'ensj_conf'             => $self->o('config_dir').'/ensj-healthcheck.json',
        'binary_species_tree'   => $self->o('config_dir').'/species_tree.branch_len.nw',
        'genome_dumps_dir'      => $self->o('shared_hps_dir') . '/genome_dumps/'.$self->o('division').'/',
        'sketch_dir'            => $self->o('shared_hps_dir') . '/species_tree/' . $self->o('division') . '_sketches/',

        # HMM library
        'hmm_library_version'   => '2',
        'hmm_library_basedir'   => $self->o('shared_hps_dir') . '/treefam_hmms/2019-01-02',
        #'hmm_library_version'   => '3',
        #'hmm_library_basedir'   => $self->o('shared_hps_dir') . '/compara_hmm_91/',

        'homology_dumps_shared_basedir' => $self->o('shared_hps_dir') . '/homology_dumps/'. $self->o('division'),
    }
}


=head2 executable_locations

  Description : Locations to all the executables and other external dependencies.
                As executable_locations is included in "default_options", they are
                all available through $self->o().

=cut

sub executable_locations {
    my ($self) = @_;
    return {
        # External dependencies (via linuxbrew)
        #'axtChain_exe'              => $self->check_exe_in_cellar('kent/v335_1/bin/axtChain'),
        #'big_bed_exe'               => $self->check_exe_in_cellar('kent/v335_1/bin/bedToBigBed'),
        #'big_wig_exe'               => $self->check_exe_in_cellar('kent/v335_1/bin/bedGraphToBigWig'),
        'bl2seq_exe'                => undef,   # We use blastn instead
        'blast_bin_dir'             => $self->check_dir_in_cellar('blast/2.2.30/bin'),
        'blastn_exe'                => $self->check_exe_in_cellar('blast/2.2.30/bin/blastn'),
        #'blat_exe'                  => $self->check_exe_in_cellar('kent/v335_1/bin/blat'),
        'cafe_shell'                => $self->check_exe_in_cellar('cafe/2.2/bin/cafeshell'),
        'cdhit_exe'                 => $self->check_exe_in_cellar('cd-hit/4.8.1/bin/cd-hit'),
        #'chainNet_exe'              => $self->check_exe_in_cellar('kent/v335_1/bin/chainNet'),
        'cmalign_exe'               => $self->check_exe_in_cellar('infernal/1.1.2/bin/cmalign'),
        'cmbuild_exe'               => $self->check_exe_in_cellar('infernal/1.1.2/bin/cmbuild'),
        'cmsearch_exe'              => $self->check_exe_in_cellar('infernal/1.1.2/bin/cmsearch'),
        'codeml_exe'                => $self->check_exe_in_cellar('paml43/4.3.0/bin/codeml'),
        #'enredo_exe'                => $self->check_exe_in_cellar('enredo/0.5.0/bin/enredo'),
        #'erable_exe'                => $self->check_exe_in_cellar('erable/1.0/bin/erable'),
        #'esd2esi_exe'               => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/esd2esi'),
        'estimate_tree_exe'         => $self->check_file_in_cellar('pecan/0.8.0/libexec/bp/pecan/utils/EstimateTree.py'),
        'examl_exe_avx'             => $self->check_exe_in_cellar('examl/3.0.17/bin/examl-AVX'),
        'examl_exe_sse3'            => $self->check_exe_in_cellar('examl/3.0.17/bin/examl'),
        #'exonerate_exe'             => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/exonerate'),
        'extaligners_exe_dir'       => $self->o('linuxbrew_home').'/bin/',   # We expect the latest version of each aligner to be symlinked there
        #'fasta2esd_exe'             => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/fasta2esd'),
        'fasttree_exe'              => $self->check_exe_in_cellar('fasttree/2.1.8/bin/FastTree'),
        #'faToNib_exe'               => $self->check_exe_in_cellar('kent/v335_1/bin/faToNib'),
        'gerp_exe_dir'              => $self->check_dir_in_cellar('gerp/20080211_1/bin'),
        'getPatterns_exe'           => $self->check_exe_in_cellar('raxml-get-patterns/1.0/bin/getPatterns'),
        #'halStats_exe'              => $self->check_exe_in_cellar('hal/1a89bd2/bin/halStats'),
        'hcluster_exe'              => $self->check_exe_in_cellar('hclustersg/0.5.1/bin/hcluster_sg'),
        'hmmer2_home'               => $self->check_dir_in_cellar('hmmer2/2.3.2/bin'),
        'hmmer3_home'               => $self->check_dir_in_cellar('hmmer/3.1b2_1/bin'),
        'java_exe'                  => $self->check_exe_in_linuxbrew_opt('openjdk/bin/java'),
        'ktreedist_exe'             => $self->check_exe_in_cellar('ktreedist/1.0.0/bin/Ktreedist.pl'),
        #'lastz_exe'                 => $self->check_exe_in_cellar('lastz/1.04.00/bin/lastz'),
        #'lavToAxt_exe'              => $self->check_exe_in_cellar('kent/v335_1/bin/lavToAxt'),
        'mafft_exe'                 => $self->check_exe_in_cellar('mafft/7.427/bin/mafft'),
        #'mash_exe'                  => $self->check_exe_in_cellar('mash/2.0/bin/mash'),
        'mcl_bin_dir'               => $self->check_dir_in_cellar('mcl/14-137/bin'),
        'mcoffee_exe'               => $self->check_exe_in_cellar('t-coffee/9.03.r1318/bin/t_coffee'),
        #'mercator_exe'              => $self->check_exe_in_cellar('cndsrc/2013.01.11/bin/mercator'),
        'mpirun_exe'                => $self->check_exe_in_cellar('open-mpi/4.0.4_1/bin/mpirun'),
        'noisy_exe'                 => $self->check_exe_in_cellar('noisy/1.5.12/bin/noisy'),
        'notung_jar'                => $self->check_file_in_cellar('notung/2.6.0/libexec/Notung-2.6.jar'),
#        'ortheus_bin_dir'           => $self->check_dir_in_compara('ortheus/rc3/bin'),
#        'ortheus_c_exe'             => $self->check_exe_in_compara('ortheus/rc3/bin/ortheus_core'),
#        'ortheus_lib_dir'           => $self->check_dir_in_compara('ortheus/rc3'),
#        'ortheus_py'                => $self->check_exe_in_compara('ortheus/rc3/bin/Ortheus.py'),
        'pantherScore_path'         => $self->check_dir_in_cellar('pantherscore/1.03'),
        'parse_examl_exe'           => $self->check_exe_in_cellar('examl/3.0.17/bin/parse-examl'),
        #'parsimonator_exe'          => $self->check_exe_in_cellar('parsimonator/1.0.2/bin/parsimonator-SSE3'),
        'pecan_exe_dir'             => $self->check_dir_in_cellar('pecan/0.8.0/libexec'),
        'prank_exe'                 => $self->check_exe_in_cellar('prank/140603/bin/prank'),
        'prottest_jar'              => $self->check_file_in_cellar('prottest3/3.4.2/libexec/prottest-3.4.2.jar'),
        'quicktree_exe'             => $self->check_exe_in_cellar('quicktree/2.2/bin/quicktree'),
        #'r2r_exe'                   => $self->check_exe_in_cellar('r2r/1.0.5/bin/r2r'),
        #'rapidnj_exe'               => $self->check_exe_in_cellar('rapidnj/2.3.2/bin/rapidnj'),
        'raxml_exe_avx'             => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-AVX'),
        'raxml_exe_sse3'            => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-SSE3'),
        'raxml_pthread_exe_avx'     => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-PTHREADS-AVX'),
        'raxml_pthread_exe_sse3'    => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-PTHREADS-SSE3'),
        #'samtools_exe'              => $self->check_exe_in_cellar('samtools/1.9/bin/samtools'),
        #'semphy_exe'                => $self->check_exe_in_cellar('semphy/2.0b3/bin/semphy'), #semphy program
        #'server_exe'                => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/exonerate-server'),
        'treebest_exe'              => $self->check_exe_in_compara('treebest/rc5/treebest'),
        'trimal_exe'                => $self->check_exe_in_cellar('trimal/1.4.1/bin/trimal'),
        'xmllint_exe'               => $self->check_exe_in_linuxbrew_opt('libxml2/bin/xmllint'),

        # Internal dependencies (Compara scripts)
        'ancestral_dump_program'            => $self->check_exe_in_ensembl('ensembl-compara/scripts/ancestral_sequences/get_ancestral_sequence.pl'),
        'ancestral_stats_program'           => $self->check_exe_in_ensembl('ensembl-compara/scripts/ancestral_sequences/get_stats.pl'),
        'BuildSynteny_exe'                  => $self->check_file_in_ensembl('ensembl-compara/scripts/synteny/BuildSynteny.jar'),
        'compare_beds_exe'                  => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/compare_beds.pl'),
        'create_pair_aligner_page_exe'      => $self->check_exe_in_ensembl('ensembl-compara/scripts/report/create_pair_aligner_page.pl'),
        'dump_aln_program'                  => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/DumpMultiAlign.pl'),
        'dump_features_exe'                 => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/dump_features.pl'),
        'dump_gene_tree_exe'                => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/dumpTreeMSA_id.pl'),
        'dump_species_tree_exe'             => $self->check_exe_in_ensembl('ensembl-compara/scripts/examples/species_getSpeciesTree.pl'),
        'DumpGFFAlignmentsForSynteny_exe'   => $self->check_exe_in_ensembl('ensembl-compara/scripts/synteny/DumpGFFAlignmentsForSynteny.pl'),
        'DumpGFFHomologuesForSynteny_exe'   => $self->check_exe_in_ensembl('ensembl-compara/scripts/synteny/DumpGFFHomologuesForSynteny.pl'),
        'emf2maf_program'                   => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/emf2maf.pl'),
        'epo_stats_report_exe'              => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/epo_stats.pl'),
        'populate_new_database_exe'         => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/populate_new_database.pl'),
        'run_healthchecks_exe'              => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/run_healthchecks.pl'),

        # Internal dependencies (Ensembl scripts)
        'ensj_testrunner_exe'               => $self->check_exe_in_ensembl('ensj-healthcheck/run-configurable-testrunner.sh'),

        # Other dependencies (non executables)
        'core_schema_sql'                   => $self->check_file_in_ensembl('ensembl/sql/table.sql'),
        'tree_stats_sql'                    => $self->check_file_in_ensembl('ensembl-compara/sql/tree-stats-as-stn_tags.sql'),
    };
}


sub resource_classes_single_thread {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        # 250 Mb seems to be the minimum we need nowadays, especially since we load the registry
        'default' => {
            'LSF'   => [ lsf_resources(250),   $reg_requirement ],
            'SLURM' => [ slurm_resources(250), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },

        '500Mb_job' => {
            'LSF'   => [ lsf_resources(500),   $reg_requirement ],
            'SLURM' => [ slurm_resources(500), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '1Gb_job' => {
            'LSF'   => [ lsf_resources(1000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(1000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '2Gb_job' => {
            'LSF'   => [ lsf_resources(2000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(2000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '4Gb_job' => {
            'LSF'   => [ lsf_resources(4000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(4000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '8Gb_job' => {
            'LSF'   => [ lsf_resources(8000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '16Gb_job' => {
            'LSF'   => [ lsf_resources(16000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '24Gb_job' => {
            'LSF'   => [ lsf_resources(24000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(24000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '32Gb_job' => {
            'LSF'   => [ lsf_resources(32000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '48Gb_job' => {
            'LSF'   => [ lsf_resources(48000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(48000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '64Gb_job' => {
            'LSF'   => [ lsf_resources(64000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(64000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '96Gb_job' => {
            'LSF'   => [ lsf_resources(96000),   $reg_requirement ],
            'SLURM' => [ slurm_resources(96000), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        #'512Gb_job' => {
        #    'LSF'   => [ lsf_resources(512000),   $reg_requirement ],
        #    'SLURM' => [ slurm_resources(512000), $reg_requirement ],
        #    'LOCAL' => [ '', $reg_requirement ],
        #},

        '250Mb_6_hour_job' => {
            'LSF'   => [ lsf_resources(250, 0, 0, '6:00'),   $reg_requirement ],
            'SLURM' => [ slurm_resources(250, 0, 0, '6:00'), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '500Mb_6_hour_job' => {
            'LSF'   => [ lsf_resources(500, 0, 0, '6:00'),   $reg_requirement ],
            'SLURM' => [ slurm_resources(500, 0, 0, '6:00'), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
        '2Gb_6_hour_job' => {
            'LSF'   => [ lsf_resources(2000, 0, 0, '6:00'),   $reg_requirement ],
            'SLURM' => [ slurm_resources(2000, 0, 0, '6:00'), $reg_requirement ],
            'LOCAL' => [ '', $reg_requirement ],
        },
    };
}

sub resource_classes_multi_thread {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        # In theory, LOCAL should also be defined, but I assumed it is very unlikely we use it for multi-threaded jobs

        '500Mb_2c_job' => {
            'LSF'   => [ lsf_resources(500, 2),   $reg_requirement ],
            'SLURM' => [ slurm_resources(500, 2), $reg_requirement ],
        },
        '1Gb_2c_job' => {
            'LSF'   => [ lsf_resources(1000, 2),   $reg_requirement ],
            'SLURM' => [ slurm_resources(1000, 2), $reg_requirement ],
        },
        '2Gb_2c_job' => {
            'LSF'   => [ lsf_resources(2000, 2),   $reg_requirement ],
            'SLURM' => [ slurm_resources(2000, 2), $reg_requirement ],
        },
        '4Gb_2c_job' => {
            'LSF'   => [ lsf_resources(4000, 2),   $reg_requirement ],
            'SLURM' => [ slurm_resources(4000, 2), $reg_requirement ],
        },
        '8Gb_2c_job'   => {
            'LSF'   => [ lsf_resources(8000, 2),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000, 2), $reg_requirement ],
        },


        '1Gb_4c_job' => {
            'LSF'   => [ lsf_resources(1000, 4),   $reg_requirement ],
            'SLURM' => [ slurm_resources(1000, 4), $reg_requirement ],
        },
        '2Gb_4c_job' => {
            'LSF'   => [ lsf_resources(2000, 4),   $reg_requirement ],
            'SLURM' => [ slurm_resources(2000, 4), $reg_requirement ],
        },
        '4Gb_4c_job' => {
            'LSF'   => [ lsf_resources(4000, 4),   $reg_requirement ],
            'SLURM' => [ slurm_resources(4000, 4), $reg_requirement ],
        },
        '8Gb_4c_job' => {
            'LSF'   => [ lsf_resources(8000, 4),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000, 4), $reg_requirement ],
        },
        '16Gb_4c_job' => {
            'LSF'   => [ lsf_resources(16000, 4),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000, 4), $reg_requirement ],
        },
        '32Gb_4c_job'  => {
            'LSF'   => [ lsf_resources(32000, 4),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000, 4), $reg_requirement ],
        },

        '2Gb_8c_job'   => {
            'LSF'   => [ lsf_resources(2000, 8),   $reg_requirement ],
            'SLURM' => [ slurm_resources(2000, 8), $reg_requirement ],
        },
        '4Gb_8c_job'   => {
            'LSF'   => [ lsf_resources(4000, 8),   $reg_requirement ],
            'SLURM' => [ slurm_resources(4000, 8), $reg_requirement ],
        },
        '8Gb_8c_job'   => {
            'LSF'   => [ lsf_resources(8000, 8),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000, 8), $reg_requirement ],
        },
        '16Gb_8c_job'  => {
            'LSF'   => [ lsf_resources(16000, 8),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000, 8), $reg_requirement ],
        },
        '32Gb_8c_job'  => {
            'LSF'   => [ lsf_resources(32000, 8),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000, 8), $reg_requirement ],
        },
        '64Gb_8c_job'  => {
            'LSF'   => [ lsf_resources(64000, 8),   $reg_requirement ],
            'SLURM' => [ slurm_resources(64000, 8), $reg_requirement ],
        },
        '96Gb_8c_job'  => {
            'LSF'   => [ lsf_resources(96000, 8),   $reg_requirement ],
            'SLURM' => [ slurm_resources(96000, 8), $reg_requirement ],
        },

        '8Gb_16c_job'  => {
            'LSF'   => [ lsf_resources(8000, 16),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000, 16), $reg_requirement ],
        },
        '16Gb_16c_job' => {
            'LSF'   => [ lsf_resources(16000, 16),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000, 16), $reg_requirement ],
        },
        '32Gb_16c_job' => {
            'LSF'   => [ lsf_resources(32000, 16),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000, 16), $reg_requirement ],
        },
        '64Gb_16c_job' => {
            'LSF'   => [ lsf_resources(64000, 16),   $reg_requirement ],
            'SLURM' => [ slurm_resources(64000, 16), $reg_requirement ],
        },
        '128Gb_16c_job'  => {
            'LSF'   => [ lsf_resources(128000, 16),   $reg_requirement ],
            'SLURM' => [ slurm_resources(120000, 16), $reg_requirement ],
        },

        '16Gb_32c_job' => {
            'LSF'   => [ lsf_resources(16000, 32),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000, 32), $reg_requirement ],
        },
        '32Gb_32c_job' => {
            'LSF'   => [ lsf_resources(32000, 32),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000, 32), $reg_requirement ],
        },
        '64Gb_32c_job' => {
            'LSF'   => [ lsf_resources(64000, 32),   $reg_requirement ],
            'SLURM' => [ slurm_resources(64000, 32), $reg_requirement ],
        },
        '128Gb_32c_job' => {
            'LSF'   => [ lsf_resources(128000, 32),   $reg_requirement ],
            'SLURM' => [ slurm_resources(120000, 32), $reg_requirement ],
        },

		'8Gb_4c_mpi'   => {
            'LSF'   => [ lsf_resources(8000, 4, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000, 4, 1), $reg_requirement ],
        },
        '8Gb_8c_mpi'   => {
            'LSF'   => [ lsf_resources(8000, 8, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000, 8, 1), $reg_requirement ],
        },
        '8Gb_16c_mpi'  => {
            'LSF'   => [ lsf_resources(8000, 16, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000, 16, 1), $reg_requirement ],
        },
        '8Gb_24c_mpi'  => {
            'LSF'   => [ lsf_resources(8000, 24, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000, 24, 1), $reg_requirement ],
        },
        '8Gb_32c_mpi'  => {
            'LSF'   => [ lsf_resources(8000, 32, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(8000, 32, 1), $reg_requirement ],
        },
        #'8Gb_64c_mpi'  => {
        #    'LSF'   => [ lsf_resources(8000, 64, 1),   $reg_requirement ],
        #    'SLURM' => [ slurm_resources(8000, 64, 1), $reg_requirement ],
        #},

        '16Gb_4c_mpi'  => {
            'LSF'   => [ lsf_resources(16000, 4, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000, 4, 1), $reg_requirement ],
        },
        '16Gb_8c_mpi'  => {
            'LSF'   => [ lsf_resources(16000, 8, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000, 8, 1), $reg_requirement ],
        },
        '16Gb_16c_mpi' => {
            'LSF'   => [ lsf_resources(16000, 16, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000, 16, 1), $reg_requirement ],
        },
        '16Gb_24c_mpi' => {
            'LSF'   => [ lsf_resources(16000, 24, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000, 24, 1), $reg_requirement ],
        },
        '16Gb_32c_mpi' => {
            'LSF'   => [ lsf_resources(16000, 32, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(16000, 32, 1), $reg_requirement ],
        },

        '32Gb_4c_mpi'  => {
            'LSF'   => [ lsf_resources(32000, 4, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000, 4, 1), $reg_requirement ],
        },
        '32Gb_8c_mpi'  => {
            'LSF'   => [ lsf_resources(32000, 8, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000, 8, 1), $reg_requirement ],
        },
        '32Gb_16c_mpi' => {
            'LSF'   => [ lsf_resources(32000, 16, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000, 16, 1), $reg_requirement ],
        },
        '32Gb_24c_mpi' => {
            'LSF'   => [ lsf_resources(32000, 24, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000, 24, 1), $reg_requirement ],
        },
        '32Gb_32c_mpi' => {
            'LSF'   => [ lsf_resources(32000, 32, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(32000, 32, 1), $reg_requirement ],
        },
        #'32Gb_64c_mpi' => {
        #    'LSF'   => [ lsf_resources(32000, 64, 1),   $reg_requirement ],
        #    'SLURM' => [ slurm_resources(32000, 64, 1), $reg_requirement ],
        #},

        '64Gb_4c_mpi'  => {
            'LSF'   => [ lsf_resources(64000, 4, 1),   $reg_requirement ],
            'SLURM' => [ slurm_resources(64000, 4, 1), $reg_requirement ],
        },

    };
}

sub lsf_resources {
    my ($mem, $ncpu, $mpi, $walltime) = @_;
    my (@opts, @r_opts);

    push @opts, "-M$mem";
    push @r_opts, "select[mem>$mem] rusage[mem=$mem]";

    # -W 6:00
    push @opts, "-W $walltime" if $walltime;
    push @opts, "-n $ncpu" if $ncpu;

    if ($mpi) {
        push @opts, '-q mpi-rh74';
        push @r_opts, "same[model] span[ptile=$ncpu]";
    } else {
        push @opts, '-C0';
    }

    return join(' ', 
        join(' ', @opts), 
        '-R"' . join(' ', @r_opts) . '"'
    );
}

sub slurm_resources {
    my ($mem, $ncpu, $mpi, $walltime) = @_;
    my @opts;
    $ncpu ||= 1;

    # set basic options : memory, walltime, cpus
    my $mem_str = $mem >= 1000 ? ($mem/1000) . 'G' : "${mem}M";
    push @opts, "--mem=$mem_str";
    push @opts, "--time=0-${walltime}:00" if $walltime;
    #push @opts, "-N $ncpu" if $ncpu > 1;

    # set up MPI (or not)
    if ( $mpi ) {
        push @opts, "--tasks $ncpu --tasks-per-node=$ncpu --cpus-per-task 1";
    } else {
        push @opts, "--tasks 1 --cpus-per-task $ncpu";
    }

    # select suitable partition (slurm really should be doing this!!)
    my $mem_per_cpu = 3750;
    my %cpus_per_core_partitions = (
        1  => ['p1a-n1-standard-1',  'p1b-n1-standard-1',  'p1c-n1-standard-1' ],
        2  => ['p2a-n1-standard-2',  'p2b-n1-standard-2',  'p2c-n1-standard-2' ],
        4  => ['p3a-n1-standard-4',  'p3b-n1-standard-4',  'p3c-n1-standard-4' ],
        32 => ['p4a-n1-standard-32', 'p4b-n1-standard-32', 'p4c-n1-standard-32'],
    );
    my $selected_partition;
    foreach my $ncpu_part ( sort {$a <=> $b} keys %cpus_per_core_partitions ) {
        my $mem_for_partition = $ncpu_part * $mem_per_cpu;
        next if $ncpu_part < $ncpu || $mem_for_partition < $mem;
        my @partition_names = @{ $cpus_per_core_partitions{$ncpu_part} };
        $selected_partition = $partition_names[rand @partition_names];
        last;
    }
    $walltime ||= 'N';
	$mpi ||= 'N';
	die "Cannot find suitable partition for: [mem: $mem, ncpu: $ncpu, walltime: $walltime, mpi: $mpi]" unless $selected_partition;
    push @opts, "--partition $selected_partition";

    return join(' ', @opts);
}

1;
