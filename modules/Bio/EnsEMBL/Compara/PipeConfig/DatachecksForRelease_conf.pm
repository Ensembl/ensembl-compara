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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::DatachecksForRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DatachecksForRelease_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION

The pipeline configuration that runs compara datachecks for the current release database

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DatachecksForRelease_conf;


use strict;
use warnings;
use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # for WHEN and INPUT_PLUS

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        division      => undef,
        pipeline_name => $self->o('division').'_datachecks_'.$self->o('rel_with_suffix'),
        registry_file => $self->o('reg_conf'),
        db_type       => 'compara',
        compara_db    => 'compara_curr',

        history_file       => '/nfs/panda/ensembl/production/datachecks/history/compara.json',
        output_dir_path    => $self->o('pipeline_dir').'/tapfile',
        datacheck_groups   => ['compara'],
        datacheck_types    => ['critical'],
        datacheck_names    => [],
        datacheck_patterns => [],
        species            => [],
        taxons             => [],
        antispecies        => [],
        antitaxons         => [],

        overwrite_files        => 1,
        failures_fatal         => 0,
        parallelize_datachecks => 1,

        meta_filters  => {},
        tag           => undef,
        timestamp     => undef,
        email         => undef,
        report_per_db => 0,
        report_all    => 0,
        run_all       => 0,

        tap_to_json     => 1,
        json_passed     => 0,
        json_by_species => 1,

        # Datacheck Jira ticket creation executable_location
        cvs_root_dir         => $ENV{'ENSEMBL_CVS_ROOT_DIR'},
        create_datacheck_tickets_exe => $self->o('cvs_root_dir').'/ensembl-compara/scripts/jira_tickets/create_datacheck_tickets.pl',
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes()},
    };
}

sub hive_meta_table {
    my ($self) = @_;

    return {
        %{$self->SUPER::hive_meta_table},
        'hive_use_param_stack' => 1,
    };
}

sub pipeline_create_commands {
    my ($self) = @_;

    my $submission_table_sql = q/
        CREATE TABLE datacheck_submission (
            submission_job_id INT PRIMARY KEY,
            history_file VARCHAR(255) NULL,
            output_dir VARCHAR(255) NULL,
            tag VARCHAR(255) NULL,
            email VARCHAR(255) NULL,
            submitted VARCHAR(255) NULL
        );
    /;

    my $results_table_sql = q/
        CREATE TABLE datacheck_results (
            submission_job_id INT,
            dbname VARCHAR(255) NOT NULL,
            passed INT,
            failed INT,
            skipped INT,
            INDEX submission_job_id_idx (submission_job_id)
        );
    /;

    my $result_table_sql = q/
        CREATE TABLE result (
            job_id INT PRIMARY KEY,
            output TEXT
        );
    /;

    my $drop_input_id_index = q/
        ALTER TABLE job DROP KEY input_id_stacks_analysis;
    /;

    my $extend_input_id = q/
        ALTER TABLE job MODIFY input_id TEXT;
    /;

    return [
        @{$self->SUPER::pipeline_create_commands},
        $self->db_cmd($submission_table_sql),
        $self->db_cmd($results_table_sql),
        $self->db_cmd($result_table_sql),
        $self->db_cmd($drop_input_id_index),
        $self->db_cmd($extend_input_id),
        $self->pipeline_create_commands_rm_mkdir(['pipeline_dir','output_dir_path']),
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},
        registry_file    => $self->o('reg_conf'),
        db_type          => $self->o('db_type'),
        compara_db       => $self->o('compara_db'),
        output_dir_path  => $self->o('output_dir_path'),
        meta_filters     => $self->o('meta_filters'),
        history_file     => $self->o('history_file'),

        datacheck_names    => $self->o('datacheck_names'),
        datacheck_patterns => $self->o('datacheck_patterns'),
        datacheck_groups   => $self->o('datacheck_groups'),
        datacheck_types    => $self->o('datacheck_types'),

        run_all                => $self->o('run_all'),
        report_all             => $self->o('report_all'),
        report_per_db          => $self->o('report_per_db'),
        overwrite_files        => $self->o('overwrite_files'),
        failures_fatal         => $self->o('failures_fatal'),
        parallelize_datachecks => $self->o('parallelize_datachecks'),
        tap_to_json            => $self->o('tap_to_json'),
        json_by_species        => $self->o('json_by_species'),
        json_passed            => $self->o('json_passed'),
        taxons                 => $self->o('taxons'),
        antispecies            => $self->o('antispecies'),
        antitaxons             => $self->o('antitaxons'),
    };
}

sub pipeline_analyses {
    my $self = shift @_;

    return [
        {
            -logic_name        => 'DataCheckSubmission',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::DataCheckSubmission',
            -input_ids         => [ { } ],
            -analysis_capacity => 1,
            -max_retry_count   => 1,
            -flow_into         => {
                '1' => [ 'GetComparaDBName' ],
                '3' => [ '?table_name=datacheck_submission' ],
            },
        },

        {
            -logic_name        => 'GetComparaDBName',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::GetComparaDBName',
            -analysis_capacity => 1,
            -max_retry_count   => 0,
            -flow_into         => {
                '1' => { 'DbFactory' },
            },
        },

        {
            -logic_name        => 'DbFactory',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
            -analysis_capacity => 10,
            -max_retry_count   => 0,
            -parameters        => {
                division         => [
                    $self->o('division'),
                ],
                datacheck_groups => [
                    'compara',
                ],
                datacheck_types  => [
                    'critical',
                ],
            },
            -flow_into         => {
                '2->A' => 
                    WHEN(
                        '#parallelize_datachecks#' => [ 'DataCheckFactory' ],
                        ELSE [ 'RunDataChecks' ]
                    ),
                'A->1' => [ 'DataCheckResults' ],
            },
        },

        {
            -logic_name        => 'RunDataChecks',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::RunDataChecks',
            -analysis_capacity => 10,
            -max_retry_count   => 0,
            -rc_name           => '2Gb_job',
            -flow_into         => {
                '1'  => [ 'StoreResults' ],
                '-1' => [ 'RunDataChecks_High_mem' ]
            },
        },

        {
            -logic_name        => 'RunDataChecks_High_mem',  
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::RunDataChecks',
            -analysis_capacity => 10,
            -max_retry_count   => 0,
            -rc_name           => '2Gb_job',
            -flow_into         => {
                '1' => [ 'StoreResults' ],
            },
        },

        {
            -logic_name        => 'DataCheckFactory',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::DataCheckFactory',
            -analysis_capacity => 10,
            -max_retry_count   => 0,
            -flow_into         => {
                '2->A' => [ 'DataCheckFan' ],
                'A->1' => [ 'DataCheckFunnel' ],
            },
        },

        {
            -logic_name        => 'DataCheckFan',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -analysis_capacity => 100,
            -max_retry_count   => 0,
            -rc_name           => '500Mb_job',
            -flow_into         => {
                '1'  => [ '?accu_name=results&accu_address=[]' ],
                '-1' => [ 'DataCheckFan_High_mem' ],
                '2'  => [ 'JiraTicketCreation' ],
            },
        },

        {
            -logic_name        => 'DataCheckFan_High_mem',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -analysis_capacity => 100,
            -max_retry_count   => 0,
            -rc_name           => '2Gb_job',
            -flow_into         => {
                '1' => [ '?accu_name=results&accu_address=[]' ],
                '2' => [ 'JiraTicketCreation' ],
            },
        },

        {
            -logic_name        => 'JiraTicketCreation',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::CreateDCJiraTickets',
            -parameters        => {
                division                     => '#division#',
                release                      => '#ensembl_release#',
                update                       => 1,
                create_datacheck_tickets_exe => $self->o('create_datacheck_tickets_exe'),
            },
            -analysis_capacity => 1,
            -max_retry_count   => 0,
        },

        {
            -logic_name        => 'DataCheckFunnel',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::DataCheckFunnel',
            -analysis_capacity => 1,
            -batch_size        => 100,
            -max_retry_count   => 0,
            -rc_name           => '2Gb_job',
            -flow_into         => {
                '1' => [ 'StoreResults' ],
            },
        },

        {
            -logic_name        => 'StoreResults',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::StoreResults',
            -analysis_capacity => 10,
            -max_retry_count   => 1,
            -flow_into         => {
                '3' => [ '?table_name=datacheck_results' ],
                '4' => [ 'EmailReport' ],
            },
        },

        {
            -logic_name        => 'EmailReport',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailReport',
            -analysis_capacity => 10,
            -batch_size        => 100,
            -max_retry_count   => 0,
        },

        {
            -logic_name        => 'DataCheckResults',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -max_retry_count   => 0,
            -flow_into         => {
                '1' =>  
                    WHEN( 
                        '#output_dir# && #tap_to_json#' => [ 'ConvertTapToJson' ],
                        ELSE [ 'DataCheckSummary' ]
                    ),
            },
        },

        {
            -logic_name        => 'ConvertTapToJson',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::ConvertTapToJson',
            -analysis_capacity => 10,
            -max_retry_count   => 0,
            -parameters        => {
                tap => '#output_dir#',
            },
            -flow_into         => [ 'DataCheckSummary' ],
        },

        {
            -logic_name        => 'DataCheckSummary',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::DataCheckSummary',
            -analysis_capacity => 10,
            -max_retry_count   => 0,
            -flow_into         => [ '?table_name=result' ],
        },
    ];
}

1;
