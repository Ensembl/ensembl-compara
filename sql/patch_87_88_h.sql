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

# patch_87_88_h.sql
#
# Title: Add a table to store exon coordinates
#
# Description:
#   Coordinates are assumed to be on the same dnafrag as their seq_member
#   sequence_length is the number of characters of the sequence that can be
#   associated to this exon. The phase of each exon is kept in the left_over
#   column which tells the number of nucleotides that are not part of whole
#   codons in this exon

CREATE TABLE exon_boundaries (
	gene_member_id   INT(10) UNSIGNED NOT NULL,
	seq_member_id    INT(10) UNSIGNED NOT NULL,
	dnafrag_start    INT NOT NULL,
	dnafrag_end      INT NOT NULL,
	sequence_length  INT(10) UNSIGNED NOT NULL,
	left_over        TINYINT(1) DEFAULT 0 NOT NULL,
	INDEX (seq_member_id),
	INDEX (gene_member_id)
) ENGINE=MyISAM;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_87_88_h.sql|exon_boundaries');

