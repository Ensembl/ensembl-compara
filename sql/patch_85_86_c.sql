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

# patch_85_86_c.sql
#
# Title: Add a "species_tree_root_id" column to the gene_tree_root table
#
# Description:
#   The column will be used to link to the species-tree used to reconcile this
#   gene-tree. For a given gene-family, different gene-trees (different
#   clusterset_ids) can be linked to different species-trees


ALTER TABLE gene_tree_root ADD COLUMN species_tree_root_id INT(10) UNSIGNED AFTER method_link_species_set_id;

UPDATE gene_tree_root JOIN gene_tree_node USING (root_id) JOIN gene_tree_node_attr USING (node_id) JOIN species_tree_node ON species_tree_node_id = species_tree_node.node_id
SET species_tree_root_id = species_tree_node.root_id
WHERE species_tree_node_id IS NOT NULL;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_85_86_c.sql|gene_tree_root.species_tree_root_id');

