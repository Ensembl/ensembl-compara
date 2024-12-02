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


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'dnafrag_chunk'
--
-- overview: This tables holds chunking information.
--
-- semantics:
--   dnafrag_chunk_id     - primary key
--   dnafrag_chunk_set_id - foreign key link to dnafrag_chunk_set table
--   dnafrag_id           - foreign key link to dnafrag table
--   dnafrag_start        - start offset in dnafrag
--   dnafrag_end          - end offset in dnafrag
--   sequence_id          - optional use (store chunk sequence in DB)

CREATE TABLE dnafrag_chunk (
  dnafrag_chunk_id           int(10) NOT NULL auto_increment,
  dnafrag_chunk_set_id       int(10) NOT NULL,
  dnafrag_id                 bigint unsigned NOT NULL DEFAULT 0,
  dnafrag_start              int(10) unsigned NOT NULL DEFAULT 0,
  dnafrag_end                int(10) unsigned NOT NULL DEFAULT 0,

  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),

  PRIMARY KEY (dnafrag_chunk_id),
  UNIQUE KEY uniq_chunk (dnafrag_chunk_set_id, dnafrag_id, dnafrag_start, dnafrag_end)
) ENGINE=InnoDB;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'dnafrag_chunk_set'
--
-- overview: This tables holds sets of dnafrag_chunk references
--
-- semantics:
--   dnafrag_chunk_set_id - primary key
--   dna_collection_id    - foreign key link to dna_collection table
--   description          - unique string describing this chunk_set

CREATE TABLE dnafrag_chunk_set (
 dnafrag_chunk_set_id    int(10) NOT NULL auto_increment,
 dna_collection_id       int(10) NOT NULL,
 description             varchar(255),

 PRIMARY KEY (dnafrag_chunk_set_id)
) ENGINE=InnoDB;



-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'dna_collection'
--
-- overview: The dna_collection table is
--           linked to the dnafrag_chunk_set table and the dnafrag_chunk_set table is linked to the
--           dnafrag_chunk table. The dna_collection table holds information relevant to all the
--           underlying dnafrag_chunks ie masking. The description field is a unique
--           identifier and is used to retrieve a specific dna_collection since this is known prior
--           to storage.
-- semantics:
--   dna_collection_id   - primary key
--   description         - unique description of collection
--   masking             - masking mode (NULL, "soft" or "hard)

CREATE TABLE dna_collection (
 dna_collection_id       int(10) NOT NULL auto_increment,
 description             varchar(255),
 masking                 varchar(4),

 PRIMARY KEY (dna_collection_id),
 UNIQUE (description)

) ENGINE=InnoDB DEFAULT CHARSET=latin1;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'anchor_sequence'
--
-- This table stores anchor sequences and associated information
--


CREATE TABLE `anchor_sequence` (
  `anchor_seq_id` bigint unsigned NOT NULL auto_increment,
  `method_link_species_set_id` int(10) unsigned default NULL,
  `anchor_id` bigint unsigned default NULL,
  `dnafrag_id` bigint unsigned default NULL,
  `dnafrag_start` INT unsigned default NULL,
  `dnafrag_end` INT unsigned default NULL,
  `dnafrag_strand` tinyint(4) default '0',
  `sequence` varchar(250) default '',
  `length` INT unsigned default NULL,
  PRIMARY KEY  (`anchor_seq_id`),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),
  KEY `anchor_id_mlss_id` (`anchor_id`, `method_link_species_set_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


--
-- Table structure for table 'anchor_align'
--
-- This table stores anchor information after they have been mapped (exonerated) to target genomes
--


CREATE TABLE `anchor_align` (
  `anchor_align_id` bigint unsigned NOT NULL auto_increment,
  `method_link_species_set_id` int(10) unsigned default NULL,
  `anchor_id` bigint unsigned default NULL,
  `dnafrag_id` bigint unsigned default NULL,
  `dnafrag_start` INT default NULL,
  `dnafrag_end` INT default NULL,
  `dnafrag_strand` tinyint(4) default NULL,
  `score` float default NULL,
  `num_of_organisms` smallint(5) unsigned default NULL,
  `num_of_sequences` smallint(5) unsigned default NULL,
  `evalue` varchar(10) default NULL,
  `untrimmed_anchor_align_id` bigint unsigned default NULL,
  `is_overlapping` tinyint(1) not null default 0,
  PRIMARY KEY  (`anchor_align_id`),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),
  KEY `untrimmed_anchor_align_id` (`untrimmed_anchor_align_id`),
  KEY `anchor_id_mlss_id` (`anchor_id`,`method_link_species_set_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


-- ----------------------------------------------------------------------------------------------
--
-- This is a temporary table used by family pipeline to hold the blast scores to be fed into MCL
--

CREATE TABLE `mcl_sparse_matrix` (
    `row_id` int(10) unsigned NOT NULL,     # sequence_id, 1st dimension
    `column_id` int(10) unsigned NOT NULL,  # sequence_id, 2nd dimension
    `value` float DEFAULT NULL,             # the blast score (e-value) on the intersection
    PRIMARY KEY (`row_id`,`column_id`)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------------------------
--
-- This is a temporary table used by ConstrainedElementAdaptor to create unique constrained_element_ids
--

CREATE TABLE constrained_element_production (
       constrained_element_id bigint unsigned NOT NULL AUTO_INCREMENT, # unique internal id,
       PRIMARY KEY constrained_element_id (constrained_element_id)
) ENGINE=InnoDB;

## These are non-coding RNA pipeline specific tables:

DROP TABLE IF EXISTS ktreedist_score;
CREATE TABLE ktreedist_score (
  node_id int(10) unsigned NOT NULL,
  tag varchar(50) NOT NULL DEFAULT '',
  k_score_rank int(10) default NULL,
  k_score float DEFAULT NULL,
  scale_factor float DEFAULT NULL,
  symm_difference int(10) unsigned DEFAULT NULL,
  n_partitions int(10) unsigned DEFAULT NULL,
  PRIMARY KEY tag_node_id (node_id,tag),
  FOREIGN KEY (node_id) REFERENCES gene_tree_root(root_id),
  KEY tag (tag)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


DROP TABLE IF EXISTS recovered_member;
CREATE TABLE recovered_member (
  recovered_id  int(10) unsigned NOT NULL AUTO_INCREMENT,
  node_id int(10) unsigned NOT NULL,
  stable_id varchar(128) NOT NULL,
  genome_db_id int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (recovered_id),
  UNIQUE KEY (stable_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


-- These tables are for passing CAFE species trees and CAFE tables between runnables for
-- CAFE Analysis

DROP TABLE IF EXISTS CAFE_data;
CREATE TABLE CAFE_data (
       fam_id                 int unsigned NOT NULL AUTO_INCREMENT,
       tree                   mediumtext NOT NULL,
       tabledata              mediumtext NOT NULL,

PRIMARY KEY (fam_id)
) ENGINE=InnoDB;




CREATE TABLE split_genes (
	seq_member_id   	int(10) unsigned NOT NULL,
	gene_split_id	int(10) unsigned NOT NULL AUTO_INCREMENT,

	PRIMARY KEY (seq_member_id),
	KEY gene_split_id (gene_split_id),

	FOREIGN KEY seq_member_id (seq_member_id) REFERENCES seq_member (seq_member_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


CREATE TABLE gene_tree_backup (
	seq_member_id	int(10) unsigned NOT NULL,
	root_id	int(10) unsigned NOT NULL,
	is_removed      tinyint(1) DEFAULT 0,

	PRIMARY KEY (root_id, seq_member_id),
	KEY (is_removed),
	KEY (seq_member_id)

) ENGINE=InnoDB DEFAULT CHARSET=latin1;



-- ----------------------------------------------------------------------------------
--
-- Table structure for tables 'panther_annot'
--
-- overview: These tables contain the InterPro classification of the Ensembl proteins

CREATE TABLE IF NOT EXISTS panther_annot (
	upi char(13) NOT NULL,
	ensembl_id char(50) NOT NULL,
	ensembl_div char(15) NOT NULL,
	panther_family_id char(15) NOT NULL,
	start int unsigned NOT NULL,
	end int unsigned NOT NULL,
	score int(11) NOT NULL,
	evalue char(25) NOT NULL,

	PRIMARY KEY (ensembl_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'hmm_thresholding'
--
-- overview: This table stores the HMM annotation of the seq_members

/**
    @table hmm_thresholding
    @desc  This table stores the HMM annotation of the seq_members
    @colour   #66CCFF

    @column seq_member_id         External reference to a seq_member_id in the @link seq_member table
    @column model_id              External reference to the internal numeric ID of a HMM profile in @link hmm_profile
    @column root_id     	      External reference to the internal unique ID
    @column evalue                The e-value of the hit
*/

CREATE TABLE hmm_thresholding (
      seq_member_id             INT(10) UNSIGNED NOT NULL, # FK seq_member.seq_member_id
      root_id                   INT(10) UNSIGNED NOT NULL,
      evalue                    float,
      score                     float,
      bias                      float,

      PRIMARY KEY (root_id,seq_member_id),
      KEY (seq_member_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'seq_member_id_current_reused_map' (DEPRECATED)
--
-- overview: Add new table to be used by copy_trees_from_previous_release in order to
--           rename old seq_member_ids with the current ones.
-- semantics:
--   stable_id              - EnsEMBL stable ID or external ID (for Uniprot/SWISSPROT and Uniprot/SPTREMBL)
--   seq_member_id_reused   - seq_member_id for the reused database containing the previous stable_id
--   seq_member_id_current  - seq_member_id for the current database containing the previous stable_id

CREATE TABLE `seq_member_id_current_reused_map` (
  stable_id                 varchar(128) NOT NULL, # e.g. ENSP000001234 or P31946
  seq_member_id_reused      int(10) unsigned NOT NULL,
  seq_member_id_current     int(10) unsigned NOT NULL,

  FOREIGN KEY (seq_member_id_current) REFERENCES seq_member(seq_member_id),

  PRIMARY KEY (stable_id)

) COLLATE=latin1_swedish_ci ENGINE=InnoDB;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'id_generator'
--
-- overview: table to mimic AUTO_INCREMENT without having to insert rows in
--           the actual data table.
-- semantics:
--   label      - A string identifying the request type, e.g. "homology", "gene_tree", etc
--   next_id    - The next value a dbID column of that type will use

CREATE TABLE id_generator (
    label       VARCHAR(40) NOT NULL,
    next_id     BIGINT UNSIGNED NOT NULL,

    PRIMARY KEY (label)
) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'id_assignments'
--
-- overview: table to record the ids that have been assigned through the
--           id_generator table. Each request yields an interval
--           [assigned_id, assigned_id+size-1]
-- semantics:
--   label          - A string identifying the request type, e.g. "homology", "gene_tree", etc
--   requestor      - A numeric identifier of the what/who made the request
--   assigned_id    - The lowest ID assigned to it
--   size           - The number of IDs assigned to this requestor

CREATE TABLE id_assignments (
    label       VARCHAR(40) NOT NULL,
    requestor   BIGINT UNSIGNED NOT NULL,
    assigned_id BIGINT UNSIGNED NOT NULL,
    size        INT UNSIGNED NOT NULL,

    PRIMARY KEY (label, requestor)
) COLLATE=latin1_swedish_ci ENGINE=InnoDB;

