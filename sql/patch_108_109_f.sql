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

# patch_108_109_f.sql
#
# Title: Restore stable_id key to gene_member and seq_member tables.
#
# Description:
#    Restore member stable_id key to prevent slowdown of MemberAdaptor methods
#    such as fetch_by_stable_id (deprecated) and fetch_all_by_stable_id_list.

ALTER TABLE gene_member ADD KEY stable_id (stable_id);
ALTER TABLE seq_member ADD KEY stable_id (stable_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_108_109_f.sql|stable_id_key_again');
