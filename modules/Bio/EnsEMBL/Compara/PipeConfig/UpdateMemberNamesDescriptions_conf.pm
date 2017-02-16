=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::UpdateMemberNamesDescriptions_conf

=head1 DESCRIPTION  

The PipeConfig file for the pipeline that imports alternative alleles as homologies.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::UpdateMemberNamesDescriptions_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'host'            => 'compara5',    # where the pipeline database will be created

        'pipeline_name'   => 'member_description_update_'.$self->o('rel_with_suffix'),   # also used to differentiate submitted processes

        'reg_conf'        => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_conf.pl",

        #Pipeline capacities:
        'update_capacity'                           => '5',

    };
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}



sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        '500Mb_job'    => { 'LSF' => ['-C0 -M500 -R"select[mem>500] rusage[mem=500]"', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {
            -logic_name => 'species_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -input_ids  => [ {
                    'compara_db' => $self->o('compara_db'),
                    'db_conn'    => '#compara_db#',
                } ],
            -flow_into => {
                2   => [ 'update_member_display_labels' ],
            },
        },

        {
            -logic_name => 'update_member_display_labels',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
            -analysis_capacity => $self->o('update_capacity'),
            -parameters => {
                'die_if_no_core_adaptor'  => 1,
                'replace'                 => 1,
                'mode'                    => 'display_label',
                'source_name'             => 'ENSEMBLGENE',
                'genome_db_ids'           => [ '#genome_db_id#' ],
            },
            -flow_into => [ 'update_seq_member_display_labels' ],
            -rc_name => '500Mb_job',
        },

        {
            -logic_name => 'update_seq_member_display_labels',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
            -analysis_capacity => $self->o('update_capacity'),
            -parameters => {
                'die_if_no_core_adaptor'  => 1,
                'replace'                 => 1,
                'mode'                    => 'display_label',
                'source_name'             => 'ENSEMBLPEP',
                'genome_db_ids'           => [ '#genome_db_id#' ],
            },
            -flow_into => [ 'update_member_descriptions' ],
            -rc_name => '500Mb_job',
        },

        {
            -logic_name => 'update_member_descriptions',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
            -analysis_capacity => $self->o('update_capacity'),
            -parameters => {
                'die_if_no_core_adaptor'  => 1,
                'replace'                 => 1,
                'mode'                    => 'description',
                'genome_db_ids'           => [ '#genome_db_id#' ],
            },
            -rc_name => '500Mb_job',
        },

    ];
}

1;


