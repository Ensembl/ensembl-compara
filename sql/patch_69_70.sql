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


-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';


-- Table structure for table `CAFE_data`

SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CAFE_data` (
  `fam_id` varchar(20) NOT NULL,
  `tree` mediumtext NOT NULL,
  `tabledata` mediumtext NOT NULL,
  PRIMARY KEY (`fam_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;


-- left/right_index

ALTER TABLE ncbi_taxa_node
	MODIFY COLUMN left_index int(10) DEFAULT 0 NOT NULL,
	MODIFY COLUMN right_index int(10) DEFAULT 0 NOT NULL;

ALTER TABLE genomic_align_tree
	DROP KEY left_index,
	ADD KEY left_index (root_id, left_index),
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
DROP TABLE sequence_exon_bounded;
INSERT INTO other_member_sequence SELECT member_id, 'cds', length, sequence_cds FROM sequence_cds;
DROP TABLE sequence_cds;


-- gene_tree_node

ALTER TABLE gene_tree_node
	ADD COLUMN member_id int(10) unsigned,
	ADD INDEX member_id (member_id);
ALTER TABLE gene_tree_node 
	DROP KEY `root_id_2`,DROP KEY `root_id`, 
	ADD INDEX root_id_left_index (root_id,left_index),
	ADD INDEX root_id (root_id);

UPDATE gene_tree_node JOIN gene_tree_member USING (node_id) SET gene_tree_node.member_id = gene_tree_member.member_id;
ALTER TABLE gene_tree_member DROP COLUMN member_id;


-- subset
ALTER TABLE member
	ADD COLUMN canonical_member_id int(10) unsigned AFTER gene_member_id;
UPDATE subset_member sm JOIN member mp USING (member_id) JOIN member mg ON mg.member_id = mp.gene_member_id SET mg.canonical_member_id = mp.member_id;


-- reference tree
ALTER TABLE gene_tree_root
	ADD COLUMN ref_root_id INT(10) UNSIGNED AFTER method_link_species_set_id,
	ADD KEY ref_root_id (ref_root_id);
UPDATE gene_tree_root JOIN gene_tree_root_tag USING (root_id)
	SET ref_root_id = value
	WHERE clusterset_id != "default" AND tag LIKE "%\_tree\_root\_id";
DELETE gene_tree_root_tag
	FROM gene_tree_root JOIN gene_tree_root_tag USING (root_id)
	WHERE clusterset_id != "default" AND tag LIKE "%\_tree\_root\_id";
DELETE gtrt
	FROM gene_tree_root_tag gtrt JOIN gene_tree_root gtr ON gtr.ref_root_id = gtrt.root_id
	WHERE tag LIKE "%\_tree\_root\_id" AND gtr.root_id = value;


-- tree support
INSERT INTO gene_tree_node_tag
	SELECT node_id, 'tree_support', 'phyml_nt'
	FROM gene_tree_node_attr
	WHERE FIND_IN_SET('phyml_nt', tree_support);

INSERT INTO gene_tree_node_tag
	SELECT node_id, 'tree_support', 'phyml_aa'
	FROM gene_tree_node_attr
	WHERE FIND_IN_SET('phyml_aa', tree_support);

INSERT INTO gene_tree_node_tag
	SELECT node_id, 'tree_support', 'nj_ds'
	FROM gene_tree_node_attr
	WHERE FIND_IN_SET('nj_ds', tree_support);

INSERT INTO gene_tree_node_tag
	SELECT node_id, 'tree_support', 'nj_dn'
	FROM gene_tree_node_attr
	WHERE FIND_IN_SET('nj_dn', tree_support);

INSERT INTO gene_tree_node_tag
	SELECT node_id, 'tree_support', 'nj_mm'
	FROM gene_tree_node_attr
	WHERE FIND_IN_SET('nj_mm', tree_support);

INSERT INTO gene_tree_node_tag
	SELECT node_id, 'tree_support', 'quicktree'
	FROM gene_tree_node_attr
	WHERE FIND_IN_SET('quicktree', tree_support);

ALTER TABLE gene_tree_node_attr DROP COLUMN tree_support;


-- gene_align

CREATE TABLE gene_align (
       gene_align_id         int(10) unsigned NOT NULL AUTO_INCREMENT,
	 seq_type              varchar(40),
	 aln_method            varchar(40) NOT NULL DEFAULT '',
	 aln_length            int(10) NOT NULL DEFAULT 0,

  PRIMARY KEY (gene_align_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


CREATE TABLE gene_align_member (
       gene_align_id         int(10) unsigned NOT NULL,
       member_id             int(10) unsigned NOT NULL,
       cigar_line            mediumtext,

  FOREIGN KEY (gene_align_id) REFERENCES gene_align(gene_align_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),

  PRIMARY KEY (gene_align_id,member_id),
  KEY member_id (member_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

ALTER TABLE gene_tree_root ADD COLUMN gene_align_id INT(10) UNSIGNED  DEFAULT NULL AFTER method_link_species_set_id,
	ADD KEY `gene_align_id` (`gene_align_id`);

INSERT INTO gene_align SELECT root_id, NULL, IF(member_type = "ncrna", "infernal", IF(clusterset_id = "default", "mcoffee", "mafft")), 0 FROM gene_tree_root JOIN gene_tree_node USING (root_id) JOIN gene_tree_member USING (node_id) WHERE cigar_line IS NOT NULL GROUP BY root_id;

INSERT INTO gene_align_member SELECT root_id, member_id, cigar_line FROM gene_tree_root JOIN gene_tree_node USING (root_id) JOIN gene_tree_member USING (node_id) WHERE cigar_line IS NOT NULL;
UPDATE gene_align JOIN gene_tree_root ON gene_tree_root.root_id = gene_align.gene_align_id SET gene_tree_root.gene_align_id = gene_tree_root.root_id;

UPDATE gene_tree_root gref JOIN gene_tree_root gsub ON gref.root_id=gsub.ref_root_id SET gsub.gene_align_id=gref.gene_align_id;
DELETE gene_tree_member FROM gene_tree_member JOIN gene_tree_node USING (node_id) JOIN gene_tree_root USING (root_id) WHERE gene_align_id IS NOT NULL;

-- gene_tree_member should now be empty
DROP TABLE gene_tree_member;



-- protein-tree HMM profiles

INSERT INTO hmm_profile (model_id, type, hc_profile) SELECT CONCAT(type, "_", node_id), "hmmer", hmmprofile FROM protein_tree_hmmprofile;
DROP TABLE protein_tree_hmmprofile;



-- protein_tree_member_score

INSERT INTO gene_align (aln_method) VALUES ("mcoffee_scores");
INSERT INTO gene_align_member SELECT LAST_INSERT_ID() , member_id, cigar_line FROM protein_tree_member_score;
DROP TABLE protein_tree_member_score;


-- New version
REPLACE INTO meta (species_id, meta_key, meta_value)
VALUES (NULL, 'schema_version', '70');

