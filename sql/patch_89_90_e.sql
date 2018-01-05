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

# patch_89_90_e.sql
#
# Title: Add "seq_member_projection" tables
#
# Description:
#   The tables will be used to hold genebuild information about transcript
#   projections. The pipelines will use the table to classify the projections
#   in the same clusters as their source.
#   There are two tables: one that has links to stable_ids (as loaded from
#   the core database), and one where links are to seq_member_ids


CREATE TABLE seq_member_projection (
  target_seq_member_id      int(10) unsigned NOT NULL,
  source_seq_member_id      int(10) unsigned NOT NULL,
  identity                  FLOAT(5,2) DEFAULT NULL,

  FOREIGN KEY (target_seq_member_id) REFERENCES seq_member (seq_member_id),
  FOREIGN KEY (source_seq_member_id) REFERENCES seq_member (seq_member_id),

  PRIMARY KEY (target_seq_member_id),
  KEY (source_seq_member_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE seq_member_projection_stable_id (
  target_seq_member_id      int(10) unsigned NOT NULL,
  source_stable_id          VARCHAR(128) NOT NULL,

  FOREIGN KEY (target_seq_member_id) REFERENCES seq_member(seq_member_id),

  PRIMARY KEY (target_seq_member_id),
  INDEX (source_stable_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_89_90_e.sql|seq_member_projection');

