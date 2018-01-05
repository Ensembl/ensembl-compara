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

# patch_87_88_d.sql
#
# Title: New column in the dnafrag table to track which sub-genome the dnafrag is part of
#
# Description:
#   This new column allows to identify the nuclear, mitochondrion and chloroplast genomes

SET session sql_mode='TRADITIONAL';

ALTER TABLE dnafrag ADD COLUMN cellular_component ENUM('NUC', 'MT', 'PT') DEFAULT 'NUC' NOT NULL AFTER coord_system_name;
UPDATE dnafrag SET cellular_component = 'MT' WHERE name IN ("MT", "chrM");

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_87_88_d.sql|cellular_component');
