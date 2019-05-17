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

Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::HighConfidenceOrthologs_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::HighConfidenceOrthologs_conf -compara_db mysql://...

=head1 DESCRIPTION

A simple pipeline to populate the high- and low- confidence levels on the Ensembl (vertebrates) database

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::HighConfidenceOrthologs_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::HighConfidenceOrthologs_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

        'division'   => 'vertebrates',

        # This pipeline will faster if it's run against the production ProteinTree database:
        # In this case it needs to be run *before* the merge, otherwise the data will not be in the release database.
        #'compara_db' => 'compara_ptrees',
        'compara_db' => 'compara_curr',

        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
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


sub pipeline_analyses {
    my ($self) = @_;
    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs::pipeline_analyses_high_confidence($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [
        {
            'compara_db'        => $self->o('compara_db'),
            'threshold_levels'  => $self->o('threshold_levels'),
            'range_label'       => 'protein',
            'range_filter'      => '((homology_id < 1400000000) OR (homology_id BETWEEN 1800000000 AND 1900000000))',
        },
        {
            'compara_db'        => $self->o('compara_db'),
            'threshold_levels'  => $self->o('threshold_levels'),
            'range_label'       => 'ncrna',
            'range_filter'      => '((homology_id BETWEEN 1400000000 AND 1800000000) OR (homology_id BETWEEN 1900000000 AND 2000000000))',
        },
    ];

    return $pipeline_analyses;
}

1;

