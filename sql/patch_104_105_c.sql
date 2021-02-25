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

# patch_104_105_c.sql
#
# Title: Update schema version.
#
# Description:
#   Remove foreign keys for dnafrag to seq_member and gene_member

ALTER TABLE dnafrag  DROP FOREIGN KEY seq_member_ibfk_5;
ALTER TABLE dnafrag  DROP INDEX seq_member_ibfk_5;
ALTER TABLE dnafrag DROP FOREIGN KEY gene_member_ibfk_3;
ALTER TABLE dnafrag DROP INDEX gene_member_ibfk_3;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_104_105_c.sql|drop_dnafrag_fk');
