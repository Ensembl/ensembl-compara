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

# patch_75_76_c.sql
#
# Title: Add support for homoeologues
#
# Description:
#   To support homoeologues, we have to:
#     - extend the "description" field of homology
#     - add a new column in member_production_counts

ALTER TABLE homology MODIFY COLUMN description ENUM('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','gene_split','between_species_paralog','alt_allele','homoeolog_one2one','homoeolog_one2many','homoeolog_many2many');

ALTER TABLE member_production_counts ADD COLUMN `homoeologues` int(10) unsigned default 0;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_75_76_c.sql|homoeologues');
