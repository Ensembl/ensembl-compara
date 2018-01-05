-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
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


# Updating the schema version

UPDATE meta SET meta_value = 51 where meta_key = "schema_version";

# Remove sitewise_member table from release

DROP TABLE sitewise_member;

# Update meta table schema to match core meta table (this
# is required as we use the MetaContainer from the core API)
# The rest of the patch is taken from the core patch_50_51_d.sql
#
# Title: make database multi-species capable
#
# Description:
#   Add a species_id column to the meta and coord_system table and make
#   new indexes on these tables.

-- Add the new species_id column after meta_id
ALTER TABLE meta ADD COLUMN
 species_id INT UNSIGNED DEFAULT 1 -- Default species_id is 1
                                   -- NULL means "not species specific"
 AFTER meta_id;

-- Redo the indexes on the meta table
ALTER TABLE meta DROP INDEX key_value;
ALTER TABLE meta DROP INDEX meta_key_index;
ALTER TABLE meta DROP INDEX meta_value_index;

ALTER TABLE meta
 ADD UNIQUE INDEX species_key_value_idx (species_id, meta_key, meta_value);
ALTER TABLE meta
 ADD INDEX species_value_idx (species_id, meta_value);

-- Optimize the modified tables
OPTIMIZE TABLE meta;

-- Update species_id for schema_version entry:
UPDATE meta SET species_id = NULL where meta_key = "schema_version";
