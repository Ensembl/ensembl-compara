-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

# patch_97_98_b.sql
#
# Title: Make the division name a global property
#
# Description:
#    A Compara database only hosts data for 1 division (not to be confused
#    with collections), so this field should rather be set centrally in the
#    meta table than in the gene_tree_root_attr table

INSERT INTO meta (species_id, meta_key, meta_value) SELECT NULL, 'division', division FROM gene_tree_root_attr WHERE division IS NOT NULL LIMIT 1;
ALTER TABLE gene_tree_root_attr DROP COLUMN division;

INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_97_98_b.sql|division_name');

