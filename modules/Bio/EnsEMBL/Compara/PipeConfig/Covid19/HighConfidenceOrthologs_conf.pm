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

Bio::EnsEMBL::Compara::PipeConfig::Covid19::HighConfidenceOrthologs_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Covid19::HighConfidenceOrthologs_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

A simple pipeline to populate the high- and low- confidence levels on an Covid19 Compara database.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Covid19::HighConfidenceOrthologs_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::HighConfidenceOrthologs_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

        'division'    => 'covid19',
        'member_type' => 'protein',
        'compara_db'  => 'compara_ptrees',

        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
        'threshold_levels' => [
            {
                'taxa'          => [ 'Coronaviridae' ],
                'thresholds'    => [ undef, undef, 80 ],
            },
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
        ],
    };
}


1;
