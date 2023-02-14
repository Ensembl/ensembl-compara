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

# patch_108_109_d.sql
#
# Title: Revert stable_id collation to be case insensitive.
#
# Description:
#   With the schema updated so that stable_ids are required to be unique per genome,
#   the workaround of using binary collation for stable_ids is not longer needed.
#   Reverting this binary fix reverts stable_id collation to be case insensitive.

ALTER TABLE gene_member MODIFY stable_id VARCHAR(128) NOT NULL;
ALTER TABLE seq_member MODIFY stable_id VARCHAR(128) NOT NULL;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_108_109_d.sql|case_insensitive_stable_id');
