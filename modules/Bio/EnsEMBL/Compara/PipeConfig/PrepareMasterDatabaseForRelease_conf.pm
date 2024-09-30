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

Bio::EnsEMBL::Compara::PipeConfig::PrepareMasterDatabaseForRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PrepareMasterDatabaseForRelease_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division <division>

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PrepareMasterDatabaseForRelease_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division <division> -additional_species <optional hash> -meta_host <alternative metadata host>

    #1. Update NCBI taxonomy
    #2. Add/update all species to master database
    #3. Update master database's metadata
    #4. Update collections and mlss

=head1 DESCRIPTION

Prepare master database of the given division for next release.

WARNING: the previous reports and backups will be removed if the pipeline is
initialised again for the same division and release.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::PrepareMasterDatabaseForRelease_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::PrepareMasterDatabaseForRelease;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub no_compara_schema {};

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'pipeline_name'       => 'prep_' . $self->o('division') . '_master_for_rel_' . $self->o('rel_with_suffix'),
        'work_dir'    => $self->o('pipeline_dir'),
        'backups_dir' => $self->o('work_dir') . '/master_backups/',

        'master_db'           => 'compara_master',
        'prev_dbs'            => ['*_prev'],
        'taxonomy_db'         => 'ncbi_taxonomy',
        'incl_components'     => 1, # let's default this to 1 - will have no real effect if there are no component genomes (e.g. in vertebrates)
        'create_all_mlss_exe' => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/create_all_mlss.pl'),
        'xml_file'            => $self->check_file_in_ensembl('ensembl-compara/conf/' . $self->o('division') . '/mlss_conf.xml'),
        'report_file'         => $self->o( 'work_dir' ) . '/mlss_ids_' . $self->o('division') . '.list',
        'annotation_file'     => $self->o('work_dir') . '/annotation_updates.' . $self->o('division') . '.' . $self->o('ensembl_release') . '.list',
        'master_backup_file'  => $self->o('backups_dir') . '/compara_master_' . $self->o('division') . '.post' . $self->o('ensembl_release') . '.sql',

        'patch_dir'   => $self->check_dir_in_ensembl('ensembl-compara/sql/'),
        'schema_file' => $self->check_file_in_ensembl('ensembl-compara/sql/table.sql'),
        'alias_file'  => $self->check_file_in_ensembl('ensembl-compara/scripts/taxonomy/ensembl_aliases.sql'),

        'list_genomes_script'    => $self->check_exe_in_ensembl('ensembl-metadata/misc_scripts/get_list_genomes_for_division.pl'),
        'report_genomes_script'  => $self->check_exe_in_ensembl('ensembl-metadata/misc_scripts/report_genomes.pl'),
        'update_metadata_script' => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/update_master_db.pl'),
        'assembly_patch_species' => [],
        'additional_species_file' => undef,
        'species_trees'          => undef,

        'do_update_from_metadata' => 1,
        'do_load_timetree'        => 0,

        'meta_host'      => 'mysql-ens-meta-prod-1',
        'perc_threshold' => 20,
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'backups_dir']),
    ];
}


sub pipeline_wide_parameters {
# these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'master_db'  => $self->o('master_db'),
        'division'   => $self->o('division'),
        'release'    => $self->o('ensembl_release'),
        'hc_version' => 1,
        # Define the flags so they can be seen by Parts::PrepareMasterDatabaseForRelease
        'do_update_from_metadata' => $self->o('do_update_from_metadata'),
        'do_load_timetree'        => $self->o('do_load_timetree'),
    };
}

sub core_pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'backup_current_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -input_ids  => [{ }],
            -parameters => {
                'src_db_conn' => '#master_db#',
                'backups_dir' => $self->o('backups_dir'),
                'output_file' => '#backups_dir#/compara_master_#division#.pre#release#.sql'
            },
            -flow_into => [ 'patch_master_db' ],
            -rc_name   => '1Gb_job'
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::PrepareMasterDatabaseForRelease::pipeline_analyses_prep_master_db_for_release($self) },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    if (defined $self->o('additional_species_file')) {
        $analyses_by_name->{'update_genome_from_metadata_factory'}->{'-parameters'}{'additional_species_file'} = $self->o('additional_species_file');
    }
}

1;
