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

Bio::EnsEMBL::Compara::PipeConfig::AlignStatsCheck_conf

=head1 DESCRIPTION

Pipeline to check genomic alignment statistics.

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::AlignStatsCheck_conf \
        -compara_db compara_curr -division $COMPARA_DIV \
        -host mysql-ens-compara-prod-X -port XXXX

=cut

package Bio::EnsEMBL::Compara::PipeConfig::AlignStatsCheck_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'pipeline_name' => $self->o('division') . '_align_stats_check_' . $self->o('rel_with_suffix'),

        # List of methods for which coding exon stats are calculated.
        # Currently used in coding_exon_genome_factory and coding_exon_length_stats analyses.
        'coding_exon_method_types' => ['CACTUS_DB', 'EPO', 'EPO_EXTENDED', 'LASTZ_NET', 'PECAN'],
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},
        # Create CodingExon coverage statistics table
        $self->db_cmd('CREATE TABLE IF NOT EXISTS statistics (
        method_link_species_set_id  int(10) unsigned NOT NULL,
        genome_db_id                int(10) unsigned NOT NULL,
        dnafrag_id                  bigint unsigned NOT NULL,
        matches                     INT(10) DEFAULT 0,
        mis_matches                 INT(10) DEFAULT 0,
        ref_insertions              INT(10) DEFAULT 0,
        non_ref_insertions          INT(10) DEFAULT 0,
        uncovered                   INT(10) DEFAULT 0,
        coding_exon_length          INT(10) DEFAULT 0,
        PRIMARY KEY (method_link_species_set_id,dnafrag_id)
        ) COLLATE=latin1_swedish_ci ENGINE=InnoDB;'),
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'compara_db' => $self->o('compara_db'),
        'coding_exon_method_types' => $self->o('coding_exon_method_types'),
    }
}

sub core_pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'coding_exon_genome_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'all_in_current_mlsses_of_types' => '#coding_exon_method_types#',
            },
            -input_ids  => [ {} ],
            -rc_name    => '2Gb_job',
            -flow_into  => {
                '2->A' => [ 'coding_exon_dnafrag_factory' ],
                'A->1' => [ 'coding_exon_funnel_check' ],
            },
        },

        {   -logic_name => 'coding_exon_dnafrag_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DnaFragFactory',
            -rc_name    => '4Gb_24_hour_job',
            -hive_capacity => 50,
            -flow_into  => {
                2 => [ 'coding_exon_length_stats' ],
            },
        },

        {   -logic_name => 'coding_exon_length_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Alignment::CodingExonLengthStats',
            -rc_name    => '2Gb_job',
            -hive_capacity => 50,
        },

        {   -logic_name => 'coding_exon_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'align_stats_mlss_factory' ],
        },

        {   -logic_name => 'align_stats_mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory',
            -parameters => {
                'methods' => {
                    'CACTUS_DB' => 2,
                    'CACTUS_HAL' => 2,
                    'EPO' => 2,
                    'EPO_EXTENDED' => 2,
                    'LASTZ_NET' => 2,
                    'PECAN' => 2,
                },
            },
            -flow_into  => {
                2 => [ 'align_stats_check' ],
            },
        },

        {   -logic_name => 'align_stats_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Alignment::FlagOutdatedAlignStats',
            -analysis_capacity => 50,
            -rc_name    => '4Gb_job',
            -parameters => {
                'methods' => {
                    'CACTUS_DB' => 3,
                    'CACTUS_HAL' => 4,
                    'EPO' => 3,
                    'EPO_EXTENDED' => 3,
                    'LASTZ_NET' => 2,
                    'PECAN' => 3,
                },
            },
            -flow_into  => {
                2 => [ 'outdated_pwa_mlsses' ],
                3 => [ 'outdated_msa_mlsses' ],
                4 => [ 'outdated_cactus_hal_mlsses' ],
            },
        },

        {   -logic_name => 'outdated_pwa_mlsses',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

        {   -logic_name => 'outdated_msa_mlsses',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

        {   -logic_name => 'outdated_cactus_hal_mlsses',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },
    ];
}

1;
