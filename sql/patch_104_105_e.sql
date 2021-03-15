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

# patch_104_105_e.sql
#
# Title: Add ON UPDATE CASCADE between member ids.
#
# Description:
#   Add ON UPDATE CASCADE option between seq_member and gene_member main IDs

ALTER TABLE gene_member ADD FOREIGN KEY (canonical_member_id) REFERENCES seq_member(seq_member_id) ON UPDATE CASCADE;

ALTER TABLE seq_member DROP FOREIGN KEY seq_member_ibfk_4;
ALTER TABLE seq_member ADD FOREIGN KEY (gene_member_id) REFERENCES gene_member(gene_member_id) ON UPDATE CASCADE;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_104_105_e.sql|member_id_fk_cascade');
