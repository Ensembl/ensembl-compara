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
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
        ],

        # Extra analyses:
        # Compute dNdS for homologies?
        'do_dnds'                => 1,
        # Gain/loss analysis?
        'do_cafe'                => 0,
        # Do we want the Gene QC part to run?
        'do_gene_qc'             => 0,
        # Do we need a mapping between homology_ids of this database to another database?
        # This parameter is automatically set to 1 when the GOC pipeline is going to run with a reuse database
        'do_homology_id_mapping' => 0,

    };
}

1;
