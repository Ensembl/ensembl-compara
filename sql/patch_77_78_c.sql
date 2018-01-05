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

# patch_77_78_c.sql
#
# Title: Add new tables to store protein classification
#
# Description:
#   Add new tables that can be used to store the classification
#   of seq_members against an HMM library

CREATE TABLE hmm_annot (
  seq_member_id              int(10) unsigned NOT NULL, # FK homology.homology_id
  model_id                   varchar(40) DEFAULT NULL,
  evalue                     float,

  PRIMARY KEY (seq_member_id),
  KEY (model_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


CREATE TABLE hmm_curated_annot (
  seq_member_stable_id       varchar(40) NOT NULL,
  model_id                   varchar(40) DEFAULT NULL,
  library_version            varchar(40) NOT NULL,
  annot_date                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reason                     MEDIUMTEXT,

  PRIMARY KEY (seq_member_stable_id),
  KEY (model_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_77_78_c.sql|hmm_tables');
