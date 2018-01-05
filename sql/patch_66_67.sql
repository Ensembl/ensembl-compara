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


-- master database
-- -----------------

ALTER TABLE method_link DROP KEY `type`;
ALTER TABLE method_link ADD UNIQUE KEY `type` (`type`);

ALTER TABLE species_set ADD UNIQUE KEY `species_set_id` (`species_set_id`,`genome_db_id`), DROP PRIMARY KEY;
ALTER TABLE species_set MODIFY COLUMN genome_db_id int(10) unsigned DEFAULT NULL;

ALTER TABLE dnafrag MODIFY COLUMN genome_db_id int(10) unsigned NOT NULL;

-- should have been included in e66
ALTER TABLE mapping_session DROP KEY `type`;
ALTER TABLE mapping_session ADD UNIQUE KEY `type` (`type`,`rel_from`,`rel_to`,`prefix`);

-- Updating the schema version
UPDATE meta SET meta_value = 67 where meta_key = "schema_version";


-- Gene trees
-- ------------

-- splitting tree_type into member_type + tree_type;
ALTER TABLE gene_tree_root CHANGE COLUMN tree_type old_tree_type ENUM('proteinclusterset','proteinsupertree','proteintree','ncrnatree','ncrnaclusterset');
ALTER TABLE gene_tree_root ADD COLUMN member_type ENUM('protein', 'ncrna') NOT NULL AFTER root_id;
ALTER TABLE gene_tree_root ADD COLUMN tree_type ENUM('clusterset', 'supertree', 'tree') NOT NULL AFTER member_type;
UPDATE gene_tree_root SET member_type = 'protein' WHERE old_tree_type LIKE 'protein%';
UPDATE gene_tree_root SET member_type = 'ncrna' WHERE old_tree_type LIKE 'ncrna%';
UPDATE gene_tree_root SET tree_type = 'clusterset' WHERE old_tree_type LIKE '%clusterset';
-- super-trees will be temporarily called 'tree'
UPDATE gene_tree_root SET tree_type = 'tree' WHERE old_tree_type LIKE '%tree';
UPDATE gene_tree_root SET tree_type = 'supertree' WHERE old_tree_type LIKE '%supertree';
ALTER TABLE gene_tree_root DROP COLUMN old_tree_type;
ALTER TABLE gene_tree_root ADD KEY `tree_type` (`tree_type`);

ALTER TABLE gene_tree_root MODIFY COLUMN method_link_species_set_id int(10) unsigned NOT NULL;

-- Removed some unused fields
ALTER TABLE gene_tree_member DROP COLUMN cigar_start;
ALTER TABLE gene_tree_member DROP COLUMN cigar_end;
ALTER TABLE protein_tree_member_score DROP COLUMN cigar_start;
ALTER TABLE protein_tree_member_score DROP COLUMN cigar_end;

ALTER TABLE homology_member DROP COLUMN cigar_start;
ALTER TABLE homology_member DROP COLUMN cigar_end;
ALTER TABLE homology_member DROP KEY `peptide_align_feature_id`;
ALTER TABLE homology_member DROP COLUMN peptide_align_feature_id;

ALTER TABLE homology DROP COLUMN stable_id;
ALTER TABLE homology ADD KEY (ancestor_node_id);

ALTER TABLE peptide_align_feature DROP COLUMN analysis_id;

-- Projected members have the right source_name now, no need for ENSEMBLPROJ
UPDATE member SET source_name = 'ENSEMBLGENE' WHERE source_name = 'ENSEMBLPROJ';
ALTER TABLE member MODIFY COLUMN source_name ENUM('ENSEMBLGENE','ENSEMBLPEP','Uniprot/SPTREMBL','Uniprot/SWISSPROT','ENSEMBLTRANS','EXTERNALCDS') NOT NULL;


-- CAFE
-- ------

ALTER TABLE CAFE_tree DROP KEY `method_link_species_set_id`;
ALTER TABLE CAFE_tree_attr DROP KEY `fam_id`;


-- Constrained elements
-- ----------------------

ALTER TABLE constrained_element MODIFY COLUMN p_value DOUBLE DEFAULT NULL, DROP COLUMN taxonomic_level;

