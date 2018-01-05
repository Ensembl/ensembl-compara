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

# patch_74_75_b.sql
#
# Title: New columns in genome_db: has_karyotype and is_high_coverage
#
# Description:
#   Introduce two new columns in genome_db: has_karyotype and is_high_coverage
#   "has_karyotype" is a boolean that is true if there is at least 1 slice
#    in the karyotype
#   "is_high_coverage" is a boolean that is true if the assembly has a high,
#    which is a proxy for the quality of the gene annotation
#   Both are normally automatically populated from the core database

ALTER TABLE genome_db
	ADD COLUMN has_karyotype TINYINT(1) NOT NULL DEFAULT 0 AFTER genebuild,
	ADD COLUMN is_high_coverage TINYINT(1) NOT NULL DEFAULT 0 AFTER has_karyotype;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_74_75_b.sql|genome_db_haskaryo_highcov');
