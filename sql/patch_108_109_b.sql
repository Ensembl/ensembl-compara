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

# patch_108_109_b.sql
#
# Title: Change the gene_member_qc key to gene_member_id.
#
# Description:
#   To facilitate the transition to allowing duplicate stable IDs between genomes:
#     - replace the gene_member_stable_id column of gene_member_qc with gene_member_id;
#     - set each gene_member_id from its corresponding row in the gene_member table; and
#     - preserve the name of the foreign-key constraint referencing the gene_member table.

SET session sql_mode='TRADITIONAL';

ALTER TABLE gene_member_qc
  ADD COLUMN gene_member_id INT unsigned NOT NULL FIRST;

UPDATE gene_member_qc gmq JOIN gene_member gm ON gmq.gene_member_stable_id = gm.stable_id
  SET gmq.gene_member_id = gm.gene_member_id;

ALTER TABLE gene_member_qc
  DROP FOREIGN KEY gene_member_qc_ibfk_1,
  DROP KEY gene_member_stable_id,
  DROP COLUMN gene_member_stable_id;

ALTER TABLE gene_member_qc
  ADD KEY (gene_member_id),
  ADD CONSTRAINT gene_member_qc_ibfk_1 FOREIGN KEY (gene_member_id) REFERENCES gene_member (gene_member_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_108_109_b.sql|gene_member_qc_key');
