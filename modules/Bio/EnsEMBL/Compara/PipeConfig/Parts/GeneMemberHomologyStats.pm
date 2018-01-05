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


sub pipeline_analyses_hom_stats {
    my ($self) = @_;
    return [

        # Get the species_set_id of the collection (supposed to be unique)
        {   -logic_name => 'find_collection_species_set_id',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT species_set_id
                                    FROM species_set_header
                                    WHERE name = "collection-#collection#"',
            },
            -flow_into => {
                2 => [ 'set_default_values' ],
            },
        },

        # Reset the gene_member_hom_stats table (for reruns)
        # REPLACE will do DELETE+INSERT if the (gene_member_id, collection) row
        # is already present. Since we don't declare the other fields, they will
        # default to their default values, which are 0
        {   -logic_name => 'set_default_values',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'REPLACE INTO gene_member_hom_stats (gene_member_id, collection)
                     SELECT gene_member_id, "#clusterset_id#"
                     FROM gene_member JOIN species_set USING (genome_db_id)
                     WHERE species_set_id = #species_set_id#',
                ],
            },
            -flow_into  => [ 'find_mlss_families', 'find_mlss_gene_trees', 'stats_homologies' ],
        },

        # Fan out all the FAMILY mlss_ids
        {   -logic_name => 'find_mlss_families',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT method_link_species_set_id
                                    FROM method_link_species_set JOIN method_link USING (method_link_id)
                                    WHERE method_link.type = "FAMILY" AND species_set_id = #species_set_id#',
            },
            -flow_into => {
                2 => [ 'stats_families' ],
            },
        },

        # Stats for a family MLSS. The structure fan+independent stats assumes
        # that if there are several MLSSs they don't share any member
        {   -logic_name => 'stats_families',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'CREATE TEMPORARY TABLE temp_member_family_counts AS
                     SELECT gene_member_id, COUNT(DISTINCT family_id) AS families
                     FROM family JOIN family_member USING (family_id) JOIN seq_member USING (seq_member_id)
                     WHERE method_link_species_set_id = #method_link_species_set_id#
                     GROUP BY gene_member_id',
                    'UPDATE gene_member_hom_stats gm JOIN temp_member_family_counts t USING (gene_member_id)
                     SET gm.families = t.families
                     WHERE collection = "#clusterset_id#"',
                    'DROP TABLE temp_member_family_counts',
                ],
            },
        },

        # Fan out all the gene-tree mlss_ids (PROTEIN_TREES and NC_TREES)
        {   -logic_name => 'find_mlss_gene_trees',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT method_link_species_set_id
                                    FROM method_link_species_set JOIN method_link USING (method_link_id)
                                    WHERE method_link.type IN ("PROTEIN_TREES", "NC_TREES") AND species_set_id = #species_set_id#',
            },
            -flow_into => {
                2 => [ 'stats_gene_trees' ],
            },
        },

        # Stats for a gene-tree MLSS. The structure fan+independent stats
        # assumes that if there are several MLSSs they don't share any member
        {   -logic_name => 'stats_gene_trees',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'CREATE TEMPORARY TABLE temp_member_tree_counts AS
                     SELECT gene_member_id, gene_tree_root.root_id
                     FROM seq_member JOIN gene_tree_node USING (seq_member_id) JOIN gene_tree_root USING(root_id)
                     WHERE clusterset_id = "#clusterset_id#" AND tree_type = "tree" AND method_link_species_set_id = #method_link_species_set_id#',
                    'UPDATE gene_member_hom_stats JOIN temp_member_tree_counts USING (gene_member_id)
                     SET gene_trees = 1
                     WHERE collection = "#clusterset_id#"',
                    'UPDATE gene_member_hom_stats JOIN temp_member_tree_counts t USING (gene_member_id) JOIN CAFE_gene_family c ON(t.root_id = c.gene_tree_root_id)
                     SET gene_gain_loss_trees = 1
                     WHERE collection = "#clusterset_id#"',
                    'DROP TABLE temp_member_tree_counts',
                ],
            },
        },

        # Homology statistics
        {   -logic_name => 'stats_homologies',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'CREATE TEMPORARY TABLE good_hom_mlss AS
                     SELECT method_link_species_set_id, method_link_id
                     FROM method_link_species_set JOIN species_set ss USING (species_set_id) LEFT JOIN species_set ss_c ON ss.genome_db_id=ss_c.genome_db_id AND ss_c.species_set_id = #species_set_id#
                     GROUP BY method_link_species_set_id
                     HAVING COUNT(*) = COUNT(ss_c.species_set_id)',
                    'ALTER TABLE good_hom_mlss ADD PRIMARY KEY (method_link_species_set_id)',
                    'CREATE TEMPORARY TABLE temp_member_hom_counts AS
                     SELECT gene_member_id, SUM(method_link_id=201) AS orthologues, SUM(method_link_id=202) AS paralogues, SUM(method_link_id=206) AS homoeologues
                     FROM homology_member JOIN homology USING (homology_id) JOIN good_hom_mlss USING (method_link_species_set_id)
                     GROUP BY gene_member_id',
                    'UPDATE gene_member_hom_stats g JOIN temp_member_hom_counts t USING (gene_member_id)
                     SET g.orthologues=t.orthologues, g.paralogues=t.paralogues, g.homoeologues=t.homoeologues
                     WHERE collection = "#clusterset_id#"',
                    'DROP TABLE good_hom_mlss, temp_member_hom_counts',
                ],
            },
        },

    ];
}

1;

