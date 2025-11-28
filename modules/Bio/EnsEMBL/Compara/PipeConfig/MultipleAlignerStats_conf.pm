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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::MultipleAlignerStats_conf

=head1 DESCRIPTION

Pipeline that computes and stores statistics for a multiple alignment.

This pipeline requires three arguments: a 'compara_db' (to read the
alignment and store the stats), a 'division' name, and an 'mlss_id_list'
indicating the alignment MLSSes for which stats should be updated.

Note: This is usually embedded in all the multiple-alignment pipelines, but
is also available as a standalone pipeline in case the stats have to be
rerun or the alignment has been imported

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MultipleAlignerStats_conf \
        -compara_db compara_curr -division $COMPARA_DIV -mlss_id_list '[1234,5678]' \
        -host mysql-ens-compara-prod-X -port XXXX

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MultipleAlignerStats_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'pipeline_name' => $self->o('division') . '_msa_stats_' . $self->o('rel_with_suffix'),

        # Dump location
        'dump_dir'      => $self->o('pipeline_dir'),
        'bed_dir'       => $self->o('dump_dir') . '/' . 'bed_dir',
        'output_dir'    => $self->o('dump_dir') . '/' . 'feature_dumps',

        'msa_stats_shared_dir' => undef,
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_create_commands {
    my ($self) = @_;

    my $pipeline_create_commands = [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        $self->pipeline_create_commands_rm_mkdir(['output_dir', 'bed_dir']),
    ];

    if (defined $self->o('msa_stats_shared_dir')) {
        push(
            @{$pipeline_create_commands},
            $self->pipeline_create_commands_rm_mkdir(['msa_stats_shared_dir'], undef, 'do not rm')
        );
    }

    return $pipeline_create_commands;
}


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
    }
}
sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},       # here we inherit anything from the base class
        'compara_db'    => $self->o('compara_db'),

        'msa_stats_shared_dir'=> $self->o('msa_stats_shared_dir'),
    }
}



sub core_pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats::pipeline_analyses_multiple_aligner_stats($self);

    unshift(@{$pipeline_analyses}, {
        -logic_name => 'msa_stats_mlss_factory',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
        -input_ids  => [
            {
                'inputlist' => destringify($self->o('mlss_id_list')),
                'column_names' => [ 'mlss_id' ],
            }
        ],
        -flow_into  => {
            2 => [ 'set_multiplealigner_stats_table' ],
        },
    });

    return $pipeline_analyses;
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'gab_factory'}->{'-parameters'}->{'db_conn'} = '#compara_db#';
    $analyses_by_name->{'genome_db_factory'}->{'-parameters'}->{'db_conn'} = '#compara_db#';
    $analyses_by_name->{'genome_length_fetcher'}->{'-parameters'}->{'db_conn'} = '#compara_db#';
}


1;
