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

-- Updating the schema version
UPDATE meta SET meta_value = 57 where meta_key = "schema_version";

-- a partitioned table cannot have any keys but the primary key
ALTER TABLE peptide_align_feature DROP KEY qgenome_db_id;
ALTER TABLE peptide_align_feature DROP KEY hgenome_db_id;
ALTER TABLE peptide_align_feature DROP KEY analysis_id;
ALTER TABLE peptide_align_feature DROP KEY qmember_id;
ALTER TABLE peptide_align_feature DROP KEY hmember_id;
ALTER TABLE peptide_align_feature DROP KEY hmember_qgenome;
ALTER TABLE peptide_align_feature DROP KEY qmember_hgenome;

-- this table is used for production only
DROP TABLE peptide_align_feature_prod;

--   This table holds the sequence exon boundaries information
CREATE TABLE sequence_exon_bounded (
  sequence_exon_bounded_id    int(10) unsigned NOT NULL auto_increment, # unique internal id
  member_id                   int(10) unsigned NOT NULL, # unique internal id
  length                      int(10) NOT NULL,
  sequence_exon_bounded       longtext NOT NULL,

  FOREIGN KEY (member_id) REFERENCES member(member_id),

  PRIMARY KEY (sequence_exon_bounded_id),
  KEY (member_id),
  KEY sequence_exon_bounded (sequence_exon_bounded(18))
);

