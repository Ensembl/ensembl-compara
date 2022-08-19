-- See the NOTICE file distributed with this work for additional information
-- regarding copyright ownership.
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

# patch_108_109_c.sql
#
# Title: Add genome_db_id to member stable_id unique keys.
#
# Description:
#   To handle duplicate stable_ids between genomes, add genome_db_id
#   to the gene_member and seq_member stable_id unique keys.

ALTER TABLE gene_member
  DROP KEY stable_id,
  ADD UNIQUE KEY genome_db_stable_id (genome_db_id,stable_id);
ALTER TABLE seq_member
  DROP KEY stable_id,
  ADD UNIQUE KEY genome_db_stable_id (genome_db_id,stable_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_108_109_c.sql|stable_id_unique_per_genome');
