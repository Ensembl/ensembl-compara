-- See the NOTICE file distributed with this work for additional information
-- regarding copyright ownership.
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

# patch_103_104_c.sql
#
# Title: Fix some SQL integer types
#
# Description:
#   Several SQL integer types were misleading:
#     - int(2) still takes 32 bits, tinyint is more suitable for a strand
#     - int(12) makes no sense as 32 bits are 10 digits at most
#     - int(4) is probably the right display width, but size is not critical
#       so we keep an int instead of switching to tinyint

ALTER TABLE constrained_element
    MODIFY COLUMN dnafrag_start INT UNSIGNED NOT NULL,
    MODIFY COLUMN dnafrag_end INT UNSIGNED NOT NULL,
    MODIFY COLUMN dnafrag_strand TINYINT NOT NULL;
ALTER TABLE CAFE_species_gene
    MODIFY COLUMN n_members INT UNSIGNED NOT NULL;
ALTER TABLE dnafrag
    MODIFY COLUMN codon_table_id TINYINT UNSIGNED DEFAULT 1 NOT NULL;
ALTER TABLE exon_boundaries
    MODIFY COLUMN dnafrag_start INT UNSIGNED NOT NULL,
    MODIFY COLUMN dnafrag_end INT UNSIGNED NOT NULL,
    MODIFY COLUMN left_over TINYINT UNSIGNED DEFAULT 0 NOT NULL;
ALTER TABLE gene_align
    MODIFY COLUMN aln_length INT UNSIGNED NOT NULL DEFAULT 0;
ALTER TABLE gene_member
    MODIFY COLUMN dnafrag_start INT UNSIGNED,
    MODIFY COLUMN dnafrag_end INT UNSIGNED,
    MODIFY COLUMN version INT UNSIGNED DEFAULT 0;
ALTER TABLE gene_tree_node
    MODIFY COLUMN left_index INT UNSIGNED NOT NULL default 0,
    MODIFY COLUMN right_index INT UNSIGNED NOT NULL default 0;
ALTER TABLE genomic_align
    MODIFY COLUMN dnafrag_start INT UNSIGNED DEFAULT 0 NOT NULL,
    MODIFY COLUMN dnafrag_end INT UNSIGNED DEFAULT 0 NOT NULL,
    MODIFY COLUMN visible TINYINT UNSIGNED DEFAULT 1 NOT NULL;
ALTER TABLE genomic_align_block
    MODIFY COLUMN length INT UNSIGNED NOT NULL,
    MODIFY COLUMN level_id TINYINT UNSIGNED DEFAULT 0 NOT NULL,
    MODIFY COLUMN direction TINYINT UNSIGNED DEFAULT NULL;
ALTER TABLE genomic_align_tree
    MODIFY COLUMN left_index INT UNSIGNED NOT NULL default 0,
    MODIFY COLUMN right_index INT UNSIGNED NOT NULL default 0;
ALTER TABLE other_member_sequence
    MODIFY COLUMN length INT UNSIGNED NOT NULL;
ALTER TABLE peptide_align_feature
    MODIFY COLUMN qstart INT UNSIGNED DEFAULT 0 NOT NULL,
    MODIFY COLUMN qend INT UNSIGNED DEFAULT 0 NOT NULL,
    MODIFY COLUMN align_length INT UNSIGNED NOT NULL,
    MODIFY COLUMN identical_matches INT UNSIGNED NOT NULL,
    MODIFY COLUMN positive_matches INT UNSIGNED NOT NULL,
    MODIFY COLUMN perc_ident TINYINT UNSIGNED NOT NULL,
    MODIFY COLUMN perc_pos TINYINT UNSIGNED NOT NULL,
    MODIFY COLUMN hit_rank SMALLINT UNSIGNED NOT NULL;
ALTER TABLE seq_member
    MODIFY COLUMN dnafrag_start INT UNSIGNED,
    MODIFY COLUMN dnafrag_end INT UNSIGNED,
    MODIFY COLUMN version INT UNSIGNED DEFAULT 0;
ALTER TABLE sequence
    MODIFY COLUMN length INT UNSIGNED NOT NULL;
ALTER TABLE species_tree_node
    MODIFY COLUMN left_index INT UNSIGNED NOT NULL default 0,
    MODIFY COLUMN right_index INT UNSIGNED NOT NULL default 0;

-- ALTER TABLE
    -- MODIFY COLUMN INT UNSIGNED NOT NULL;
# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_103_104_c.sql|fix_int_types');
