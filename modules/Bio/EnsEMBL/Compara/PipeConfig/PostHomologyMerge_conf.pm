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

Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION

This pipeline combines a few steps that are run after having merged the
homology-side of things from each gene-tree pipeline into the release database:
    - Updates the 'families' column in gene_member_hom_stats table (if
      "'do_member_stats_fam' => 1")
    - Generate the MLSS tag 'perc_orth_above_wga_thresh' combining the WGA stats
      from both gene-tree pipelines

=cut


package Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf;

use strict;
use warnings;


use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS

use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'compara_db'      => 'compara_curr',
        
        'do_member_stats_fam' => 1,
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'db_conn'               => $self->o('compara_db'),

        'do_member_stats_fam'   => $self->o('do_member_stats_fam'),
    }
}


sub pipeline_analyses {
    my ($self) = @_;

    return [
        {   -logic_name => 'backbone_family_member_stats',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids  => [ {
                    'compara_db'    => $self->o('compara_db'),
                } ],
            -flow_into  => {
                '1->A' => [WHEN( '#do_member_stats_fam#' => 'stats_families')],
                'A->1' => ['summarise_wga_stats'],
            },
        },

        {   -logic_name => 'summarise_wga_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SummariseWGAStats',
            -flow_into  => ['backbone_end'],
        },

        {   -logic_name => 'backbone_end',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats::pipeline_analyses_fam_stats($self) },
    ];
}

1;
