-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

# patch_79_80_c.sql
#
# Title: Add "first_release" and "last_release" to the core tables
#
# Description:
#   genome_db, species_set, and method_link_species_set now have two
#   extra columns ("first_release" and "last_release") to track the
#   release versions when they were loaded / active.
#   As a result, genome_db.assembly_default has been removed

-- the genome_db table
ALTER TABLE genome_db ADD COLUMN first_release smallint unsigned, ADD COLUMN last_release smallint unsigned;

# If there are some non-default assemblies, they must come from a previous version
UPDATE genome_db SET last_release = 79 WHERE assembly_default=0;

ALTER TABLE genome_db DROP COLUMN assembly_default;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_79_80_c.sql|first_last_release');
