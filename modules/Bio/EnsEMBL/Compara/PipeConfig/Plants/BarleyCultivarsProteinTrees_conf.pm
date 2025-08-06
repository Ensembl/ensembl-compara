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

Bio::EnsEMBL::Compara::PipeConfig::Plants::BarleyCultivarsProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Plants::BarleyCultivarsProteinTrees_conf \
    -host mysql-ens-compara-prod-X -port XXXX

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Plants::BarleyCultivarsProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Plants::CultivarsProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        # Parameters to allow merging different protein-tree collections
        'collection'       => 'barley_cultivars',
        'label_prefix'     => 'barley_cultivars_',

        # Flatten all the genomes under species 'Hordeum vulgare'
        'multifurcation_deletes_all_subnodes' => [4513],

        # Clustering parameters:
        'mapped_gene_ratio_per_taxon' => {
            '2759' => 0.5,  # eukaryotes
            '4513' => 0.9,  # hordeum vulgare
        },

        # GOC parameters
        'goc_taxlevels' => ['Hordeum'],
    };
}


sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    # Flow 'examl_32_cores' #-2 to 'fasttree'
    $analyses_by_name->{'examl_32_cores'}->{'-flow_into'}->{-2} = [ 'fasttree' ];
}


1;
