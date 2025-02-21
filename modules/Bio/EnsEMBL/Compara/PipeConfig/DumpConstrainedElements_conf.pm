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

Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf -host mysql-ens-compara-prodX -port XXXX \
        -compara_db $(mysql-ens-compara-prod-X details url ${USER}_mammals_epo_extended_${CURR_ENSEMBL_RELEASE}) \
        -mlss_id XXXX

=head1 DESCRIPTION

Pipeline to dump the contrained elements as BigBED files.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf;

use strict;
use warnings;
no warnings 'qw';

use Bio::EnsEMBL::Hive::Version v2.4;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Where to keep temporary files
        'work_dir'   => $self->o('pipeline_dir') . '/hash',

        # How many species can be dumped in parallel
        'dump_ce_capacity'    => 10,

        # Paths to compara files
        'ce_readme'             => $self->check_file_in_ensembl('ensembl-compara/docs/ftp/constrained_elements.txt'),
        'bigbed_autosql'        => $self->check_file_in_ensembl('ensembl-compara/scripts/pipeline/constrainedelements_autosql.as'),
    };
}


# Ensures species output parameter gets propagated implicitly
sub hive_meta_table {
    my ($self) = @_;

    return {
        %{$self->SUPER::hive_meta_table},
        'hive_use_param_stack'  => 1,
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'dump_features_exe'     => $self->o('dump_features_exe'),
        'ce_readme'             => $self->o('ce_readme'),

        'registry'      => $self->o('reg_conf'),
        'compara_db'   => $self->o('compara_db'),

        'export_dir'    => $self->o('pipeline_dir'),
        'work_dir'      => $self->o('work_dir'),
        'ce_output_dir'    => '#export_dir#/bed/ensembl-compara/#dirname#',
        'bed_file'   => '#work_dir#/#dirname#/gerp_constrained_elements.#name#.bed',
        'bigbed_file'   => '#ce_output_dir#/gerp_constrained_elements.#name#.bb',
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    
    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements::pipeline_analyses_dump_constrained_elems($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [ { mlss_id => $self->o('mlss_id') } ];

    return $pipeline_analyses;
}

1;
