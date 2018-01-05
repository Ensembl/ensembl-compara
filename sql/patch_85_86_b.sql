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

# patch_85_86_b.sql
#
# Title: Remove the "species_tree" column from the species_tree_root table
#
# Description:
#   The "species_tree" column was used to keep a stringified version of the
#   tree (in newick) which hides the fact that the true structure is kept in
#   the species_tree_node table. In fact very few pipelines needed to have
#   the string there, and they can certainly reconstruct it using the API.


ALTER TABLE species_tree_root DROP COLUMN species_tree;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_85_86_b.sql|species_tree_root.species_tree');

