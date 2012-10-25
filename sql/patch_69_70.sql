
-- left/right_index

ALTER TABLE ncbi_taxa_node
	MODIFY COLUMN left_index int(10) DEFAULT 0 NOT NULL,
	MODIFY COLUMN right_index int(10) DEFAULT 0 NOT NULL;

ALTER TABLE genomic_align_tree
	DROP KEY right_index;

ALTER TABLE species_tree_node
	DROP KEY root_id_2;

DROP TABLE lr_index_offset;


-- Other sequences

CREATE TABLE other_member_sequence (
  member_id                   int(10) unsigned NOT NULL, # unique internal id
  seq_type                    VARCHAR(40) NOT NULL,
  length                      int(10) NOT NULL,
  sequence                    longtext NOT NULL,

  FOREIGN KEY (member_id) REFERENCES member(member_id),

  PRIMARY KEY (member_id, seq_type),
  KEY (seq_type, member_id),
  KEY sequence (sequence(18))
) MAX_ROWS = 10000000 AVG_ROW_LENGTH = 60000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;

INSERT INTO other_member_sequence SELECT member_id, 'exon_bounded', length, sequence_exon_bounded FROM sequence_exon_bounded;
-- DROP TABLE sequence_exon_bounded
INSERT INTO other_member_sequence SELECT member_id, 'cds', length, sequence_cds FROM sequence_cds;
-- DROP TABLE sequence_cds


-- gene_tree_member

ALTER TABLE gene_tree_node
	ADD COLUMN member_id int(10) unsigned,
	ADD INDEX member_id (member_id);
UPDATE gene_tree_node JOIN gene_tree_member USING (node_id) SET gene_tree_node.member_id = gene_tree_member.member_id;
ALTER TABLE gene_tree_member
	DROP COLUMN member_id;


-- subset
ALTER TABLE member
	ADD COLUMN canonical_member_id int(10) unsigned AFTER gene_member_id;
UPDATE subset_member sm JOIN member mp USING (member_id) JOIN member mg ON mg.member_id = mp.gene_member_id SET mg.canonical_member_id = mp.member_id;


