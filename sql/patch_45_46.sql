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

UPDATE meta SET meta_value = 46 where meta_key = "schema_version";

# Renamed node_id to ancestor_node_id and created a tree_node_id that
# will make queries easier and faster when relating homologies to whole
# trees

ALTER TABLE homology CHANGE COLUMN node_id ancestor_node_id int(10) unsigned NOT NULL;

ALTER TABLE homology ADD COLUMN tree_node_id int(10) unsigned NOT NULL;
