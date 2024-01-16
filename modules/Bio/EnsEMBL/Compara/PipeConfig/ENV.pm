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

        # $ENSEMBL_ROOT_DIR is also loaded into ensembl_cvs_root_dir
        'ensembl_root_dir'      => $self->o('ensembl_cvs_root_dir'),

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
        'prev_eg_release'       => Bio::EnsEMBL::ApiVersion::software_version()-54,

        # TODO: make a $self method that checks whether this already exists, to prevent clashes like in the LastZ pipeline
        # NOTE: hps_dir and warehouse_dir are expected to be defined in the meadow JSON file
        'pipeline_dir'          => $self->o('hps_dir') . '/' . $self->o('dbowner') . '/' . $self->o('pipeline_name'),
        'shared_hps_dir'        => $self->o('hps_dir') . '/shared',

        # Embassy IP for rapid release project
        'embassy_ip_rr' => '45.88.81.155',
        # S3 buckets on Embassy cloud
        'embassy_ref_bucket' => '/storage/s3/long-term/',

        # Where to find the linuxbrew installation
        'linuxbrew_home'        => $ENV{'LINUXBREW_HOME'} || $self->o('linuxbrew_home'),
        'compara_software_home' => $self->o('warehouse_dir') . '/software/',

        # All the fixed parameters that depend on a "division" parameter
        'config_dir'            => $self->o('ensembl_root_dir') . '/ensembl-compara/conf/' . $self->o('division'),
        # NOTE: Can't use $self->check_file_in_ensembl as long as we don't produce a file for each division
        'reg_conf'              => $self->o('config_dir').'/production_reg_conf.pl',
        'binary_species_tree'   => $self->o('config_dir').'/species_tree.branch_len.nw',
        'genome_dumps_dir'      => $self->o('shared_hps_dir') . '/genome_dumps/'.$self->o('division').'/',
        'ref_member_dumps_dir'  => $self->o('shared_hps_dir') . '/reference_dumps/',
        'sketch_dir'            => $self->o('shared_hps_dir') . '/species_tree/' . $self->o('division') . '_sketches/',
        # Record of the species that have been run with each reference in RR
        'all_rr_records'        => $self->o('shared_hps_dir') . '/species_set_record/',
        'rr_species_set_record' => $self->o('all_rr_records') . '/' . Bio::EnsEMBL::ApiVersion::software_version() . '/',
        # HMM library
        'hmm_library_version'   => '2',
        'hmm_library_basedir'   => $self->o('shared_hps_dir') . '/treefam_hmms/2019-01-02',
        #'hmm_library_version'   => '3',
        #'hmm_library_basedir'   => $self->o('shared_hps_dir') . '/compara_hmm_91/',
        
        'homology_dumps_shared_basedir' => $self->o('shared_hps_dir') . '/homology_dumps/'. $self->o('division'),
        'gene_tree_stats_shared_basedir' => $self->o('shared_hps_dir') . '/gene_tree_stats/' . $self->o('division'),
        'msa_stats_shared_basedir'       => $self->o('shared_hps_dir') . '/msa_stats/' . $self->o('division'),
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
        # -> now recorded separately for each meadow, cf meadow_options()

        # Internal dependencies (Compara scripts)
        'ancestral_dump_program'            => $self->check_exe_in_ensembl('ensembl-compara/scripts/ancestral_sequences/get_ancestral_sequence.pl'),
        'ancestral_stats_program'           => $self->check_exe_in_ensembl('ensembl-compara/scripts/ancestral_sequences/get_stats.pl'),
        'BuildSynteny_exe'                  => $self->check_file_in_ensembl('ensembl-compara/scripts/synteny/BuildSynteny.jar'),
        'compare_beds_exe'                  => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/compare_beds.pl'),
        'create_mlss_exe'                   => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/create_mlss.pl'),
        'create_pair_aligner_page_exe'      => $self->check_exe_in_ensembl('ensembl-compara/scripts/report/create_pair_aligner_page.pl'),
        'dump_aln_program'                  => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/DumpMultiAlign.pl'),
        'dump_features_exe'                 => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/dump_features.pl'),
        'dump_gene_tree_exe'                => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/dumpTreeMSA_id.pl'),
        'dump_species_tree_exe'             => $self->check_exe_in_ensembl('ensembl-compara/scripts/examples/species_getSpeciesTree.pl'),
        'DumpGFFAlignmentsForSynteny_exe'   => $self->check_exe_in_ensembl('ensembl-compara/scripts/synteny/DumpGFFAlignmentsForSynteny.pl'),
        'DumpGFFHomologuesForSynteny_exe'   => $self->check_exe_in_ensembl('ensembl-compara/scripts/synteny/DumpGFFHomologuesForSynteny.pl'),
        'emf2maf_program'                   => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/emf2maf.pl'),
        'get_genebuild_id_exe'              => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/get_core_genebuild_id.pl'),
        'msa_stats_report_exe'              => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/msa_stats.pl'),
        'patch_db_exe'                      => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/patch_database.pl'),
        'populate_new_database_exe'         => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/populate_new_database.pl'),
        'populate_per_genome_database_exe'  => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/populate_per_genome_database.pl'),
        'create_datacheck_tickets_exe'      => $self->check_exe_in_ensembl('ensembl-compara/scripts/jira_tickets/create_datacheck_tickets.pl'),
        'copy_ancestral_core_exe'           => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/copy_ancestral_core.pl'),
        'get_nearest_taxonomy_exe'          => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/get_nearest_taxonomy.py'),
        'gene_tree_stats_report_exe'        => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/gene_tree_stats.pl'),
        'symlink_fasta_exe'                 => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/symlink_fasta.py'),

        # Other dependencies (non executables)
        'schema_file_sql'                   => $self->check_file_in_ensembl('ensembl-compara/sql/table.sql'),
        'core_schema_sql'                   => $self->check_file_in_ensembl('ensembl/sql/table.sql'),
        'tree_stats_sql'                    => $self->check_file_in_ensembl('ensembl-compara/sql/tree-stats-as-stn_tags.sql'),
    };
}


sub resource_classes_single_thread {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        # 1Gb seems to be the minimum we need nowadays
        'default'      => {'LSF' => ['-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"', $reg_requirement],              'LOCAL' => [ '', $reg_requirement ] },

        '500Mb_job'    => {'LSF' => ['-C0 -M500   -R"select[mem>500]   rusage[mem=500]"',  $reg_requirement],              'LOCAL' => [ '', $reg_requirement ] },
        '1Gb_job'      => {'LSF' => ['-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"', $reg_requirement],              'LOCAL' => [ '', $reg_requirement ] },
        '2Gb_job'      => {'LSF' => ['-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement],              'LOCAL' => [ '', $reg_requirement ] },
        '4Gb_job'      => {'LSF' => ['-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"', $reg_requirement],              'LOCAL' => [ '', $reg_requirement ] },
        '8Gb_job'      => {'LSF' => ['-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"', $reg_requirement],              'LOCAL' => [ '', $reg_requirement ] },
        '16Gb_job'     => {'LSF' => ['-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"', $reg_requirement],             'LOCAL' => [ '', $reg_requirement ] },
        '24Gb_job'     => {'LSF' => ['-C0 -M24000 -R"select[mem>24000] rusage[mem=24000]"', $reg_requirement],             'LOCAL' => [ '', $reg_requirement ] },
        '32Gb_job'     => {'LSF' => ['-C0 -M32000 -R"select[mem>32000] rusage[mem=32000]"', $reg_requirement],             'LOCAL' => [ '', $reg_requirement ] },
        '48Gb_job'     => {'LSF' => ['-C0 -M48000 -R"select[mem>48000] rusage[mem=48000]"', $reg_requirement],             'LOCAL' => [ '', $reg_requirement ] },
        '64Gb_job'     => {'LSF' => ['-C0 -M64000 -R"select[mem>64000] rusage[mem=64000]"', $reg_requirement],             'LOCAL' => [ '', $reg_requirement ] },
        '96Gb_job'     => {'LSF' => ['-C0 -M96000 -R"select[mem>96000] rusage[mem=96000]"', $reg_requirement],             'LOCAL' => [ '', $reg_requirement ] },
        '512Gb_job'    => {'LSF' => ['-q bigmem -C0 -M512000 -R"select[mem>512000] rusage[mem=512000]"', $reg_requirement],    'LOCAL' => [ '', $reg_requirement ] },

        '250Mb_6_hour_job' => {'LSF' => ['-C0 -W 6:00 -M250   -R"select[mem>250]   rusage[mem=250]"',  $reg_requirement],  'LOCAL' => [ '', $reg_requirement ] },
        '500Mb_6_hour_job' => {'LSF' => ['-C0 -W 6:00 -M500   -R"select[mem>500]   rusage[mem=500]"',  $reg_requirement],  'LOCAL' => [ '', $reg_requirement ] },
        '2Gb_6_hour_job'   => {'LSF' => ['-C0 -W 6:00 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement],  'LOCAL' => [ '', $reg_requirement ] },

        '1Gb_datamover_job' => {'LSF' => ['-q datamover -C0 -M1000 -R"select[mem>1000]  rusage[mem=1000]"', $reg_requirement], 'LOCAL' => [ '', $reg_requirement ] },
    };
}

sub resource_classes_multi_thread {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        # In theory, LOCAL should also be defined, but I assumed it is very unlikely we use it for multi-threaded jobs

        '500Mb_2c_job' => { 'LSF' => ['-C0 -n 2 -M500  -R"span[hosts=1] select[mem>500] rusage[mem=500]"', $reg_requirement] },
        '1Gb_2c_job'   => { 'LSF' => ['-C0 -n 2 -M1000 -R"span[hosts=1] select[mem>1000] rusage[mem=1000]"', $reg_requirement] },
        '2Gb_2c_job'   => { 'LSF' => ['-C0 -n 2 -M2000 -R"span[hosts=1] select[mem>2000] rusage[mem=2000]"', $reg_requirement] },
        '4Gb_2c_job'   => { 'LSF' => ['-C0 -n 2 -M4000 -R"span[hosts=1] select[mem>4000] rusage[mem=4000]"', $reg_requirement] },
        '8Gb_2c_job'   => { 'LSF' => ['-C0 -n 2 -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"', $reg_requirement] },

        '500Mb_4c_job' => {'LSF' => ['-n 4 -C0 -M500   -R"select[mem>500]   rusage[mem=500]   span[hosts=1]"', $reg_requirement] },
        '1Gb_4c_job'   => {'LSF' => ['-n 4 -C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]  span[hosts=1]"', $reg_requirement] },
        '2Gb_4c_job'   => {'LSF' => ['-n 4 -C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]  span[hosts=1]"', $reg_requirement] },
        '4Gb_4c_job'   => {'LSF' => ['-n 4 -C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]  span[hosts=1]"', $reg_requirement] },
        '8Gb_4c_job'   => {'LSF' => ['-n 4 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]  span[hosts=1]"', $reg_requirement] },
        '16Gb_4c_job'  => {'LSF' => ['-n 4 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"', $reg_requirement] },
        '32Gb_4c_job'  => {'LSF' => ['-n 4 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },

        '2Gb_8c_job'   => {'LSF' => ['-n 8 -C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]  span[hosts=1]"', $reg_requirement] },
        '4Gb_8c_job'   => {'LSF' => ['-n 8 -C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]  span[hosts=1]"', $reg_requirement] },
        '8Gb_8c_job'   => {'LSF' => ['-n 8 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]  span[hosts=1]"', $reg_requirement] },
        '16Gb_8c_job'  => {'LSF' => ['-n 8 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"', $reg_requirement] },
        '32Gb_8c_job'  => {'LSF' => ['-n 8 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },
        '64Gb_8c_job'  => {'LSF' => ['-n 8 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"', $reg_requirement] },
        '96Gb_8c_job'  => {'LSF' => ['-n 8 -C0 -M96000 -R"select[mem>96000] rusage[mem=96000] span[hosts=1]"', $reg_requirement] },

        '8Gb_16c_job'  => {'LSF' => ['-n 16 -C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]  span[hosts=1]"', $reg_requirement] },
        '16Gb_16c_job' => {'LSF' => ['-n 16 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"', $reg_requirement] },
        '32Gb_16c_job' => {'LSF' => ['-n 16 -C0 -M16000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },
        '64Gb_16c_job' => {'LSF' => ['-n 16 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"', $reg_requirement] },
        '128Gb_16c_job'  => {'LSF' => ['-n 16 -C0 -M128000 -R"select[mem>128000] rusage[mem=128000] span[hosts=1]"', $reg_requirement] },

        '16Gb_32c_job' => {'LSF' => ['-n 32 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"', $reg_requirement] },
        '32Gb_32c_job' => {'LSF' => ['-n 32 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },
        '64Gb_32c_job' => {'LSF' => ['-n 32 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"', $reg_requirement] },
        '128Gb_32c_job' => {'LSF' => ['-n 32 -C0 -M128000 -R"select[mem>128000] rusage[mem=128000] span[hosts=1]"', $reg_requirement] },

        '16Gb_64c_job' => {'LSF' => ['-n 64 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"', $reg_requirement] },
        '32Gb_64c_job' => {'LSF' => ['-n 64 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"', $reg_requirement] },
        '64Gb_64c_job' => {'LSF' => ['-n 64 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"', $reg_requirement] },
        '128Gb_64c_job' => {'LSF' => ['-n 64 -C0 -M128000 -R"select[mem>128000] rusage[mem=128000] span[hosts=1]"', $reg_requirement] },
        '256Gb_64c_job' => {'LSF' => ['-n 64 -C0 -M256000 -R"select[mem>256000] rusage[mem=256000] span[hosts=1]"', $reg_requirement] },

        '500Mb_4c_20min_job' => {'LSF' => ['-n 4 -C0 -M500  -W 0:20 -R"select[mem>500]   rusage[mem=500]   span[hosts=1]"', $reg_requirement] },
        '2Gb_4c_20min_job'   => {'LSF' => ['-n 4 -C0 -M2000 -W 0:20 -R"select[mem>2000]  rusage[mem=2000]  span[hosts=1]"', $reg_requirement] },

        '8Gb_4c_mpi'   => {'LSF' => ['-q mpi -n 4  -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=4]"', $reg_requirement] },
        '8Gb_8c_mpi'   => {'LSF' => ['-q mpi -n 8  -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=8]"', $reg_requirement] },
        '8Gb_16c_mpi'  => {'LSF' => ['-q mpi -n 16 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"', $reg_requirement] },
        '8Gb_24c_mpi'  => {'LSF' => ['-q mpi -n 24 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=12]"', $reg_requirement] },
        '8Gb_32c_mpi'  => {'LSF' => ['-q mpi -n 32 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"', $reg_requirement] },
        '8Gb_64c_mpi'  => {'LSF' => ['-q mpi -n 64 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"', $reg_requirement] },

        '16Gb_4c_mpi'  => {'LSF' => ['-q mpi -n 4  -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=4]"', $reg_requirement] },
        '16Gb_8c_mpi'  => {'LSF' => ['-q mpi -n 8  -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=8]"', $reg_requirement] },
        '16Gb_16c_mpi' => {'LSF' => ['-q mpi -n 16 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=16]"', $reg_requirement] },
        '16Gb_24c_mpi' => {'LSF' => ['-q mpi -n 24 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=12]"', $reg_requirement] },
        '16Gb_32c_mpi' => {'LSF' => ['-q mpi -n 32 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=16]"', $reg_requirement] },

        '32Gb_4c_mpi'  => {'LSF' => ['-q mpi -n 4  -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=4]"', $reg_requirement] },
        '32Gb_8c_mpi'  => {'LSF' => ['-q mpi -n 8  -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=8]"', $reg_requirement] },
        '32Gb_16c_mpi' => {'LSF' => ['-q mpi -n 16 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"', $reg_requirement] },
        '32Gb_24c_mpi' => {'LSF' => ['-q mpi -n 24 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=12]"', $reg_requirement] },
        '32Gb_32c_mpi' => {'LSF' => ['-q mpi -n 32 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"', $reg_requirement] },
        '32Gb_64c_mpi' => {'LSF' => ['-q mpi -n 64 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"', $reg_requirement] },

        '64Gb_4c_mpi'  => {'LSF' => ['-q mpi -n 4  -M64000 -R"select[mem>64000] rusage[mem=64000] same[model] span[ptile=4]"', $reg_requirement] },
    };
}

1;
