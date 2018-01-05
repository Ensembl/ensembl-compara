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

# patch_83_84_e.sql
#
# Title: Add new table to store arbitrary structured data around gene trees
#
# Description:
#   Add new table that can be used to store precomputed tracks / layer of
#   information that can be later transfered to clients

CREATE TABLE `gene_tree_object_store` (
  root_id             INT(10) UNSIGNED NOT NULL,
  data_label          VARCHAR(255) NOT NULL,
  compressed_data     MEDIUMBLOB NOT NULL,

  FOREIGN KEY (root_id) REFERENCES gene_tree_root(root_id),

  PRIMARY KEY (root_id, data_label)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_83_84_e.sql|gene_tree_object_store');
