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

# patch_84_85_f.sql
#
# Title: Change some keys (mainly in the _tag tables)
#
# Description:
#   Added a primary key when there were already some UNIQUE+NOT NULL columns
#   Uniformized the keys in the _tag tables


-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';


ALTER TABLE CAFE_species_gene
	DROP KEY cafe_gene_family_id,
	ADD PRIMARY KEY (cafe_gene_family_id, node_id);
 
ALTER TABLE species_set_tag
	DROP KEY tag_species_set_id,
	ADD PRIMARY KEY (species_set_id,tag),
	ADD KEY tag (tag);
 
ALTER TABLE method_link_species_set_tag
	ADD KEY tag (tag);
 
ALTER TABLE species_tree_node_tag
	DROP KEY tag_node_id,
	DROP KEY node_id;
 
ALTER TABLE gene_tree_node_tag
	DROP KEY node_id,
	ADD KEY tag (tag);
 
# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_f.sql|keys');
