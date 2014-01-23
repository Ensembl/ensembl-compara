=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');   # instead of Compara tables we actually want Core tables


sub default_options {
    my ($self) = @_;
    return {
         %{$self->SUPER::default_options},

        'rel_suffix'        => '',                                                  # empty string by default
        'rel_with_suffix'   => $self->o('ensembl_release').$self->o('rel_suffix'),  # for convenience

        'pipeline_name' => 'ensembl_ancestral_'.$self->o('rel_with_suffix'),        # name used by the beekeeper to prefix job names on the farm

        'merge_script'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/copy_ancestral_core.pl',

        'prev_ancestral_db' => 'mysql://ensadmin:' . $self->o('password') . '@compara3/mp12_ensembl_ancestral_74',

        'reservation_sfx' => '',    # set to '000' for farm2, to '' for farm3 and EBI
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
         'urgent'   => {  'LSF' => '-q yesterday' },
         'more_mem' => {  'LSF' => '-M5000'.$self->o('reservation_sfx').' -R "select[mem>5000] rusage[mem=5000]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'copy_coord_system',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('prev_ancestral_db'),
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
                'inputlist'         => [        # this table needs to be edited prior to running the pipeline:
                        # copying from previous release:
                                        [ '528' => $self->o('prev_ancestral_db'), ],     # 5 teleost fish
                                        [ '548' => $self->o('prev_ancestral_db'), ],     # 6 primates
                                        [ '647' => $self->o('prev_ancestral_db'), ],     # 4 sauropsids
                                        [ '654' => $self->o('prev_ancestral_db'), ],     # 15 eutherian mammals

                        # copying from new sources:
#                     [ '548' => 'mysql://ensadmin:'.$self->o('password').'@compara4/sf5_ancestral_sequences_core_71' ],   # 6-way primates
#                     [ '641' => 'mysql://ensadmin:'.$self->o('password').'@compara3/sf5_3birds_ancestral_sequences_core_71' ],  # 3-way birds
                ],
            },
            -flow_into => {
                2 => { 'merge_an_ancestor' => { 'mlss_id' => '#_0#', 'from_url' => '#_1#' } },
            },
            -rc_name => 'urgent',
        },

        {   -logic_name    => 'merge_an_ancestor',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'to_url' => $self->dbconn_2_url('pipeline_db'),
                'cmd'    => 'perl ' . $self->o('merge_script').' --from_url #from_url# --to_url #to_url# --mlss_id #mlss_id#',
            },
            -hive_capacity  => 1,   # do them one-by-one
            -rc_name => 'more_mem',
        },
    ];
}

1;

