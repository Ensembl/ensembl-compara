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

# patch_81_82_b.sql
#
# Title: Add "first_release" and "last_release" to the core tables
#
# Description:
#   A header table (species_set_header) is added for species-sets.
#   genome_db, species_set_header, and method_link_species_set now
#   have two #   extra columns ("first_release" and "last_release")
#   to track the #   release versions when they were loaded / active.
#   As a result, genome_db.assembly_default has been removed


-- the genome_db table
ALTER TABLE genome_db ADD COLUMN first_release smallint unsigned, ADD COLUMN last_release smallint unsigned;

# Insert dummy values for first_release and last_release
UPDATE genome_db SET first_release = 80;    -- must be set, so that all the genomes are considered as released
UPDATE genome_db SET last_release = 80 WHERE assembly_default=0;    -- non-default genome_dbs were not current any more in e81, so must have ended in e80 or before
UPDATE genome_db gdb1 JOIN genome_db gdb2 USING (name, assembly) SET gdb2.first_release = gdb1.first_release, gdb2.last_release = gdb1.last_release WHERE gdb1.genome_component IS NULL AND gdb2.genome_component IS NOT NULL;   -- Make sure the components are in sync with their principal genome_db

ALTER TABLE genome_db DROP COLUMN assembly_default;


-- the species_set_header table
CREATE TABLE species_set_header (
  species_set_id              int(10) unsigned NOT NULL AUTO_INCREMENT,
  name                        varchar(255) NOT NULL default '',
  first_release               smallint,
  last_release                smallint,

  PRIMARY KEY (species_set_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

-- first and last release can be inferred from the genome_db table
INSERT INTO species_set_header (species_set_id, first_release, last_release)
	SELECT species_set.species_set_id, IF(SUM(first_release IS NULL)>0, NULL, MAX(first_release)), IF(SUM(first_release IS NULL)>0, NULL, IF(SUM(last_release IS NOT NULL)>0, MIN(last_release), NULL))
	FROM species_set JOIN genome_db USING (genome_db_id)
	GROUP BY species_set.species_set_id;

-- Try to find the best name
UPDATE species_set_header JOIN species_set_tag USING (species_set_id) SET name = CONCAT("genetree_display_", value) WHERE tag = "genetree_display";
UPDATE species_set_header JOIN species_set_tag USING (species_set_id) SET name = CONCAT("taxon_", value) WHERE tag = "taxon_id";
UPDATE species_set_header JOIN species_set_tag USING (species_set_id) SET name = value WHERE tag = "name";
DELETE FROM species_set_tag WHERE tag = "genetree_display";
DELETE FROM species_set_tag WHERE tag = "taxon_id";
DELETE FROM species_set_tag WHERE tag = "name";

-- Insert an empty species-set
INSERT INTO species_set_header (name, first_release) VALUES ("empty", 82);

-- the method_link_species_set table
CREATE TEMPORARY TABLE method_link_species_set_time AS
	SELECT method_link_species_set_id, IF(SUM(first_release IS NULL)>0, NULL, MAX(first_release)) AS fr, IF(SUM(last_release IS NOT NULL)>0, MIN(last_release), NULL) AS lr
	FROM method_link_species_set JOIN species_set_header USING (species_set_id)
	GROUP BY method_link_species_set_id;

ALTER TABLE method_link_species_set ADD COLUMN first_release smallint unsigned, ADD COLUMN last_release smallint unsigned;
UPDATE method_link_species_set JOIN method_link_species_set_time USING (method_link_species_set_id) SET first_release = fr, last_release = lr;

-- update the species_set table
ALTER TABLE species_set
	MODIFY COLUMN species_set_id int(10) unsigned NOT NULL,
	MODIFY COLUMN genome_db_id int(10) unsigned NOT NULL,
	DROP INDEX species_set_id,
	ADD PRIMARY KEY (species_set_id,genome_db_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_81_82_b.sql|first_last_release');

