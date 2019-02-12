=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::PostHomologyMerge_conf

=head1 DESCRIPTION

Specific version of PostHomologyMerge for Ensembl (vertebrates)

=cut


package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::PostHomologyMerge_conf;

use strict;
use warnings;


use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS


use base ('Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'division'        => 'vertebrates',

        # ncRNAs don't have GOC, so we don't want to penalize them for that
        'high_confidence_ranges'    => [
            {
                'range_label'       => 'protein',
                'range_filter'      => '((homology_id < 1400000000) OR (homology_id BETWEEN 1800000000 AND 1900000000))',
            },
            {
                'range_label'       => 'ncrna',
                'range_filter'      => '((homology_id BETWEEN 1400000000 AND 1800000000) OR (homology_id BETWEEN 1900000000 AND 2000000000))',
            },
        ],

        # In this structure, the "thresholds" are for resp. the GOC score,
        # the WGA coverage and %identity
        'threshold_levels' => [
            {
                'taxa'          => [ 'Apes', 'Murinae' ],
                'thresholds'    => [ 75, 75, 80 ],
            },
            {
                'taxa'          => [ 'Mammalia', 'Aves', 'Percomorpha' ],
                'thresholds'    => [ 75, 75, 50 ],
            },
            {
                'taxa'          => [ 'Euteleostomi', 'Ciona' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
        ],

    };
}

1;


