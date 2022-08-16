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
#   To allow for duplicate stable IDs between genomes, replace the
#   gene_member_stable_id column of gene_member_qc with gene_member_id.

SET session sql_mode='TRADITIONAL';

ALTER TABLE gene_member_qc
  DROP FOREIGN KEY gene_member_stable_id,
  DROP KEY gene_member_stable_id,
  DROP COLUMN gene_member_stable_id,
  ADD COLUMN gene_member_id INT unsigned NOT NULL FIRST,
  ADD KEY (gene_member_id),
  ADD FOREIGN KEY (gene_member_id) REFERENCES gene_member(gene_member_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_108_109_b.sql|gene_member_qc_key');
