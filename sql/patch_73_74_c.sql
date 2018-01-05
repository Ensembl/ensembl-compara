-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# patch_73_74_c.sql
#
# Title: Changes in the SpeciesTree tables
#
# Description:
#    Compara now has a new SpeciesTree object/adaptor that is now independent of
#    the CAFE analysis.

#    species_tree_root: + Now has a new column, label, to differentiate between different species trees created on the same mlss_id.
#                       + The pvalue_lim column has been dropped (It is only in the code)
#
#    species_tree_node: + Now has the new columns taxon_id, genome_db_id and node_name. This last one is needed to name differently nodes that have the same taxon_id (for example when binarizing the tree in the CAFE analysis).
#                        
#    CAFE_species_gene: + The taxon_id column has been dropped

# species_tree_root
ALTER TABLE species_tree_root
      ADD COLUMN `label` varchar(256) NOT NULL DEFAULT 'default' AFTER method_link_species_set_id,
      DROP COLUMN `pvalue_lim`,
      ADD UNIQUE KEY (method_link_species_set_id, label);

ALTER TABLE species_tree_node 
      ADD COLUMN `taxon_id` int(10) unsigned DEFAULT NULL,
      ADD COLUMN `genome_db_id` int(10) unsigned DEFAULT NULL,
      ADD COLUMN `node_name` varchar(255) DEFAULT NULL,
      ADD FOREIGN KEY (`taxon_id`) REFERENCES ncbi_taxa_node(taxon_id),
      ADD FOREIGN KEY (`genome_db_id`) REFERENCES genome_db(genome_db_id);

UPDATE species_tree_node JOIN CAFE_species_gene USING(node_id) SET species_tree_node.taxon_id = CAFE_species_gene.taxon_id;
ALTER TABLE CAFE_species_gene DROP COLUMN taxon_id;
UPDATE species_tree_node JOIN genome_db using(taxon_id) SET species_tree_node.genome_db_id=genome_db.genome_db_id;

INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_c.sql|species_tree');

