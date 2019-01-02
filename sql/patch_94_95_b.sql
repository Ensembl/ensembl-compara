-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

# patch_94_95_b.sql
#
# Title: Removed indices that do not give any performance boost
#
# Description:
#   To save up some space, remove the indices that do make the queries any faster

ALTER TABLE constrained_element DROP KEY mlssid_dfId_idx;
ALTER TABLE constrained_element DROP KEY mlssid_idx;
ALTER TABLE genomic_align_tree DROP KEY root_id;
ALTER TABLE family_member DROP KEY family_id;
ALTER TABLE gene_tree_node DROP KEY root_id;
ALTER TABLE gene_tree_root_tag DROP KEY root_id;
ALTER TABLE homology_member DROP KEY homology_id;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_94_95_b.sql|remove_unused_indices');

