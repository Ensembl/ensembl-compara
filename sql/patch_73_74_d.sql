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

# patch_73_74_d.sql
#
# Title: Drops the threshold_on_ds column in homology
#
# Description:
#   Drops the threshold_on_ds column in the homology
#   table. Stores the information in mlss_tag instead

SET session sql_mode='TRADITIONAL';

INSERT INTO method_link_species_set_tag
  SELECT method_link_species_set_id, 'threshold_on_ds', threshold_on_ds
  FROM homology
  WHERE threshold_on_ds IS NOT NULL
  GROUP BY method_link_species_set_id;

ALTER TABLE homology
  DROP COLUMN threshold_on_ds;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_d.sql|threshold_on_ds');
