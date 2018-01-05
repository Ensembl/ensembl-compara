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

# patch_84_85_d.sql
#
# Title: Add size-distribution data for WGAs
#
# Description:
#   The distribution of WGA-block sizes has recently been introduced
#   but earlier WGAs have not been updated.

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

# Pairwise-alignments
INSERT IGNORE INTO method_link_species_set_tag
	SELECT method_link_species_set_id, CONCAT("num_chains_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, COUNT(*) AS value
	FROM genomic_align_block JOIN method_link_species_set USING (method_link_species_set_id)
	WHERE method_link_id IN (1,7,16,21)
	GROUP BY method_link_species_set_id, tag;

INSERT IGNORE INTO method_link_species_set_tag
	SELECT method_link_species_set_id, CONCAT("totlength_chains_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, SUM(length) AS value
	FROM genomic_align_block JOIN method_link_species_set USING (method_link_species_set_id)
	WHERE method_link_id IN (1,7,16,21)
	GROUP BY method_link_species_set_id, tag;

INSERT IGNORE INTO method_link_species_set_tag
	SELECT method_link_species_set_id, CONCAT("num_nets_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, COUNT(*) AS value
	FROM (
		SELECT method_link_species_set_id, SUM(length) AS length
		FROM genomic_align_block JOIN method_link_species_set USING (method_link_species_set_id)
		WHERE method_link_id IN (1,7,16,21)
		GROUP BY method_link_species_set_id, group_id
	) tmp
	GROUP BY method_link_species_set_id, tag;

INSERT IGNORE INTO method_link_species_set_tag
	SELECT method_link_species_set_id, CONCAT("totlength_nets_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, SUM(length) AS value
	FROM (
		SELECT method_link_species_set_id, SUM(length) AS length
		FROM genomic_align_block JOIN method_link_species_set USING (method_link_species_set_id)
		WHERE method_link_id IN (1,7,16,21)
		GROUP BY method_link_species_set_id, group_id
	) tmp
	GROUP BY method_link_species_set_id, tag;


# Multiple-alignments
INSERT IGNORE INTO method_link_species_set_tag
	SELECT method_link_species_set_id, CONCAT("num_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, COUNT(*) AS value
	FROM genomic_align_block JOIN method_link_species_set USING (method_link_species_set_id)
	WHERE method_link_id IN (10,13,14)
	GROUP BY method_link_species_set_id, tag;

INSERT IGNORE INTO method_link_species_set_tag
	SELECT method_link_species_set_id, CONCAT("totlength_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, SUM(length) AS value
	FROM genomic_align_block JOIN method_link_species_set USING (method_link_species_set_id)
	WHERE method_link_id IN (10,13,14)
	GROUP BY method_link_species_set_id, tag;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_d.sql|wga_size_distribution');
