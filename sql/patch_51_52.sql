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

UPDATE meta SET meta_value = 52 where meta_key = "schema_version";

#Update sitewise_aln table
ALTER TABLE sitewise_aln ADD COLUMN optimal float(10,5) AFTER omega_upper;
ALTER TABLE sitewise_aln ADD COLUMN ncod int(10) AFTER optimal;
ALTER TABLE sitewise_aln ADD INDEX (tree_node_id);
ALTER TABLE sitewise_aln MODIFY COLUMN type
ENUM('all_gaps','constant','default','negative1','negative2','negative3','negative4','positive1','positive2','positive3','positive4','synonymous') NOT NULL;

#Change from varchar to enum field
ALTER TABLE homology MODIFY COLUMN description
ENUM('ortholog_one2one','apparent_ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','between_species_paralog');
