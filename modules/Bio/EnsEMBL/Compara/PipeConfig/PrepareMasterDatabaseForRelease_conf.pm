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

Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesIntoMaster_conf

=head1 DESCRIPTION

    Add/update all species to master database


=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PrepareMasterDatabaseForRelease_conf -password <your_password> -inputfile file_new_species_production_names.txt

    #1. fetch species from text file
    #2. add all to master_db

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

=cut

package Bio::EnsEMBL::Compara::PipeConfig::PrepareMasterDatabaseForRelease_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub no_compara_schema {};

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'email'                     => $self->o('ENV', 'USER').'@ebi.ac.uk',
        'host'                      => 'mysql-ens-compara-prod-4:4401',
        #'host'                      => 'mysql-ens-compara-prod-1:4485',
        'work_dir'                  => '/hps/nobackup2/production/ensembl/' . $self->o( 'ENV', 'USER' ) . '/compara/'.$self->o('pipeline_name'),
        'reg_conf'                  => $self->o( 'ENV', 'ENSEMBL_CVS_ROOT_DIR' ) .'/ensembl-compara/scripts/pipeline/production_reg_' . $self->o('division') . '_conf.pl',
        'master_db'                 => 'compara_master',
        'release'                   => $self->o( 'ENV', 'CURR_ENSEMBL_RELEASE' ),
        'division'                  => $self->o( 'ENV', 'COMPARA_DIV' ),
        'incl_components'           => 1, # let's default this to 1 - will have no real effect if there are no component genomes (e.g. in vertebrates) 
        'create_all_mlss_exe'       => $self->o( 'ENV', 'ENSEMBL_CVS_ROOT_DIR' ) . '/ensembl-compara/scripts/pipeline/create_all_mlss.pl',
        'xml_file'                  => $self->o( 'ENV', 'ENSEMBL_CVS_ROOT_DIR' ) . '/ensembl-compara/scripts/pipeline/compara_' . $self->o('division') . '.xml',
        'report_file'               => $self->o( 'ENV', 'ENSEMBL_CVS_ROOT_DIR' ) . '/ensembl-compara/mlss_ids_' . $self->o('division') . '.list',
    };
}

# This section has to be filled in any derived class
sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         'default'           => {'LSF' => ['-C0 -M250   -R"select[mem>250]   rusage[mem=250]"', $reg_requirement] },
         '2Gb_job'          => {'LSF' => ['-C0 -M2000 -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement] },
         '16Gb_job'          => {'LSF' => ['-C0 -M16000 -R"select[mem>16000]  rusage[mem=16000]"', $reg_requirement] },
    };
}



sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        'mkdir -p '.$self->o('work_dir'),
    ];
}


sub pipeline_wide_parameters {  
# these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'master_db'     => $self->o('master_db'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'create_jobs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'column_names' => [ 'species_name' ],
            },
            -input_ids => [
                {
                    'inputfile' => $self->o('inputfile'), # A file with species names, one per line 
                },
            ],
            -flow_into => {
                '2->A' => [ 'add_species_into_master'  ],
                'A->1' => [ 'update_collection' ], 
            },
        },

        {   -logic_name     => 'add_species_into_master',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::AddSpeciesToMasterDatabase',
            -parameters => {
                    'release'           => $self->o('release'),
            },
            -hive_capacity  => 10,
            -rc_name        => '16Gb_job',
        },

        {   -logic_name => 'update_collection',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CreateReleaseCollection',
            -parameters => {
                    'collection_name'   => $self->o('division'),
                    'incl_components'   => $self->o('incl_components'),
                    'release'           => $self->o('release'),
            },
            -flow_into  => [ 'add_mlss_to_master' ],
        },

        {   -logic_name => 'add_mlss_to_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'create_all_mlss_exe'   => $self->o('create_all_mlss_exe'),
                'reg_conf'              => $self->o('reg_conf'),
                'master_db'             => $self->o('master_db'),
                'xml_file'              => $self->o('xml_file'),
                'report_file'           => $self->o('report_file'),
                'cmd'                   => 'perl #create_all_mlss_exe# --reg_conf #reg_conf# --compara #master_db# -xml #xml_file# --release --output_file #report_file# --verbose',
            },
            -rc_name        => '2Gb_job',
            -flow_into  => [ 'backbone_pipeline_finished' ],
        },
        
        {   -logic_name => 'backbone_pipeline_finished',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

    ];
}

1;

