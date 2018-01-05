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

# patch_90_91_b.sql
#
# Title: Change the type of gene_member_qc.seq_member_id to allow a foreign key
#
# Description:
# Foreign keys are only allowed between columns of identical types, but
# gene_member_qc.seq_member_id was not set as "unsigned"

ALTER TABLE gene_member_qc 
      MODIFY COLUMN seq_member_id int(10) unsigned,
      ADD FOREIGN KEY (seq_member_id) REFERENCES seq_member(seq_member_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_90_91_b.sql|gene_member_qc.seq_member_id.unsigned.foreign_key');
