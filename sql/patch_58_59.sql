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

# Updating the schema version:
UPDATE meta SET meta_value = 59 where meta_key = "schema_version";

# Use production names, i.e. no whitespaces and all lowercases:
UPDATE genome_db SET name = LCASE(REPLACE(name, " ", "_"));

# a new column to the dnafrag table to hold information about whether
# a DnaFrag is part of the reference assembly or not:
ALTER TABLE dnafrag ADD COLUMN is_reference tinyint(1) DEFAULT 1;
UPDATE dnafrag, genome_db
 SET is_reference = 0
 WHERE dnafrag.genome_db_id = genome_db.genome_db_id
 AND genome_db.name = "homo_sapiens"
 AND coord_system_name = "chromosome"
 AND (dnafrag.name like "H%" or dnafrag.name like "c%");

# Adding indexes to the taxonomy tables to speed up searches
ALTER TABLE ncbi_taxa_node ADD KEY left_index(left_index);
ALTER TABLE ncbi_taxa_node ADD KEY right_index(right_index);
