-- Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

# patch_84_85_b.sql
#
# Title: Add extra attributes to the attribute table.
#
# Description:
#   New attributes to be included in this release.


-- the genome_db table
ALTER TABLE gene_tree_root_attr 
    ADD COLUMN lca int(10) unsigned NOT NULL,
    ADD COLUMN taxonomic_coverage FLOAT(5) NOT NULL, 
    ADD COLUMN ratio_species_genes FLOAT(5) NOT NULL;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_b.sql|add_attributes');

