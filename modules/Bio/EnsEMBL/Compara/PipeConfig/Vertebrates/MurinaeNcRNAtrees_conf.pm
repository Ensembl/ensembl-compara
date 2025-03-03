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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MurinaeNcRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MurinaeNcRNAtrees_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

This is the Murinae PipeConfig for the StrainsNcRNAtrees pipeline.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MurinaeNcRNAtrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsNcRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            'collection'        => 'murinae',       # The name of the species-set within that division
            'label_prefix'      => 'mur_',

            'projection_source_species_names' => ['mus_musculus'],
            'multifurcation_deletes_all_subnodes' => [ 10088 ], # All the species under the "Mus" genus are flattened, i.e. it's rat vs a rake of mice

    };
}

1;
