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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ProtostomesProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ProtostomesProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The Protostomes PipeConfig file for ComplementaryProteinTrees pipeline.
This automates relevant pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ProtostomesProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion ();

use base ('Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ComplementaryProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'collection'   => 'protostomes',
        'label_prefix' => 'protostomes_',

        #GOC parameters:
        'goc_taxlevels' => [ 'Cyclophyllidea', 'Entelegynae' , 'Ixodidae' ,'Mollusca' ,'Nematoda' ,'Neoptera', 'Schistosoma' ],

        'threshold_levels' => [
            {
		        'taxa'          => [ 'Caenorhabditis', 'Crassostrea', 'Cyclophyllidea', 'Ditrysia', 'Haliotis', 'Octopus', 'Rhipicephalinae', 'Schistosoma', 'Spirurina' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
            {
                'taxa'          => [ 'Entelegynae' , 'Ixodidae' ,'Mollusca' ,'Neoptera' ],
                'thresholds'    => [ 25, 25, 25 ],
            },
            {
                'taxa'          => [ 'Nematoda' ],
                'thresholds'    => [ undef, undef, 25 ],
            }, 
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
        ],
    };
}


1;
