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

Bio::EnsEMBL::Compara::PipeConfig::Fungi::ProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Fungi::ProteinTrees_conf \
    -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The Fungi PipeConfig file for ProteinTrees pipeline automating execution of homology-specific analyses.

Selected funnel analyses are blocked on pipeline initialisation.
These should be unblocked as needed during pipeline execution.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Fungi::ProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},  # inherit the generic ones

        'division' => 'fungi',

        # homology_dnds parameters:
        'taxlevels' => [],

        # GOC parameters:
        'goc_taxlevels' => [],

        # HighConfidenceOrthologs parameters:
        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
        'threshold_levels' => [
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, 25, 25 ],
            },
        ],

        'mapped_gene_ratio_per_taxon' => {
            '2759'    => 0.5,    # eukaryotes
            '6029'    => 0.4,    # microsporidia
        },

        # Extra analyses:
        # Gain/loss analysis?
        'do_cafe'                => 0,
        # Compute dNdS for homologies?
        'do_dnds'                => 0,
        # Do we want the Gene QC part to run?
        'do_gene_qc'             => 0,
        # Do we need a mapping between homology_ids of this database to another database?
        'do_homology_id_mapping' => 0,
        # Do we expect to need shared homology dumps in a future release to facilitate reuse of WGA coverage data ?
        'homology_dumps_shared_dir' => undef,
    };
}

sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    $analyses_by_name->{'unannotated_all_vs_all_factory'}->{'-parameters'}->{'num_sequences_per_blast_job'} = 5000;
    $analyses_by_name->{'members_against_allspecies_factory'}->{'-parameters'}->{'num_sequences_per_blast_job'} = 5000;
    $analyses_by_name->{'members_against_allspecies_factory'}->{'-parameters'}->{'num_sequences_per_blast_job'} = 5000;

    $analyses_by_name->{'make_treebest_species_tree'}->{'-parameters'}->{'allow_subtaxa'} = 1;

    # Block unguarded funnel analyses; to be unblocked as needed during pipeline execution.
    my @unguarded_funnel_analyses = (
        'create_mlss_ss',
        'datacheck_funnel',
        'exon_boundaries_prep',
        'hc_cafe_results',
        'hc_post_tree',
        'hcluster_dump_input_all_pafs',
        'ortholog_mlss_factory',
        'panther_paralogs',
        'store_tags',
    );
    foreach my $logic_name (@unguarded_funnel_analyses) {
        $analyses_by_name->{$logic_name}->{'-analysis_capacity'} = 0;
    }
}

1;
