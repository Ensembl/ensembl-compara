=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::EBI::CITest::BuildCITestMasterDatabase_conf

=head1 DESCRIPTION

    Create a new master database from scratch from a set of species' regions
    (from core databases) that will be cloned before copying their information
    into the new master database. This pipeline requires a configuration
    directory (parameter 'config_dir') that contains:
        - a "core" subdirectory with one JSON file per species (following the format described in
          https://github.com/Ensembl/ensembl-test/blob/release/98/scripts/clone_core_database.pl),
          named with the species' scientific name with spaces replaced by
          underscores, e.g. 'homo_sapiens.json', 'mus_musculus.json'
        - initial registry configuration file with the information about the
          location of the core databases from which to clone the regions, and
          the location where the new master database will be created
        - XML file with all the desired method_link_species_set entries, named
          'mlss_conf.xml'

    WARNING: the previous reports and backups will be removed if the pipeline is
    initialised again for the same division

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::CITest::BuildCITestMasterDatabase_conf -dst_host <host> -dst_port <port>

    #1. Create a new master database
    #2. Clone data regions from JSON files located in 'config_dir'/core
    #3. Populate the new master database through PrepareMasterDatabaseForRelease pipeline

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::CITest::BuildCITestMasterDatabase_conf;

use strict;
use warnings;
use File::Spec;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Compara::PipeConfig::BuildNewMasterDatabase_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'      => 'citest',
        'compara_dir'   => $self->check_dir_in_ensembl('ensembl-compara/'),
        # NOTE: 'config_dir' is already in ENV but the check* method is not called on it
        #       Since it is essential for this pipeline, redefining it here with the checks
        'config_dir'    => $self->check_dir_in_ensembl('ensembl-compara/conf/' . $self->o('division')),
        'init_reg_conf' => $self->check_file_in_ensembl('ensembl-compara/conf/' . $self->o('division') . '/production_init_reg_conf.pl'),
        'reg_conf_tmpl' => $self->check_file_in_ensembl('ensembl-compara/conf/' . $self->o('division') . '/production_reg_conf_tmpl.pl'),

        # Change working directory
        'pipeline_name' => 'build_master',
        'work_dir'      => '/hps/nobackup2/production/ensembl/' . $ENV{'USER'} . '/' . $self->o('division') . '_division/' . $self->o('pipeline_name'),
        'backups_dir'   => $self->o('work_dir') . '/backups/',
        
        'do_clone_species' => 1,

        # PrepareMasterDatabaseForRelease pipeline configuration:
        'do_load_lrg_dnafrags' => 1,
        'do_load_timetree'     => 1,
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        # Inherit creation of database, hive tables and compara tables
        @{$self->SUPER::pipeline_create_commands},

        # Make a backup of the current registry configuration file and the Java
        # healthchecks database properties file
        'cp ' . $self->o('reg_conf') . ' ' . $self->o('backups_dir') . '/production_reg_' . $self->o('division') . '_conf.pl',
        'cp ' . $self->o('java_hc_db_prop') . ' ' . $self->o('backups_dir') . '/database.defaults.properties',
        # Replace the backed-up files by their default content to ensure a safe
        # setup to start of the pipeline
        'pushd ' . $self->o('compara_dir') . '; git checkout -- ' . $self->o('reg_conf') . '; popd',
        'pushd ' . $self->o('java_hc_dir') . '; git checkout -- ' . $self->o('java_hc_db_prop') . '; popd',
    ];
}

1;
