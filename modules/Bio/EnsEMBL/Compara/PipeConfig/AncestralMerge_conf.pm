=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::AncestralMerge_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::AncestralMerge_conf -password <your_password>

=head1 DESCRIPTION  

    A pipeline to create the EnsEMBL core database with ancestral sequences merged from different sources.

    In rel.64 it took ~30min to run.
    In rel.65 it took ~38min to run.
    In rel.71 it took 

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::AncestralMerge_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
         %{$self->SUPER::default_options},

         # The production database itself (will be created). That's where the ancestral sequences will be
        'pipeline_name' => 'ensembl_ancestral_'.$self->o('rel_with_suffix'),
        'host'          => 'mysql-ens-compara-prod-1',
        'port'          => 4485,

        'merge_script'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/copy_ancestral_core.pl',

        'prev_ancestral_db' => 'mysql://ensadmin:' . $self->o('password') . '@mysql-ens-compara-prod-1:4485/ensembl_ancestral_91',

        # map EPO mlss_ids to their source ancestral db
        'epo_mlsses' => [ # this table needs to be edited prior to running the pipeline:
            [ '1132' => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/muffato_fish_ancestral_core_92', ], # teleost fish
            [ '825'  => $self->o('prev_ancestral_db'), ], # sauropsids
            [ '1134' => 'mysql://ensro@mysql-ens-compara-prod-3.ebi.ac.uk:4523/carlac_primates_ancestral_core_92', ], # primates
            [ '1135' => 'mysql://ensro@mysql-ens-compara-prod-3.ebi.ac.uk:4523/muffato_mammals_ancestral_core_92',] # mammals
        ],

        # Redefined so that the database name is *not* prefixed with the user name
        'pipeline_db'   => {
            -driver => $self->o('hive_driver'),
            -host   => $self->o('host'),
            -port   => $self->o('port'),
            -user   => $self->o('user'),
            -pass   => $self->o('password'),
            -dbname => $self->o('pipeline_name'),
        },
    };
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'ensembl_release'       => $self->o('ensembl_release'),
        'prev_ancestral_db'     => $self->o('prev_ancestral_db'),
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},                                                              # inherit database and Hive tables' creation

        $self->db_cmd().' <'.$self->o('ensembl_cvs_root_dir').'/ensembl/sql/table.sql',     # add Core tables
    ];
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{ $self->SUPER::resource_classes() },
         'urgent'   => {  'LSF' => '' },
         'more_mem' => {  'LSF' => '-M5000 -R "select[mem>5000] rusage[mem=5000]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'copy_coord_system',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#prev_ancestral_db#',
                'table'         => 'coord_system',
                'mode'          => 'insertignore',
            },
            -input_ids  => [ {} ],
            -flow_into  => {
                1 => [ 'generate_merge_jobs' ],
            },
            -rc_name => 'urgent',
        },

        {   -logic_name => 'generate_merge_jobs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist' => $self->o('epo_mlsses'),
                'column_names' => [ 'mlss_id', 'from_url' ],
            },
            -flow_into => {
                2 => [ 'merge_an_ancestor' ],
            },
            -rc_name => 'urgent',
        },

        {   -logic_name    => 'merge_an_ancestor',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'to_url' => $self->pipeline_url(),
                'cmd'    => ['perl', $self->o('merge_script'), qw(--from_url #from_url# --to_url #to_url# --mlss_id #mlss_id#)],
            },
            -hive_capacity  => 1,   # do them one-by-one
            -rc_name => 'more_mem',
        },
    ];
}

1;

