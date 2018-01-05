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
UPDATE meta SET meta_value = 62 where meta_key = "schema_version";

# extending analysis.module field to 255 characters (used to be 80, which is too limiting):
ALTER TABLE analysis MODIFY COLUMN module varchar(255);

# extending the length of meta.meta_value to text
ALTER TABLE meta DROP INDEX species_key_value_idx;
ALTER TABLE meta DROP INDEX species_value_idx;
ALTER TABLE meta MODIFY COLUMN meta_value TEXT NOT NULL;
ALTER TABLE meta ADD UNIQUE KEY species_key_value_idx (species_id,meta_key,meta_value(255));
ALTER TABLE meta ADD        KEY species_value_idx (species_id,meta_value(255));

# Done to alter the mapping session code
alter table mapping_session drop index `type`;
alter table mapping_session add column prefix CHAR(4);
update mapping_session set prefix = 'ENS';
alter table mapping_session modify column prefix CHAR(4) NOT NULL;

# Auto-populate lr_index_offset with all tables
ALTER TABLE lr_index_offset DROP PRIMARY KEY;
ALTER TABLE lr_index_offset 
  ADD COLUMN lr_index_offset_id int(10) unsigned NOT NULL AUTO_INCREMENT FIRST, 
  ADD PRIMARY KEY (lr_index_offset_id),
  ADD UNIQUE INDEX (table_name)
;
INSERT IGNORE INTO lr_index_offset (table_name, lr_index)
values
      ('protein_tree_node', 0),
      ('ncbi_taxa_node', 0),
      ('genomic_align_tree', 0),
      ('nc_tree_node', 0),
      ('super_protein_tree_node', 0);

alter table mapping_session add index `type` (`type`,`rel_from`,`rel_to`, `prefix`);
