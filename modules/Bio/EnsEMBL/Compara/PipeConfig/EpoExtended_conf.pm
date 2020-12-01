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

Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -species_set_name <species_set_name> -low_epo_mlss_id <curr_epo_2x_mlss_id> \
        -base_epo_mlss_id <curr_epo_mlss_id>

=head1 EXAMPLES

    # With GERP (mammals, sauropsids, fish):
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division vertebrates -species_set_name fish -low_epo_mlss_id 1333 -base_epo_mlss_id 1332

    # Without GERP (primates):
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division vertebrates -species_set_name primates -low_epo_mlss_id 1141 -base_epo_mlss_id 1134 -run_gerp 0

=head1 DESCRIPTION

PipeConfig file for the EPO Extended (previously known as EPO-2X or EPO Low
Coverage) pipeline.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

use Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoExtended;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

    'pipeline_name' => $self->o('species_set_name').'_epo_extended_'.$self->o('rel_with_suffix'),

        'master_db' => 'compara_master',
        # Location of compara db containing EPO/EPO_EXTENDED alignment to use as a base
        'epo_db'    => $self->o('species_set_name') . '_epo',

	'low_epo_mlss_id' => $self->o('low_epo_mlss_id'),   #mlss_id for low coverage epo alignment
	'base_epo_mlss_id' => $self->o('base_epo_mlss_id'), #mlss_id for the base alignment we're topping up
                                                        # (can be EPO or EPO_EXTENDED)
	'mlss_id' => $self->o('low_epo_mlss_id'),   #mlss_id for low coverage epo alignment, needed for the alignment stats

        # Default location for pairwise alignments (can be a string or an array-ref,
        # and the database aliases can include '*' as a wildcard character)
        'pairwise_location' => [ qw(compara_prev lastz_batch_* unidir_lastz) ],

	'max_block_size'  => 1000000,                       #max size of alignment before splitting 

	 #gerp parameters
        'run_gerp' => 1,
	'gerp_window_sizes'    => [1,10,100,500],         #gerp window sizes

        #
        #Default statistics
        #
        'skip_multiplealigner_stats' => 0, #skip this module if set to 1

        'work_dir'   => $self->o('pipeline_dir'),
        'bed_dir' => $self->o('work_dir') . '/bed_dir/',
        'output_dir' => $self->o('work_dir') . '/feature_dumps/',
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'output_dir', 'bed_dir']),
	   ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
			'mlss_id' => $self->o('low_epo_mlss_id'),
            'run_gerp' => $self->o('run_gerp'),
            'genome_dumps_dir' => $self->o('genome_dumps_dir'),
            'reg_conf' => $self->o('reg_conf'),
            'low_epo_mlss_id' => $self->o('low_epo_mlss_id'),
            'base_epo_mlss_id' => $self->o('base_epo_mlss_id'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoExtended::pipeline_analyses_all($self) },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;
    $analyses_by_name->{'create_default_pairwise_mlss'}->{'-parameters'}->{'base_location'} = $self->o('epo_db');
}

1;
