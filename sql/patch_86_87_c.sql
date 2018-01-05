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

# patch_86_87_b.sql
#
# Title: New table with gene quality information from the geneset_QC pipeline.
#
# Description:
#   This table contains gene quality information from the geneset_QC pipeline

SET session sql_mode='TRADITIONAL';

INSERT INTO species_tree_node_tag SELECT stn.node_id, "coding_exon_coverage", mt.value FROM method_link_species_set mlss JOIN method_link_species_set_tag mt USING(method_link_species_set_id) JOIN species_tree_root str USING (method_link_species_set_id) JOIN species_tree_node stn USING(root_id) WHERE mlss.method_link_id IN (10,13) AND mt.tag = CONCAT("coding_exon_coverage_", stn.genome_db_id);
INSERT INTO species_tree_node_tag SELECT stn.node_id, "coding_exon_length", mt.value FROM method_link_species_set mlss JOIN method_link_species_set_tag mt USING(method_link_species_set_id) JOIN species_tree_root str USING (method_link_species_set_id) JOIN species_tree_node stn USING(root_id) WHERE mlss.method_link_id IN (10,13) AND mt.tag = CONCAT("coding_exon_length_", stn.genome_db_id);
INSERT INTO species_tree_node_tag SELECT stn.node_id, "genome_coverage", mt.value FROM method_link_species_set mlss JOIN method_link_species_set_tag mt USING(method_link_species_set_id) JOIN species_tree_root str USING (method_link_species_set_id) JOIN species_tree_node stn USING(root_id) WHERE mlss.method_link_id IN (10,13) AND mt.tag = CONCAT("genome_coverage_", stn.genome_db_id);
INSERT INTO species_tree_node_tag SELECT stn.node_id, "genome_length", mt.value FROM method_link_species_set mlss JOIN method_link_species_set_tag mt USING(method_link_species_set_id) JOIN species_tree_root str USING (method_link_species_set_id) JOIN species_tree_node stn USING(root_id) WHERE mlss.method_link_id IN (10,13) AND mt.tag = CONCAT("genome_length_", stn.genome_db_id);
DELETE FROM method_link_species_set_tag WHERE method_link_species_set_id IN (SELECT method_link_species_set_id FROM method_link_species_set WHERE method_link_id IN (10, 13)) AND (tag LIKE 'coding_exon_coverage%' OR tag LIKE 'coding_exon_length%' OR tag LIKE 'genome_coverage%' OR tag LIKE 'genome_length%');

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_86_87_c.sql|msa_stats_to_stn_tag');