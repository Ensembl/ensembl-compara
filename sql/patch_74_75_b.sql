-- Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

# patch_74_75_b.sql
#
# Title: New column in genome_db: has_karyotype
#
# Description:
#   Introduce a new column in genome_db: has_karyotype
#   It is a boolean that is populated after reading from the code database
#   whether there is at least 1 slice in the karyotype

ALTER TABLE genome_db ADD COLUMN has_karyotype TINYINT(1) NOT NULL DEFAULT 0 AFTER genebuild;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_74_75_b.sql|genome_db_has_karyo');
