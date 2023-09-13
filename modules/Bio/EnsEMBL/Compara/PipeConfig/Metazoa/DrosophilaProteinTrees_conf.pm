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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::DrosophilaProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::DrosophilaProteinTrees_conf \
        -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The Drosophila PipeConfig file for ComplementaryProteinTrees pipeline.
This automates relevant pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::DrosophilaProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion ();

use base ('Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ComplementaryProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'collection'          => 'pangenome_drosophila',
        'dbID_range_index'    => 30,
        'ref_collection_list' => ['default', 'protostomes', 'insects'],
        'label_prefix'        => 'pangenome_drosophila_',

        # GOC parameters:
        'goc_taxlevels' => ['Diptera', 'Hemiptera'],

        # HighConfidenceOrthologs parameters:
        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
        'threshold_levels' => [
            {
                'taxa'          => ['Drosophila'],
                'thresholds'    => [50, 50, 25],
            },
            {
                'taxa'          => ['Brachycera'],
                'thresholds'    => [25, 25, 25],
            },
            {
                'taxa'          => ['all'],
                'thresholds'    => [undef, undef, 25],
            },
        ],
    };
}


1;
