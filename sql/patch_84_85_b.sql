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

# patch_84_85_b.sql
#
# Title: Add extra attributes to the attribute table.
#
# Description:
#   New attributes to be included in this release.
#   And moving model_name and division from tag to attributes.

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

-- Alter the gene_tree_root_attr table
ALTER TABLE gene_tree_root_attr 
    ADD COLUMN lca_node_id          INT(10) UNSIGNED,
    ADD COLUMN taxonomic_coverage   FLOAT(5),
    ADD COLUMN ratio_species_genes  FLOAT(5),
    ADD COLUMN model_name           VARCHAR(40),
    ADD COLUMN division             VARCHAR(10);

-- Insert values from the gene_tree_root_tag table into gene_tree_root_attr table
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.model_name = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'model_name' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.division = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'division' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;

-- Delete old values
DELETE FROM gene_tree_root_tag WHERE tag IN ( 'model_name','division');

-- For the foreign key
ALTER TABLE gene_tree_root_attr ADD KEY (lca_node_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_b.sql|gene_tree_root_attr');
