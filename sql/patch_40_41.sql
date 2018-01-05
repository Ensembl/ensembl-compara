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


# Updating the schema version

DELETE FROM meta WHERE meta_key="schema_version";
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",41);

# Add displayable column to analysis_description table

ALTER TABLE analysis_description ADD COLUMN displayable BOOLEAN DEFAULT 1 NOT NULL;

# Add display_label column to member table

ALTER TABLE member ADD COLUMN display_label VARCHAR(128) DEFAULT NULL;

# Add ancestor_node_id to homology table

ALTER TABLE homology ADD COLUMN node_id int(10) unsigned DEFAULT NULL;

# change description column in member table from varchar(255) to text

ALTER TABLE member MODIFY COLUMN description TEXT DEFAULT NULL;
