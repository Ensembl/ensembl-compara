-- Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

# patch_84_85_e.sql
#
# Title: Add new table to store the mapping between the seq_member_ids from the previous and current databases.
#
# Description:
#   Add new table to be used by copy_trees_from_previous_release in order to rename old seq_member_ids with the current ones.

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

CREATE TABLE `seq_member_id_current_reused_map` (
  stable_id                 varchar(128) NOT NULL, # e.g. ENSP000001234 or P31946
  seq_member_id_reused      int(10) unsigned NOT NULL,
  seq_member_id_current     int(10) unsigned NOT NULL,

  FOREIGN KEY (seq_member_id_current) REFERENCES seq_member(seq_member_id),

  PRIMARY KEY (stable_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_e.sql|seq_member_id_current_reused_map');
