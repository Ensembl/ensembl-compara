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

# patch_104_105_d.sql
#
# Title: Allow duplicates in stable_id.
#
# Description:
#   stable_id can have duplicates, but make sure this does not happen in the same genome

ALTER TABLE gene_member DROP UNIQUE (stable_id);
ALTER TABLE gene_member ADD CONSTRAINT genome_stable_id UNIQUE (genome_db_id, stable_id);
ALTER TABLE gene_member ADD KEY (stable_id);

ALTER TABLE seq_member DROP UNIQUE (stable_id);
ALTER TABLE seq_member ADD CONSTRAINT genome_stable_id UNIQUE (genome_db_id, stable_id);
ALTER TABLE seq_member ADD KEY (stable_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_104_105_d.sql|add_genome_stable_id_key');
