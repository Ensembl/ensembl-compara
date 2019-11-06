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

## Configuration file for the Epo Low Coverage pipeline

package Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

use Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoLowCoverage;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

    'pipeline_name' => $self->o('species_set_name').'_epo_low_coverage_'.$self->o('rel_with_suffix'),

	'low_epo_mlss_id' => $self->o('low_epo_mlss_id'),   #mlss_id for low coverage epo alignment
	'base_epo_mlss_id' => $self->o('base_epo_mlss_id'), #mlss_id for the base alignment we're topping up
                                                        # (can be EPO or EPO_LOW_COVERAGE)
	'mlss_id' => $self->o('low_epo_mlss_id'),   #mlss_id for low coverage epo alignment, needed for the alignment stats

	'max_block_size'  => 1000000,                       #max size of alignment before splitting 

	 #gerp parameters
        'run_gerp' => 1,
	'gerp_window_sizes'    => [1,10,100,500],         #gerp window sizes

        #
        #Default statistics
        #
        'skip_multiplealigner_stats' => 0, #skip this module if set to 1
        'bed_dir' => $self->o('work_dir') . '/bed_dir/',
        'output_dir' => $self->o('work_dir') . '/feature_dumps/',
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        $self->pipeline_create_commands_rm_mkdir(['output_dir', 'bed_dir']),
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
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoLowCoverage::pipeline_analyses_all($self) },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;
        
    $analyses_by_name->{'create_default_pairwise_mlss'}->{'-parameters'}->{'use_epo_coverage'} = 1;
}

1;
