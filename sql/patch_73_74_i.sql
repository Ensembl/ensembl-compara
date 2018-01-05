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

# patch_73_74_i,sql
#
# Title: Links gene_tree_node_attr to species_tree_node
#
# Description:
#   Adds a new column (species_tree_node_id) in gene_tree_node_attr
#   It can be a foreign key to species_tree_node.node_id
#   taxon_id and taxon_name can be removed

SET session sql_mode='TRADITIONAL';

ALTER TABLE gene_tree_node_attr ADD species_tree_node_id INT(10) UNSIGNED;

# This assumes that the species_tree_node table has been populated by a previous patch
UPDATE gene_tree_node_attr SET species_tree_node_id = 500000000+taxon_id;

ALTER TABLE gene_tree_node_attr DROP COLUMN taxon_id, DROP COLUMN taxon_name;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_i.sql|gene_tree_node_attr.taxon_id');
