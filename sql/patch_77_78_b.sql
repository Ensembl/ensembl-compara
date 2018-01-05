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

# patch_77_78_b.sql
#
# Title: Allow NULL in the paf.*genome_db_id columns
#
# Description:
#   Allow NULL in the paf.*genome_db_id columns

ALTER TABLE peptide_align_feature
  MODIFY COLUMN qgenome_db_id int(10) unsigned,
  MODIFY COLUMN hgenome_db_id int(10) unsigned;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_77_78_b.sql|null_paf_genome_db_ids');
