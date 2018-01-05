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
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",42);

# Add a UNIQUE constraint to the analysis_description.analysis_id

ALTER TABLE analysis_description DROP INDEX analysis_idx;
ALTER TABLE analysis_description ADD UNIQUE analysis_idx (analysis_id);

# description: Add web_data column to analysis_description.

ALTER TABLE analysis_description ADD COLUMN web_data TEXT;

# Add a PRIMARY KEY to the ncbi_taxa_node.taxon_id

ALTER TABLE ncbi_taxa_node DROP INDEX taxon_id;
ALTER TABLE ncbi_taxa_node ADD PRIMARY KEY (taxon_id);
