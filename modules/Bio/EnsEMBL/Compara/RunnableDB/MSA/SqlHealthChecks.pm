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

Bio::EnsEMBL::Compara::RunnableDB::MSA::SqlHealthChecks

=head1 DESCRIPTION

This runnable offers one or more groups of healthchecks to
verify the integrity of MSA-related data in a database.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MSA::SqlHealthChecks;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck');


our $config = {

    ### Species Tree
    #################

    species_tree => {
        params => [ 'species_tree_root_id', 'mlss_id', 'binary', 'n_missing_species_in_tree' ],
        tests => [
            {
                description => 'genome_db_id can only be populated on leaves',
                query => 'SELECT stn.*, COUNT(*) AS n_children FROM species_tree_node stn JOIN species_tree_node stnc ON stnc.parent_id = stn.node_id WHERE stn.root_id = #species_tree_root_id# AND stn.genome_db_id IS NOT NULL GROUP BY stn.node_id'
            },
            {
                description => 'All the leaves of the species tree should have a genome_db',
                query => 'SELECT stn.* FROM species_tree_node stn LEFT JOIN species_tree_node stnc ON stnc.parent_id = stn.node_id WHERE stn.root_id = #species_tree_root_id# AND stnc.node_id IS NULL AND stn.genome_db_id IS NULL'
            },
            {
                description => 'All current genome_dbs in the MLSS should be represented in the species tree',
                query => q/
                    SELECT
                        mlss_gdb.name
                    FROM
                        genome_db mlss_gdb
                    JOIN
                        species_set
                    USING
                        (genome_db_id)
                    JOIN
                        method_link_species_set
                    USING
                        (species_set_id)
                    WHERE
                        method_link_species_set_id = #mlss_id#
                    AND
                        mlss_gdb.name != "ancestral_sequences"
                    AND
                        mlss_gdb.name NOT IN (
                            SELECT DISTINCT
                                node_gdb.name
                            FROM
                                species_tree_node stn
                            JOIN
                                genome_db node_gdb
                            ON
                                node_gdb.genome_db_id = stn.genome_db_id
                            WHERE
                                stn.root_id = #species_tree_root_id#
                        )
                /,
                expected_size => '= #n_missing_species_in_tree#',
            },
            {
                description => 'Checks that the species tree is minimized (i.e. nodes cannot have a single child)',
                query => 'SELECT stn1.node_id FROM species_tree_node stn1 JOIN species_tree_node stn2 ON stn1.node_id = stn2.parent_id WHERE stn1.root_id = #species_tree_root_id# GROUP BY stn1.node_id HAVING COUNT(*) = 1',
            },
            {
                description => 'Checks that the species tree is binary',
                query => 'SELECT stn1.node_id FROM species_tree_node stn1 JOIN species_tree_node stn2 ON stn1.node_id = stn2.parent_id WHERE stn1.root_id = #species_tree_root_id# GROUP BY stn1.node_id HAVING COUNT(*) > 2 AND #binary#',
            },
        ],
    },
};


sub fetch_input {
    my $self = shift;

    my $mode = $self->param_required('mode');
    die unless exists $config->{$mode};
    my $this_config = $config->{$mode};

    foreach my $param_name (@{$this_config->{params}}) {
        $self->param_required($param_name);
    }
    $self->param('tests', $this_config->{tests});
    $self->_validate_tests;
}


1;
