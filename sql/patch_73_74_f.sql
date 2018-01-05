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

# patch_73_74_f.sql
#
# Title: Rename the tree columns of the homology table
#
# Description:
#   Performs the following renames in the homology table:
#    - ancestor_node_id -> gene_tree_node_id
#    - tree_node_id -> gene_tree_root_id
#    - subtype -> species_tree_node_id

SET session sql_mode='TRADITIONAL';

ALTER TABLE homology
  DROP KEY `ancestor_node_id`,
  DROP KEY `tree_node_id`,
  CHANGE COLUMN ancestor_node_id gene_tree_node_id INT(10) UNSIGNED,
  CHANGE COLUMN tree_node_id     gene_tree_root_id INT(10) UNSIGNED,
  ADD COLUMN species_tree_node_id INT(10) UNSIGNED AFTER lnl;

INSERT INTO species_tree_node SELECT 500000000+taxon_id, 500000000+parent_id, 500000000+root_id, left_index, right_index, NULL, taxon_id, NULL, name FROM ncbi_taxa_node JOIN ncbi_taxa_name USING (taxon_id) WHERE name_class = "scientific name";
UPDATE species_tree_node stn JOIN genome_db gdb USING (taxon_id) SET stn.genome_db_id = gdb.genome_db_id;

## ALTER TABLE homology ADD species_tree_node_id INT UNSIGNED DEFAULT NULL AFTER lnl;
UPDATE homology JOIN gene_tree_node_attr ON node_id = gene_tree_node_id SET species_tree_node_id = 500000000+taxon_id;
ALTER TABLE homology DROP COLUMN subtype;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_f.sql|homology_node_ids');
