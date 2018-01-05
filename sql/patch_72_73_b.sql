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

# patch_72_73_b.sql
#
# Title: Allows homologies not to be linked to gene-trees
#
# Description:
#   Change the ancestor_node_id and tree_node_id columns in the homology
#   table to allow NULL. This is needed for the gene projections between
#   the reference sequence and the patch regions.

ALTER TABLE homology MODIFY COLUMN ancestor_node_id int(10) unsigned;
ALTER TABLE homology MODIFY COLUMN tree_node_id     int(10) unsigned;
UPDATE homology SET ancestor_node_id = NULL WHERE ancestor_node_id = 0;
UPDATE homology SET tree_node_id     = NULL WHERE tree_node_id     = 0;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_72_73_b.sql|homology_genetree_links');
