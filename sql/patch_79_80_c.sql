-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

# patch_79_80_c.sql
#
# Title: Add "first_release" and "last_release" to the core tables
#
# Description:
#   genome_db, species_set, and method_link_species_set now have two
#   extra columns ("first_release" and "last_release") to track the
#   release versions when they were loaded / active.
#   As a result, genome_db.assembly_default has been removed

-- the genome_db table
ALTER TABLE genome_db ADD COLUMN first_release smallint unsigned, ADD COLUMN last_release smallint unsigned;

# If there are some non-default assemblies, they must come from a previous version
UPDATE genome_db SET last_release = 79 WHERE assembly_default=0;

ALTER TABLE genome_db DROP COLUMN assembly_default;


-- the species_set table
CREATE TABLE species_set_header (
  species_set_id              int(10) unsigned NOT NULL AUTO_INCREMENT,
  name                        varchar(255) NOT NULL default '',
  first_release               smallint,
  last_release                smallint,

  PRIMARY KEY (species_set_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

INSERT INTO species_set_header
	SELECT species_set.species_set_id, IFNULL(value, ""), IF(SUM(first_release IS NULL)>0, NULL, MAX(first_release)), IF(SUM(last_release IS NOT NULL)>0, MIN(last_release), NULL)
	FROM species_set JOIN genome_db USING (genome_db_id) LEFT JOIN species_set_tag ON species_set.species_set_id = species_set_tag.species_set_id AND tag = "name"
	GROUP BY species_set.species_set_id;


-- the method_link_species_set table
CREATE TEMPORARY TABLE method_link_species_set_time AS
	SELECT method_link_species_set_id, IF(SUM(first_release IS NULL)>0, NULL, MAX(first_release)) AS fr, IF(SUM(last_release IS NOT NULL)>0, MIN(last_release), NULL) AS lr
	FROM method_link_species_set JOIN species_set_header USING (species_set_id)
	GROUP BY method_link_species_set_id;

ALTER TABLE method_link_species_set ADD COLUMN first_release smallint unsigned, ADD COLUMN last_release smallint unsigned;
UPDATE method_link_species_set JOIN method_link_species_set_time USING (method_link_species_set_id) SET first_release = fr, last_release = lr;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_79_80_c.sql|first_last_release');
