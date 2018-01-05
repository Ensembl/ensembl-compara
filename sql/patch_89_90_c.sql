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

# patch_89_90_c.sql
#
# Title: Mark constrained_element.p_value as NOT NULL
#
# Description:
#   A p-value can in fact always be present, although sometimes zero


UPDATE constrained_element SET p_value = 0 WHERE p_value IS NULL;
ALTER TABLE constrained_element MODIFY p_value DOUBLE NOT NULL DEFAULT 0;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_89_90_c.sql|constrained_element_pvalue_not_null');
