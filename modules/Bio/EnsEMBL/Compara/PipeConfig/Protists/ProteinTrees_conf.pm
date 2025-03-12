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

Bio::EnsEMBL::Compara::PipeConfig::Protists::ProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Protists::ProteinTrees_conf \
    -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The Protists PipeConfig file for ProteinTrees pipeline automating execution of homology-specific analyses.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Protists::ProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils ('stringify');

use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'   => 'protists',

        # homology_dnds parameters:
        'taxlevels' => ['Alveolata', 'Amoebozoa', 'Choanoflagellida', 'Cryptophyta', 'Fornicata', 'Haptophyceae', 'Kinetoplastida', 'Rhizaria', 'Rhodophyta', 'Stramenopiles'],

        # GOC parameters:
        'goc_taxlevels' => [],

        # HighConfidenceOrthologs parameters:
        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
        'threshold_levels' => [
            {
                'taxa'          => [ 'Alveolata', 'Amoebozoa', 'Apusozoa', 'Choanoflagellida', 'Cryptophyta', 'Euglenozoa', 'Fornicata', 'Heterolobosea', 'Ichthyosporea', 'Nucleariidae', 'Fonticula', 'Parabasalia', 'Rhizaria', 'Stramenopiles' ],
                'thresholds'    => [ 25, 25, 25 ],
            },
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, 25, 25 ],
            },
        ],

        'mapped_gene_ratio_per_taxon' => {
            '72018'   => 0.5,    #sphaeroforma
            '207245'  => 0.5,    #fornicata
            '2759'    => 0.5,    #eukaryotes
        },

        # Extra analyses:
        # Gain/loss analysis?
        'do_cafe'                => 0,
        # Compute dNdS for homologies?
        'do_dnds'                => 1,
        # Do we want the Gene QC part to run?
        'do_gene_qc'             => 0,
        # Do we need a mapping between homology_ids of this database to another database?
        'do_homology_id_mapping' => 0,
        # Do we expect to need shared homology dumps in a future release to facilitate reuse of WGA coverage data ?
        'homology_dumps_shared_dir' => undef,
        # Quick tree break is not suitable for protists dataset due to divergence causing inappropriate subtrees
        'use_quick_tree_break' => 0,

    };
}

sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    $analyses_by_name->{'HMMer_classify_factory'}->{'-parameters'}->{'step'} = 50;

    $analyses_by_name->{'make_treebest_species_tree'}->{'-parameters'}->{'allow_subtaxa'} = 1;
}

1;
