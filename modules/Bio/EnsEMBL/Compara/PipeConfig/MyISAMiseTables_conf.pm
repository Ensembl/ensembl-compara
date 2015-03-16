=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::MyISAMiseTables_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MyISAMiseTables_conf -password <your_password>

=head1 DESCRIPTION  

A pipeline to turn all release tables into MyISAM

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MyISAMiseTables_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.
                  In addition to the standard things it defines four options:
                    o('fixing_capacity')   defines how many tables can be worked on in parallel
                
                  There are rules dependent on two options that do not have defaults (this makes them mandatory):
                    o('password')       your read-write password for creation and maintenance of the hive database

=cut

sub default_options {
    my ($self) = @_;
    return {

        'pipeline_name' => 'myisamise_compara_release',            # name used by the beekeeper to prefix job names on the farm

        'pipeline_db' => {
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $ENV{USER}.'_'.$self->o('pipeline_name'),
        },

        'rel_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'kb3_ensembl_compara_59',
        },

        'fixing_capacity'  => 10,                                  # how many tables can be worked on in parallel (too many will slow the process down)
    };
}

=head2 pipeline_create_commands

    Description : Implements pipeline_create_commands() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that lists the commands that will create and set up the Hive database.
                  In addition to the standard creation of the database and populating it with Hive tables and procedures it also creates a directory for storing the output.

=cut

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
    ];
}

=head2 pipeline_analyses

    Description : Implements pipeline_analyses() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that defines the structure of the pipeline: analyses, jobs, rules, etc.
                  Here it defines two analyses:

                    * 'generate_job_list'   generates a list of tables to be copied from master_db

                    * 'myisamise_table'     turn that table's engine into MyISAM

=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'generate_job_list',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'         => $self->o('rel_db'),
                'fan_branch_code' => 2,
            },
            -input_ids => [
                { 'inputquery' => "SELECT table_name FROM information_schema.tables WHERE table_schema ='#mysql_dbname:db_conn#' AND engine='InnoDB' " },
            ],
            -flow_into => {
                2 => [ 'myisamise_table'  ],
            },
        },

        {   -logic_name    => 'myisamise_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'db_conn'     => $self->o('rel_db'),
                'sql'         => "ALTER TABLE #table_name# ENGINE=MyISAM",
            },
            -hive_capacity => $self->o('fixing_capacity'),       # allow several workers to perform identical tasks in parallel
        },
    ];
}

1;

