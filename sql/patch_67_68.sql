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


-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

-- Unique keys promoted to primary keys
ALTER TABLE method_link_species_set_tag 
DROP KEY tag_mlss_id, 
ADD PRIMARY KEY tag_mlss_id (method_link_species_set_id,tag);

ALTER TABLE subset_member 
DROP KEY subset_member_id, 
ADD PRIMARY KEY subset_member_id (subset_id, member_id);

-- If the following ALTER TABLE fails, you have several entries for a given member_id
-- That should not happen, and hopefully, the sequences are identical:
--   SELECT member_id FROM sequence_exon_bounded GROUP BY member_id HAVING COUNT(*) > 1 AND COUNT(DISTINCT sequence_exon_bounded) > 1
-- If it is empty, you're fine and you can do:
--   DELETE seb FROM sequence_exon_bounded seb LEFT JOIN (SELECT sequence_exon_bounded_id FROM sequence_exon_bounded GROUP BY member_id) seb_d USING (sequence_exon_bounded_id) WHERE seb_d.sequence_exon_bounded IS NULL
-- Otherwise, that's pretty unexpected, please contact the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

ALTER TABLE sequence_exon_bounded 
DROP PRIMARY KEY, DROP KEY member_id, 
DROP COLUMN sequence_exon_bounded_id, 
ADD PRIMARY KEY (member_id);


-- sequence_cds is susceptible to raise the same issue as sequence_exon_bounded
-- The same procedure would then apply

ALTER TABLE sequence_cds
DROP PRIMARY KEY,
DROP KEY member_id,
DROP COLUMN sequence_cds_id,
ADD PRIMARY KEY (member_id);

ALTER TABLE family_member
DROP KEY family_member_id,
ADD PRIMARY KEY family_member_id (family_id,member_id);

ALTER TABLE gene_tree_member
DROP KEY node_id,
ADD PRIMARY KEY (node_id);

-- clusterset_id is now a string
-- NOTE, NULL values in this field are 'truncated' in this step, so we
-- set NULLs to 1 first, then update all values
UPDATE gene_tree_root SET clusterset_id = 1 WHERE clusterset_id IS NULL;
ALTER TABLE gene_tree_root
MODIFY COLUMN clusterset_id VARCHAR(20) NOT NULL DEFAULT 'default';
UPDATE gene_tree_root SET clusterset_id = "default";

-- New (generic) name
ALTER TABLE nc_profile
RENAME hmm_profile,
MODIFY COLUMN model_id VARCHAR(40) NOT NULL,
MODIFY COLUMN type VARCHAR(40) NOT NULL,
ADD COLUMN consensus MEDIUMTEXT;

-- New version
REPLACE INTO meta (species_id, meta_key, meta_value)
VALUES (NULL, 'schema_version', '68');
