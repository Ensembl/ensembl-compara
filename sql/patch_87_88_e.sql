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

# patch_87_88_e.sql
#
# Title: New column in the gene_member table to record the biotype (group) of each gene
#
# Description:
#   This new column allows to distinguish between coding and non-coding genes without
#   having to look at the seq_member table

SET session sql_mode='TRADITIONAL';

ALTER TABLE gene_member ADD COLUMN biotype_group ENUM('coding', 'snoncoding', 'lnoncoding', 'mnoncoding', 'LRG') NOT NULL DEFAULT 'coding' AFTER genome_db_id;
UPDATE gene_member JOIN seq_member USING (gene_member_id) SET biotype_group = "snoncoding" WHERE seq_member.source_name LIKE "%TRANS";

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_87_88_e.sql|biotype_group');
