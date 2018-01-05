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

Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs

=head1 DESCRIPTION

This pipeline-part analyzes the orthologies and flags the best ones as
"high-confidence", following a number of thresholds.

=head1 USAGE

=head2 eHive configuration

This pipeline fires 1 job per orthology MLSS, which are relatively fast
too, so you will have to set 'high_confidence_batch_size' and 'high_confidence_capacity'.

Jobs require less than 100MB of memory.

=head2 Seeding

Job really only require a database location.

=head2 Global parameters

These parameters are required by several analyses and should probably
be declared as pipeline-wide. They can otherwise be set at the first job.

=over

=item threshold_levels

"threshold_levels" is an array of selectors that are evaluated in order.
Each element is a hash that defines some taxon names and the filter to
apply on their homologies.

When a taxon is considered, all the MLSSs that join two species below it
will be selected. The filter consists of three thresholds: the minimum values
for respectively the GOC score, the WGA coverage and the minimum percentage
of identity of the pair of orthologues.

Example:

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
                'taxa'          => [ 'Euteleostomi' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
        ],

=item range_filter, range_label

If the pipeline needs to process only a subset of the homologies,
these can be defined with an additional filter: a SQL condition.
The statistics will then be stored in the database with the label
added to their names.

=back

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs;

use strict;
use warnings;


use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS


sub pipeline_analyses_high_confidence {
    my ($self) = @_;
    return [

        {   -logic_name => 'mlss_id_for_high_confidence_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::FindMLSSUnderTaxa',
            -flow_into  => {
                2   => { 'flag_high_confidence_orthologs' => INPUT_PLUS },
            },
        },

        {   -logic_name    => 'flag_high_confidence_orthologs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::FlagHighConfidenceOrthologs',
            -parameters    => {
                'thresholds'    => '#expr( #threshold_levels#->[#threshold_index#]->{"thresholds"} )expr#',
            },
            -hive_capacity => $self->o('high_confidence_capacity'),
            -batch_size    => $self->o('high_confidence_batch_size'),
        },

    ];
}

1;

