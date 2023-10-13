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

        # Where to find the linuxbrew installation
        'linuxbrew_home'        => $ENV{'LINUXBREW_HOME'} || $self->o('linuxbrew_home'),
        'compara_software_home' => $self->o('warehouse_dir') . '/software/',

        # All the fixed parameters that depend on a "division" parameter
        'config_dir'            => $self->o('ensembl_root_dir') . '/ensembl-compara/conf/' . $self->o('division'),
        # NOTE: Can't use $self->check_file_in_ensembl as long as we don't produce a file for each division
        'reg_conf'              => $self->o('config_dir').'/production_reg_conf.pl',
        'binary_species_tree'   => $self->o('config_dir').'/species_tree.branch_len.nw',
        'genome_dumps_dir'      => $self->o('shared_hps_dir') . '/genome_dumps/'.$self->o('division').'/',
        'sketch_dir'            => $self->o('shared_hps_dir') . '/species_tree/' . $self->o('division') . '_sketches/',

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
        'count_genes_in_tree_exe'           => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/count_genes_in_tree.pl'),
        'create_pair_aligner_page_exe'      => $self->check_exe_in_ensembl('ensembl-compara/scripts/report/create_pair_aligner_page.pl'),
        'dump_aln_program'                  => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/DumpMultiAlign.pl'),
        'dump_features_exe'                 => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/dump_features.pl'),
        'dump_gene_tree_exe'                => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/dumpTreeMSA_id.pl'),
        'dump_species_tree_exe'             => $self->check_exe_in_ensembl('ensembl-compara/scripts/examples/species_getSpeciesTree.pl'),
        'DumpGFFAlignmentsForSynteny_exe'   => $self->check_exe_in_ensembl('ensembl-compara/scripts/synteny/DumpGFFAlignmentsForSynteny.pl'),
        'DumpGFFHomologuesForSynteny_exe'   => $self->check_exe_in_ensembl('ensembl-compara/scripts/synteny/DumpGFFHomologuesForSynteny.pl'),
        'emf2maf_program'                   => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/emf2maf.pl'),
        'list_must_reuse_species_exe'       => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/list_must_reuse_species.py'),
        'msa_stats_report_exe'              => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/msa_stats.pl'),
        'patch_db_exe'                      => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/patch_database.pl'),
        'populate_new_database_exe'         => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/populate_new_database.pl'),
        'create_datacheck_tickets_exe'      => $self->check_exe_in_ensembl('ensembl-compara/scripts/jira_tickets/create_datacheck_tickets.pl'),
        'copy_ancestral_core_exe'           => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/copy_ancestral_core.pl'),
        'gene_tree_stats_report_exe'        => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/gene_tree_stats.pl'),
        'hal_cov_one_seq_chunk_exe'         => $self->check_exe_in_ensembl('ensembl-compara/scripts/hal_alignment/hal_cov_one_seq_chunk.py'),

        # Other dependencies (non executables)
        'core_schema_sql'                   => $self->check_file_in_ensembl('ensembl/sql/table.sql'),
        'tree_stats_sql'                    => $self->check_file_in_ensembl('ensembl-compara/sql/tree-stats-as-stn_tags.sql'),
    };
}



# Methods 'resource_classes_single_thread' and 'resource_classes_multi_thread' generate
# a set of resource classes from the resource-class templates, and the former also has
# additional resource classes. By the end of the process, every resource class should
# have config for supported meadows, with each meadow config being a two-element arrayref
# of the form: '[$submission_cmd_args, $worker_cmd_args]'.

sub resource_classes_single_thread {
    my ($self) = @_;

    my $resource_class_templates = {
        # 1 Gb seems to be the minimum we need nowadays
        '1Gb_job' => {
            'LSF'   => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"',
            'SLURM' => '--partition=standard --mem=1g',
        },

        '2Gb_job' => {
            'LSF'   => '-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"',
            'SLURM' => '--partition=standard --mem=2g',
        },

        '4Gb_job' => {
            'LSF'   => '-C0 -M4000 -R"select[mem>4000] rusage[mem=4000]"',
            'SLURM' => '--partition=standard --mem=4g',
        },

        '8Gb_job' => {
            'LSF'   => '-C0 -M8000 -R"select[mem>8000] rusage[mem=8000]"',
            'SLURM' => '--partition=standard --mem=8g',
        },

        '16Gb_job' => {
            'LSF'   => '-C0 -M16000 -R"select[mem>16000] rusage[mem=16000]"',
            'SLURM' => '--partition=standard --mem=16g',
        },

        '24Gb_job' => {
            'LSF'   => '-C0 -M24000 -R"select[mem>24000] rusage[mem=24000]"',
            'SLURM' => '--partition=standard --mem=24g',
        },

        '32Gb_job' => {
            'LSF'   => '-C0 -M32000 -R"select[mem>32000] rusage[mem=32000]"',
            'SLURM' => '--partition=standard --mem=32g',
        },

        '48Gb_job' => {
            'LSF'   => '-C0 -M48000 -R"select[mem>48000] rusage[mem=48000]"',
            'SLURM' => '--partition=standard --mem=48g',
        },

        '64Gb_job' => {
            'LSF'   => '-C0 -M64000 -R"select[mem>64000] rusage[mem=64000]"',
            'SLURM' => '--partition=standard --mem=64g',
        },

        '96Gb_job' => {
            'LSF'   => '-C0 -M96000 -R"select[mem>96000] rusage[mem=96000]"',
            'SLURM' => '--partition=standard --mem=96g',
        },

        '512Gb_job' => {
            'LSF'   => '-q bigmem -C0 -M512000 -R"select[mem>512000] rusage[mem=512000]"',
            'SLURM' => '--partition=standard --mem=512g',
        },
    };

    my $long_running_rc_keys = [
        '1Gb_job',
        '8Gb_job',
        '64Gb_job',
        '96Gb_job',
    ];

    my $resource_classes = _generate_resource_classes($resource_class_templates, $long_running_rc_keys);

    # Some resource classes do not fit the typical pattern, so we add them here.
    my %additional_resource_classes = (

        '1Gb_6_hour_job' => {
            'LSF'   => ['-C0 -M500 -R"select[mem>500] rusage[mem=500]" -W 6:00'],
            'SLURM' => ['--partition=standard --mem=500m --time=6:00:00'],
        },

        '2Gb_6_hour_job' => {
            'LSF'   => ['-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]" -W 6:00'],
            'SLURM' => ['--partition=standard --mem=2g --time=6:00:00'],
        },

        '1Gb_datamover_job' => {
            'LSF'   => ['-q datamover -C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"'],
            'SLURM' => ['--partition=datamover --mem=1g --time=24:00:00'],
        },
    );
    %{$resource_classes} = (%{$resource_classes}, %additional_resource_classes);

    _apply_common_rc_config($self, $resource_classes);

    $resource_classes->{'default'} = \%{$resource_classes->{'1Gb_job'}};

    return $resource_classes;
}

sub resource_classes_multi_thread {
    my ($self) = @_;

    my $resource_class_templates = {

        '1Gb_2c_job' => {
            'LSF'   => '-C0 -n 2 -M1000 -R"span[hosts=1] select[mem>1000] rusage[mem=1000]"',
            'SLURM' => '--partition=standard --cpus-per-task=2 --mem=1g',
        },

        '2Gb_2c_job' => {
            'LSF'   => '-C0 -n 2 -M2000 -R"span[hosts=1] select[mem>2000] rusage[mem=2000]"',
            'SLURM' => '--partition=standard --cpus-per-task=2 --mem=2g',
        },

        '4Gb_2c_job' => {
            'LSF'   => '-C0 -n 2 -M4000 -R"span[hosts=1] select[mem>4000] rusage[mem=4000]"',
            'SLURM' => '--partition=standard --cpus-per-task=2 --mem=4g',
        },

        '8Gb_2c_job' => {
            'LSF'   => '-C0 -n 2 -M8000 -R"span[hosts=1] select[mem>8000] rusage[mem=8000]"',
            'SLURM' => '--partition=standard --cpus-per-task=2 --mem=8g',
        },

        '1Gb_4c_job' => {
            'LSF'   => '-n 4 -C0 -M1000 -R"select[mem>1000] rusage[mem=1000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=4 --mem=1g',
        },

        '2Gb_4c_job' => {
            'LSF'   => '-n 4 -C0 -M2000 -R"select[mem>2000] rusage[mem=2000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=4 --mem=2g',
        },

        '4Gb_4c_job' => {
            'LSF'   => '-n 4 -C0 -M4000 -R"select[mem>4000] rusage[mem=4000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=4 --mem=4g',
        },

        '8Gb_4c_job' => {
            'LSF'   => '-n 4 -C0 -M8000 -R"select[mem>8000] rusage[mem=8000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=4 --mem=8g',
        },

        '16Gb_4c_job' => {
            'LSF'   => '-n 4 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=4 --mem=16g',
        },

        '32Gb_4c_job' => {
            'LSF'   => '-n 4 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=4 --mem=32g',
        },

        '1Gb_8c_job' => {
            'LSF'   => '-n 8 -C0 -M1000 -R"select[mem>1000] rusage[mem=1000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=8 --mem=1g',
        },

        '2Gb_8c_job' => {
            'LSF'   => '-n 8 -C0 -M2000 -R"select[mem>2000] rusage[mem=2000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=8 --mem=2g',
        },

        '2Gb_8c_job' => {
            'LSF'   => '-n 8 -C0 -M2000 -R"select[mem>2000] rusage[mem=2000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=8 --mem=2g',
        },

        '4Gb_8c_job' => {
            'LSF'   => '-n 8 -C0 -M4000 -R"select[mem>4000] rusage[mem=4000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=8 --mem=4g',
        },

        '8Gb_8c_job' => {
            'LSF'   => '-n 8 -C0 -M8000 -R"select[mem>8000] rusage[mem=8000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=8 --mem=8g',
        },

        '16Gb_8c_job' => {
            'LSF'   => '-n 8 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=8 --mem=16g',
        },

        '32Gb_8c_job' => {
            'LSF'   => '-n 8 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=8 --mem=32g',
        },

        '64Gb_8c_job' => {
            'LSF'   => '-n 8 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=8 --mem=64g',
        },

        '96Gb_8c_job' => {
            'LSF'   => '-n 8 -C0 -M96000 -R"select[mem>96000] rusage[mem=96000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=8 --mem=96g',
        },

        '8Gb_16c_job' => {
            'LSF'   => '-n 16 -C0 -M8000 -R"select[mem>8000] rusage[mem=8000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=16 --mem=8g',
        },

        '16Gb_16c_job' => {
            'LSF'   => '-n 16 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=16 --mem=16g',
        },

        '32Gb_16c_job' => {
            'LSF'   => '-n 16 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=16 --mem=32g',
        },

        '64Gb_16c_job' => {
            'LSF'   => '-n 16 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=16 --mem=64g',
        },

        '128Gb_16c_job' => {
            'LSF'   => '-n 16 -C0 -M128000 -R"select[mem>128000] rusage[mem=128000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=16 --mem=128g',
        },

        '16Gb_32c_job' => {
            'LSF'   => '-n 32 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=32 --mem=16g',
        },

        '32Gb_32c_job' => {
            'LSF'   => '-n 32 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=32 --mem=32g',
        },

        '64Gb_32c_job' => {
            'LSF'   => '-n 32 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=32 --mem=64g',
        },

        '128Gb_32c_job' => {
            'LSF'   => '-n 32 -C0 -M128000 -R"select[mem>128000] rusage[mem=128000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=32 --mem=128g',
        },

        '4Gb_48c_job' => {
            'LSF'   => '-n 48 -C0 -M4000 -R"span[hosts=1] select[mem>4000] rusage[mem=4000]"',
            'SLURM' => '--partition=standard --cpus-per-task=48 --mem=4g',
        },

        '16Gb_48c_job' => {
            'LSF'   => '-n 48 -C0 -M16000 -R"select[mem>16000] rusage[mem=16000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=48 --mem=16g',
        },

        '32Gb_48c_job' => {
            'LSF'   => '-n 48 -C0 -M32000 -R"select[mem>32000] rusage[mem=32000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=48 --mem=32g',
        },

        '64Gb_48c_job' => {
            'LSF'   => '-n 48 -C0 -M64000 -R"select[mem>64000] rusage[mem=64000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=48 --mem=64g',
        },

        '128Gb_48c_job' => {
            'LSF'   => '-n 48 -C0 -M128000 -R"select[mem>128000] rusage[mem=128000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=48 --mem=128g',
        },

        '256Gb_48c_job' => {
            'LSF'   => '-n 48 -C0 -M256000 -R"select[mem>256000] rusage[mem=256000] span[hosts=1]"',
            'SLURM' => '--partition=standard --cpus-per-task=48 --mem=256g',
        },


        '8Gb_4c_mpi' => {
            'LSF'   => '-q mpi -n 4 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=4]"',
            'SLURM' => '--partition=standard --cpus-per-task=4 --mem=8g',
        },

        '8Gb_8c_mpi' => {
            'LSF'    => '-q mpi -n 8 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=8]"',
            'SLURM'  => '--partition=standard --cpus-per-task=8 --mem=8g',
        },

        '8Gb_16c_mpi' => {
            'LSF'    => '-q mpi -n 16 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"',
            'SLURM'  => '--partition=standard --cpus-per-task=16 --mem=8g',
        },

        '8Gb_24c_mpi' => {
            'LSF'    => '-q mpi -n 24 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=12]"',
            'SLURM'  => '--partition=standard --cpus-per-task=24 --mem=8g',
        },

        '8Gb_32c_mpi' => {
            'LSF'    => '-q mpi -n 32 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"',
            'SLURM'  => '--partition=standard --cpus-per-task=32 --mem=8g',
        },

        '8Gb_48c_mpi' => {
            'LSF'    => '-q mpi -n 48 -M8000 -R"select[mem>8000] rusage[mem=8000] same[model] span[ptile=16]"',
            'SLURM'  => '--partition=standard --cpus-per-task=48 --mem=8g',
        },

        '16Gb_4c_mpi' => {
            'LSF'    => '-q mpi -n 4 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=4]"',
            'SLURM'  => '--partition=standard --cpus-per-task=4 --mem=16g',
        },

        '16Gb_8c_mpi' => {
            'LSF'    => '-q mpi -n 8 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=8]"',
            'SLURM'  => '--partition=standard --cpus-per-task=8 --mem=16g',
        },

        '16Gb_16c_mpi' => {
            'LSF'    => '-q mpi -n 16 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=16]"',
            'SLURM'  => '--partition=standard --cpus-per-task=16 --mem=16g',
        },

        '16Gb_24c_mpi' => {
            'LSF'    => '-q mpi -n 24 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=12]"',
            'SLURM'  => '--partition=standard --cpus-per-task=24 --mem=16g',
        },

        '16Gb_32c_mpi' => {
            'LSF'    => '-q mpi -n 32 -M16000 -R"select[mem>16000] rusage[mem=16000] same[model] span[ptile=16]"',
            'SLURM'  => '--partition=standard --cpus-per-task=32 --mem=16g',
        },

        '32Gb_4c_mpi' => {
            'LSF'    => '-q mpi -n 4 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=4]"',
            'SLURM'  => '--partition=standard --cpus-per-task=4 --mem=32g',
        },

        '32Gb_8c_mpi' => {
            'LSF'    => '-q mpi -n 8 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=8]"',
            'SLURM'  => '--partition=standard --cpus-per-task=8 --mem=32g',
        },

        '32Gb_16c_mpi' => {
            'LSF'    => '-q mpi -n 16 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"',
            'SLURM'  => '--partition=standard --cpus-per-task=16 --mem=32g',
        },

        '32Gb_24c_mpi' => {
            'LSF'    => '-q mpi -n 24 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=12]"',
            'SLURM'  => '--partition=standard --cpus-per-task=24 --mem=32g',
        },

        '32Gb_32c_mpi' => {
            'LSF'    => '-q mpi -n 32 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"',
            'SLURM'  => '--partition=standard --cpus-per-task=32 --mem=32g',
        },

        '32Gb_48c_mpi' => {
            'LSF'    => '-q mpi -n 48 -M32000 -R"select[mem>32000] rusage[mem=32000] same[model] span[ptile=16]"',
            'SLURM'  => '--partition=standard --cpus-per-task=48 --mem=32g',
        },

        '64Gb_4c_mpi' => {
            'LSF'    => '-q mpi -n 4 -M64000 -R"select[mem>64000] rusage[mem=64000] same[model] span[ptile=4]"',
            'SLURM'  => '--partition=standard --cpus-per-task=4 --mem=64g',
        },
    };

    my $long_running_rc_keys = [
        '2Gb_2c_job',
        '4Gb_4c_job',
        '8Gb_8c_job',
        '64Gb_8c_job',
        '96Gb_8c_job',
        '8Gb_16c_job',
        '32Gb_16c_job',
        '64Gb_16c_job',
        '128Gb_16c_job',
        '16Gb_32c_job',
        '32Gb_32c_job',
        '64Gb_32c_job',
        '128Gb_32c_job',
        '16Gb_48c_job',
        '64Gb_48c_job',
        '128Gb_48c_job',
        '256Gb_48c_job',
    ];

    my $resource_classes = _generate_resource_classes($resource_class_templates, $long_running_rc_keys);

    _apply_common_rc_config($self, $resource_classes);

    return $resource_classes;
}

sub _apply_common_rc_config {
    my ($pipe_config, $resource_classes) = @_;

    my $local_submission_cmd_args = '';
    my $worker_cmd_args = sprintf('--reg_conf %s', $pipe_config->o('reg_conf'));
    while (my ($rc_name, $rc_config) = each %{$resource_classes}) {
        $rc_config->{'LOCAL'} = [$local_submission_cmd_args];

        while (my ($meadow_name, $meadow_config) = each %{$rc_config}) {
            push(@{$meadow_config}, $worker_cmd_args);
        }
    }
}

sub _generate_resource_classes {
    my ($resource_class_templates, $long_running_rc_keys) = @_;

    my %time_limits = (
        '1_hour' => {
            'LSF'   => '',
            'SLURM' => '--time=1:00:00',
        },
        '24_hour' => {
            'LSF'   => '',
            'SLURM' => '--time=24:00:00',
        },
        '168_hour' => {
            'LSF'   => '',
            'SLURM' => '--time=168:00:00',
        },
        '720_hour' => {
            'LSF'   => '-q long -W 720:00',
            'SLURM' => '--time=720:00:00',
        },
    );

    my $resource_classes;
    while (my ($rc_key, $submission_cmd_config) = each %{$resource_class_templates}) {
        while (my ($time_limit_name, $time_limit_config) = each %time_limits) {

            if ($time_limit_name eq '720_hour' && !grep { $_ eq $rc_key } @{$long_running_rc_keys}) {
                next;
            }

            my $rc_name = $rc_key;
            if ($time_limit_name ne '24_hour') {
                next if ($rc_key =~ /_mpi$/);
                $rc_name =~ s/(?=_job$)/_${time_limit_name}/;
            }

            while (my ($meadow_name, $submission_cmd_args) = each %{$submission_cmd_config}) {
                my $time_limit_arg = $time_limit_config->{$meadow_name};
                if ($time_limit_arg) {
                    $submission_cmd_args = "$submission_cmd_args $time_limit_arg";
                }
                $resource_classes->{$rc_name}{$meadow_name} = [$submission_cmd_args];
            }
        }
    }

    return $resource_classes;
}

1;
