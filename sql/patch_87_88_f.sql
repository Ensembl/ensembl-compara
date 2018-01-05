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

# patch_87_88_f.sql
#
# Title: New column in the seq_member table to track the SeqEdits
#
# Description:
#   These new columns indicate whether there are SeqEdits modifying the
#   transcript and translation sequences.

ALTER TABLE seq_member ADD COLUMN has_transcript_edits tinyint(1) DEFAULT 0 NOT NULL AFTER gene_member_id;
ALTER TABLE seq_member ADD COLUMN has_translation_edits tinyint(1) DEFAULT 0 NOT NULL AFTER has_transcript_edits;

UPDATE seq_member JOIN other_member_sequence USING (seq_member_id) JOIN sequence USING (sequence_id)
SET has_translation_edits = 1
WHERE seq_type = "cds" AND ABS(sequence.length*3-other_member_sequence.length)>3;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_87_88_f.sql|has_seq_edits');

