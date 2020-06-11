-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

# patch_101_102_c.sql
#
# Title: Make species_tree_node.node_id a BIGINT
#
# Description:
#   species_tree_node.node_id and all references to it are now BIGINTs

ALTER table species_tree_node MODIFY COLUMN node_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT;
ALTER table species_tree_node MODIFY COLUMN parent_id BIGINT UNSIGNED;
ALTER table species_tree_node MODIFY COLUMN root_id BIGINT UNSIGNED;

ALTER table species_tree_root MODIFY COLUMN root_id BIGINT UNSIGNED;
ALTER table species_tree_node_tag MODIFY COLUMN node_id BIGINT UNSIGNED NOT NULL;
ALTER table species_tree_node_attr MODIFY COLUMN node_id BIGINT UNSIGNED NOT NULL;

ALTER table gene_tree_root_attr MODIFY COLUMN lca_node_id BIGINT UNSIGNED;
ALTER table gene_tree_node_attr MODIFY COLUMN species_tree_node_id BIGINT UNSIGNED;
ALTER table homology MODIFY COLUMN species_tree_node_id BIGINT UNSIGNED;

ALTER table CAFE_gene_family MODIFY COLUMN lca_id BIGINT UNSIGNED NOT NULL;
ALTER table CAFE_species_gene MODIFY COLUMN node_id BIGINT UNSIGNED NOT NULL;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_101_102_c.sql|stn_node_id_bigint');
