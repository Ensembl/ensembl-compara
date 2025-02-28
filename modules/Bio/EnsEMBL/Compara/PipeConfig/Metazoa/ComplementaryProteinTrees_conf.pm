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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ComplementaryProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ComplementaryProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -collection <complementary_collection> -ref_collection 'default'

=head1 DESCRIPTION

The Metazoa Complementary Collection PipeConfig file for ProteinTrees pipeline.
This automates relevant pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ComplementaryProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion ();

use base ('Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

    # complementary collection parameters:

        # Collection(s) in master that may have overlapping data. Potentially overlapping clusters
        # and homologies are removed during the complementary protein-trees pipeline. This should be
        # defined in the PipeConfig file for each complementary collection (or on the command line).
        'ref_collection_list' => undef,

    # mapping parameters:

        'do_stable_id_mapping' => 0,
        'do_treefam_xref' => 0,
    };
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'ref_collection_list' => $self->o('ref_collection_list'),
    }
}


sub core_pipeline_analyses {
    my ($self) = @_;
    return [
        @{$self->SUPER::core_pipeline_analyses},

        # include complementary collection-specific analyses
        {
            -logic_name => 'find_overlapping_genomes',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::FindOverlappingGenomes',
            -parameters => {
                'collection' => $self->o('collection'),
            },
            -flow_into  => [ 'check_strains_cluster_factory' ],
        },

        {   -logic_name => 'check_strains_cluster_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery' => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id="default"',
            },
            -flow_into  => {
                '2->A' => [ 'cleanup_strains_clusters' ],
                'A->1' => [ 'cluster_cleanup_funnel_check' ],
            },
            -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'cleanup_strains_clusters',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RemoveOverlappingClusters',
            -analysis_capacity => 100,
        },

        {   -logic_name => 'cluster_cleanup_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => [ 'hc_clusters_again' ],
        },

        {   -logic_name         => 'hc_clusters_again',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -flow_into          => [ 'clusterset_backup' ],
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
        },
    ]
}


sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    # wire up complementary collection-specific analyses
    $analyses_by_name->{'cluster_qc_funnel_check'}->{'-flow_into'} = 'find_overlapping_genomes';
}


1;
