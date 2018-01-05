=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::HighConfidenceOrthologs_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::HighConfidenceOrthologs_conf -gene_tree_db mysql://...

=head1 DESCRIPTION  

    A simple pipeline to populate all the gene-tree related JSONs

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::HighConfidenceOrthologs_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');   # we don't need Compara tables in this particular case


sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

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
                'taxa'          => [ 'Aculeata', 'Anophelinae', 'Caenorhabditis', 'Drosophila', 'Glossinidae', 'Onchocercidae' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
            {
                'taxa'          => [ 'Brachycera', 'Culicinae', 'Hemiptera', 'Phlebotominae' ],
                'thresholds'    => [ 25, 25, 25 ],
            },
            {
                'taxa'          => [ 'Chelicerata', 'Diptera', 'Hymenoptera', 'Nematoda' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
        ],

        # ------- GRCh37
        #'range_label',  => "protein",       # A name for the range
        #'range_filter', => "homology_id < 100000000",       # An SQL boolean expression to filter homology_id

        #'range_label',  => "ncrna",       # A name for the range
        #'range_filter', => "homology_id > 100000000",       # An SQL boolean expression to filter homology_id
        # ------- GRCh37


        'high_confidence_capacity'    => 20,             # how many mlss_ids can be processed in parallel
        'high_confidence_batch_size'  => 10,            # how many mlss_ids' jobs can be batched together

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
            'range_filter'      => '((homology_id < 100000000) OR (homology_id BETWEEN 400000000 AND 500000000))',
        },
        {
            'compara_db'        => $self->o('compara_db'),
            'threshold_levels'  => $self->o('threshold_levels'),
            'range_label'       => 'ncrna',
            'range_filter'      => '((homology_id BETWEEN 100000000 AND 200000000) OR (homology_id BETWEEN 300000000 AND 400000000))',
        },
    ];

    return $pipeline_analyses;
}

1;

