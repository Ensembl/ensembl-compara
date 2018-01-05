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

# patch_84_85_h.sql
#
# Title: Use floating-poitn values in homology_member
#
# Description:
#   These columns used to be tinyint, which meant we would lose
#   the digits after the decimal points

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';


ALTER TABLE homology_member
	MODIFY  perc_cov     float unsigned default 0,
	MODIFY  perc_pos     float unsigned default 0,
	MODIFY  perc_id      float unsigned default 0;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_h.sql|homology_member_float');
