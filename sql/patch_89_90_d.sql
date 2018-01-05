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

# patch_89_90_d.sql
#
# Title: Allow NULL in genomic_align_tree.left_node_id/right_node_id
#
# Description:
#   NULL was not allowed, so 0 was ued, but NULL is more accurate


ALTER TABLE genomic_align_tree MODIFY COLUMN left_node_id bigint(10), MODIFY COLUMN right_node_id bigint(10);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_89_90_d.sql|genomic_align_tree_left_node_id_null');
