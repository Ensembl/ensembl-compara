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

# patch_104_105_b.sql
#
# Title: Widen genebuild field in genome_db.
#
# Description:
#   Widen genebuild field in genome_db to match an update done in core databases.

ALTER TABLE genome_db MODIFY COLUMN genebuild varchar(255) DEFAULT '' NOT NULL;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_104_105_b.sql|genebuild_varchar255');
