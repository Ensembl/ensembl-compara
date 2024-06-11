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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs

=head1 DESCRIPTION

This pipeline-part analyzes the orthologies and flags the best ones as
"high-confidence", following a number of thresholds.

=head1 USAGE

=head2 eHive configuration

This pipeline fires 1 job per orthology MLSS, which are relatively fast
too, so you will have to set 'high_confidence_capacity'.

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
of identity of the pair of orthologues. If there is no GOC/WGA scores for a
given mlss_id or if no filter is set, the pipeline will fallback to using
the is_tree_compliant flag together with the percentage of identity.

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
                'taxa'          => [ 'all' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
        ],

=item range_filter, range_label

If the pipeline needs to process only a subset of the homologies,
these can be defined with an additional filter: a list of ranges.
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
                'homology_file' => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
            },
            -hive_capacity => $self->o('high_confidence_capacity'),
            -flow_into     => {
                1 => { 'import_homology_table' => { 'mlss_id' => '#mlss_id#', 'high_conf_expected' => '1' } },
            },
        },

        {   -logic_name => 'import_homology_table',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::MySQLImportHomologies',
            -parameters => {
                attrib_files => {
                    'goc'       => '#goc_file#',
                    'wga'       => '#wga_file#',
                    'high_conf' => '#high_conf_file#',
                },
                homology_flatfile => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                replace      => 0,
            },
            -hive_capacity   => $self->o('import_homologies_capacity'),
            -rc_name        => '1Gb_24_hour_job',
            -max_retry_count => 0,
            -flow_into       => {
                -1 => [ 'import_homology_table_himem' ],
            }
        },

        {   -logic_name => 'import_homology_table_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::MySQLImportHomologies',
            -parameters => {
                attrib_files => {
                    'goc'       => '#goc_file#',
                    'wga'       => '#wga_file#',
                    'high_conf' => '#high_conf_file#',
                },
                homology_flatfile => '#homology_dumps_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.homologies.tsv',
                replace      => 0,
            },
            -rc_name         => '16Gb_24_hour_job',
            -hive_capacity   => $self->o('import_homologies_capacity'),
            -max_retry_count => 0,
        },

    ];
}

1;
