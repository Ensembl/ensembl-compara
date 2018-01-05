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

# patch_87_88_c.sql
#
# Title: New column in the dnafrag table to track the codon-table of each sequence
#
# Description:
#   This new column allows to select the appropriate codon-table when running codeml
#   without having to connect to the core database.

SET session sql_mode='TRADITIONAL';

ALTER TABLE dnafrag ADD COLUMN codon_table_id tinyint(2) unsigned DEFAULT 1 NOT NULL;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_87_88_c.sql|codon_table_id');
