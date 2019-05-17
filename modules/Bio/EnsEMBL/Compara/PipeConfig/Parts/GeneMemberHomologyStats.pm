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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats

=head1 DESCRIPTION

This pipeline-part populates the gene_member_hom_stats table.
This table can now hold statistics for different collections and once
instance of the pipeline can be seeded multiple times in order to gather
statistics for multiple collections.

=head1 USAGE

=head2 eHive configuration

This pipeline assumes the param_stack is turned on. Since we only have
a handful of resources (trees, families, collections) per database,
concurrency is not an issue and maximum capacities are not set by default.

=head2 Seeding

Each seed job has two arguments: "collection" is the name of the
collection species-set, and "clusterset_id" is the name of the
clusterset_id under which the trees / homologies are stored

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats;

use strict;
use warnings;


sub pipeline_analyses_fam_stats {
    my ($self) = @_;
    return [

        {   -logic_name => 'stats_families',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    # Clean up partial runs
                    'DROP TABLE IF EXISTS temp_member_family_counts',
                    # Temporary table with the counts
                    'CREATE TEMPORARY TABLE temp_member_family_counts AS
                     SELECT gene_member_id, COUNT(DISTINCT family_id) AS families
                     FROM family_member JOIN seq_member USING (seq_member_id)
                     GROUP BY gene_member_id',
                    # Add an index on gene_member_id
                    'ALTER TABLE temp_member_family_counts ADD INDEX (gene_member_id)',
                    # Make sure all the members are in the table
                    'INSERT IGNORE INTO gene_member_hom_stats (gene_member_id, collection)
                     SELECT gene_member_id, "default"
                     FROM temp_member_family_counts',
                    # Reset the counts (for reruns)
                    'UPDATE gene_member_hom_stats
                     SET families = 0',
                    # And set them to its right values
                    'UPDATE gene_member_hom_stats gm JOIN temp_member_family_counts t USING (gene_member_id)
                     SET gm.families = t.families
                     WHERE collection = "default"',
                    # Clean up the temporary table
                    'DROP TABLE temp_member_family_counts',
                ],
            },
        },

    ];
}


sub pipeline_analyses_hom_stats {
    my ($self) = @_;
    return [

        # Reset and populate the gene_member_hom_stats table
        {   -logic_name => 'set_default_values',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'clusterset_id' => $self->o('collection'),
                'sql'   => [
                    'DELETE FROM gene_member_hom_stats',
                    'INSERT INTO gene_member_hom_stats (gene_member_id, collection)
                     SELECT gene_member_id, "#clusterset_id#"
                     FROM gene_member',
                ],
            },
            -flow_into  => [ 'stats_gene_trees', 'gene_member_id_range_factory' ],
        },

        # Gene-tree statistics
        {   -logic_name => 'stats_gene_trees',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    # Clean up partial runs
                    'DROP TABLE IF EXISTS temp_member_tree_counts',
                    # Temporary table with the counts
                    'CREATE TEMPORARY TABLE temp_member_tree_counts AS
                     SELECT gene_member_id, gene_tree_root.root_id
                     FROM seq_member JOIN gene_tree_node USING (seq_member_id) JOIN gene_tree_root USING(root_id)
                     WHERE tree_type = "tree" AND ref_root_id IS NULL',
                    # Add an index on gene_member_id
                    'ALTER TABLE temp_member_tree_counts ADD INDEX (gene_member_id)',
                    # Reset the counts (for reruns)
                    'UPDATE gene_member_hom_stats
                     SET gene_trees = 0, gene_gain_loss_trees = 0',
                    # And set them to its right values
                    'UPDATE gene_member_hom_stats JOIN temp_member_tree_counts USING (gene_member_id)
                     SET gene_trees = 1',
                    'UPDATE gene_member_hom_stats JOIN temp_member_tree_counts t USING (gene_member_id) JOIN CAFE_gene_family c ON(t.root_id = c.gene_tree_root_id)
                     SET gene_gain_loss_trees = 1',
                    # Clean up the temporary table
                    'DROP TABLE temp_member_tree_counts',
                ],
            },
        },

        # gene_member_id_chunks
        {   -logic_name => 'gene_member_id_range_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MemberIDRangeFactory',
            -parameters => {
                'table'         => 'gene_member',
                'chunk_size'    => 100_000,
            },
            -flow_into  => {
                2 => 'stats_homologies',
            },
        },

        # Homology statistics
        {   -logic_name => 'stats_homologies',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    # Clean up partial runs
                    'DROP TABLE IF EXISTS temp_member_hom_counts',
                    # Temporary table with the counts
                    'CREATE TEMPORARY TABLE temp_member_hom_counts AS
                     SELECT gene_member_id, SUM(method_link_id=201) AS orthologues, SUM(method_link_id=202) AS paralogues, SUM(method_link_id=206) AS homoeologues
                     FROM homology_member
                     STRAIGHT_JOIN homology ON homology_member.homology_id = homology.homology_id
                     STRAIGHT_JOIN method_link_species_set ON method_link_species_set.method_link_species_set_id = homology.method_link_species_set_id
                     WHERE gene_member_id BETWEEN #min_gene_member_id# AND #max_gene_member_id#
                     GROUP BY gene_member_id',
                    # Add an index on gene_member_id
                    'ALTER TABLE temp_member_hom_counts ADD INDEX (gene_member_id)',
                    # Reset the counts (for reruns)
                    'UPDATE gene_member_hom_stats
                     SET orthologues = 0, paralogues = 0, homoeologues = 0
                     WHERE gene_member_id BETWEEN #min_gene_member_id# AND #max_gene_member_id#',
                    # And set them to its right values
                    'UPDATE gene_member_hom_stats g JOIN temp_member_hom_counts t USING (gene_member_id)
                     SET g.orthologues=t.orthologues, g.paralogues=t.paralogues, g.homoeologues=t.homoeologues',
                    # Clean up the temporary table
                    'DROP TABLE temp_member_hom_counts',
                ],
            },
        },

    ];
}

1;
