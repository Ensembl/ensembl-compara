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

# patch_78_79_b.sql
#
# Title: Add the genome_component column in genome_db
#
# Description:
#   Add the genome_component column in genome_db
#   It is also added to the UNIQUE key

ALTER TABLE genome_db ADD COLUMN genome_component varchar(5) DEFAULT NULL AFTER is_high_coverage;
ALTER TABLE genome_db DROP KEY name, ADD UNIQUE name (name,assembly,genebuild,genome_component);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_78_79_b.sql|genome_component');
