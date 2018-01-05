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

UPDATE meta SET meta_value = 45 where meta_key = "schema_version";

# Add new column in the genomic_align_block table

ALTER TABLE genomic_align_block ADD group_id bigint unsigned DEFAULT NULL;

# Move "default" and "split" groups to the new column

UPDATE genomic_align_block gab, genomic_align ga, genomic_align_group gag SET gab.group_id = gag.group_id
 WHERE gab.genomic_align_block_id = ga.genomic_align_block_id AND ga.genomic_align_id = gag.genomic_align_id
 AND gag.type IN ("default", "split");

DELETE FROM genomic_align_group WHERE type IN ("default", "split");

