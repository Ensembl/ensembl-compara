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

# patch_87_88_i.sql
#
# Title: Add common-name information to the genome_db table.
#
# Description:
#   Add a common name that is supposed to be in sync with the "web name"

ALTER TABLE genome_db ADD COLUMN display_name VARCHAR(255) DEFAULT NULL AFTER strain_name;
UPDATE genome_db JOIN ncbi_taxa_name USING (taxon_id) SET display_name = ncbi_taxa_name.name WHERE name_class = "ensembl alias name";

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_87_88_i.sql|genome_db.display_name');

