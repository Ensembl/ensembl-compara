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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::LoadSpeciesTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::LoadSpeciesTrees_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The Vertebrates configuration of the LoadSpeciesTrees pipeline. Please, refer
to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::LoadSpeciesTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.3;

use base ('Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesTrees_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'division'  => 'vertebrates',

        'compara_alias_name' => 'compara_curr',

        'taxon_filters' => [
            # Filters with the default behaviour (strains hidden)
            [ 'Amniota', 'Amniotes', '' ],
            [ 'Mammalia', 'Mammals', '' ],
            [ 'Neopterygii', 'Fish', '' ],
            [ 'Sauria', 'Sauropsids', '' ],
            # Filters with the strains shown, prefix with "str:"
            [ 'Murinae', 'Rat and all mice (incl. strains)', 'str:' ],
            [ 'Sus scrofa', 'All pig breeds', 'str:' ],
        ],
        'reference_genomes' => [
            # Which genome_dbs are used references for which clades
            [ '10090', 'mus_musculus' ],
            [ '9823',  'sus_scrofa' ],
        ],
    };
}


1;
