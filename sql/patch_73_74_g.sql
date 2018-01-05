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

# patch_73_74_g.sql
#
# Title: Change the types in the homology_member table
#
# Description:
#   Reduces the size of the integers in the homology_member table

SET session sql_mode='TRADITIONAL';

ALTER TABLE homology_member 
	MODIFY COLUMN perc_cov tinyint unsigned default 0,
	MODIFY COLUMN perc_id  tinyint unsigned default 0,
	MODIFY COLUMN perc_pos tinyint unsigned default 0;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_g.sql|homology_perc_size');
