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

# patch_81_82_c.sql
#
# Title: Add a "size" column to the species_set_header table
#
# Description:
#   The size column is an extra attribute that is stored in the database
#   but not read by the API (the size can be inferred by listing the
#   genome_dbs)


ALTER TABLE species_set_header ADD COLUMN size int(10) unsigned NOT NULL AFTER name;

CREATE TEMPORARY TABLE ssh_size AS SELECT species_set_id, COUNT(*) AS cnt FROM species_set GROUP BY species_set_id;
UPDATE ssh_size JOIN species_set_header USING (species_set_id) SET species_set_header.size = ssh_size.cnt;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_81_82_c.sql|species_set_size');

