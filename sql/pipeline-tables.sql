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
--   seq_start            - start offset in dnafrag
--   seq_end              - end offset in dnafrag
--   sequence_id          - optional use (store chunk sequence in DB)
                       
CREATE TABLE dnafrag_chunk (
  dnafrag_chunk_id           int(10) NOT NULL auto_increment,
  dnafrag_chunk_set_id       int(10) NOT NULL,
  dnafrag_id                 int(10) NOT NULL DEFAULT 0,
  seq_start                  int(10) unsigned NOT NULL DEFAULT 0,
  seq_end                    int(10) unsigned NOT NULL DEFAULT 0,
  sequence_id                int(10) NOT NULL DEFAULT 0,

  PRIMARY KEY (dnafrag_chunk_id),
  UNIQUE KEY uniq_chunk (dnafrag_chunk_set_id, dnafrag_id, seq_start, seq_end),
  KEY sequence_id (sequence_id)
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
--           the underlying dnafrag_chunks ie dump_loc and masking_options. The description field is a unique
--           identifier and is used to retrieve a specific dna_collection since this is known prior
--           to storage.
-- semantics:
--   dna_collection_id   - primary key
--   description         - unique description of collection 
--   dump_loc            - directory path to dump files
--   masking_options     - masking options

CREATE TABLE dna_collection (
 dna_collection_id       int(10) NOT NULL auto_increment,
 description             varchar(255),
 dump_loc                varchar(255),
 masking_options         mediumtext,

 PRIMARY KEY (dna_collection_id),
 UNIQUE (description)
 
) ENGINE=InnoDB;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'anchor_sequence'
--
-- This table stores anchor sequences and associated information
--


CREATE TABLE `anchor_sequence` (
  `anchor_seq_id` bigint(20) unsigned NOT NULL auto_increment,
  `method_link_species_set_id` int(10) unsigned default NULL,
  `anchor_id` bigint(20) unsigned default NULL,
  `dnafrag_id` int(20) unsigned default NULL,
  `start` int(20) unsigned default NULL,
  `end` int(20) unsigned default NULL,
  `strand` tinyint(4) default '0',
  `sequence` varchar(250) default '',
  `length` int(20) unsigned default NULL,
  PRIMARY KEY  (`anchor_seq_id`),
  KEY `anchor_id_mlss_id` (`anchor_id`, `method_link_species_set_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


--
-- Table structure for table 'anchor_align'
--
-- This table stores anchor information after they have been mapped (exonerated) to target genomes 
--


CREATE TABLE `anchor_align` (
  `anchor_align_id` bigint(20) unsigned NOT NULL auto_increment,
  `method_link_species_set_id` int(10) unsigned default NULL,
  `anchor_id` bigint(20) unsigned default NULL,
  `dnafrag_id` int(20) unsigned default NULL,
  `dnafrag_start` int(20) default NULL,
  `dnafrag_end` int(20) default NULL,
  `dnafrag_strand` tinyint(4) default NULL,
  `score` float default NULL,
  `num_of_organisms` smallint(5) unsigned default NULL,
  `num_of_sequences` smallint(5) unsigned default NULL,
  `evalue` varchar(10) default NULL,
  `anchor_status` int(10) default NULL,
  PRIMARY KEY  (`anchor_align_id`),
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
    PRIMARY KEY (`row_id`,`column_id`),
    KEY `row_id` (`row_id`)
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
  tag varchar(50) DEFAULT NULL,
  k_score_rank int(10) default NULL,
  k_score float(10,5) DEFAULT NULL,
  scale_factor float(10,5) DEFAULT NULL,
  symm_difference int(10) unsigned DEFAULT NULL,
  n_partitions int(10) unsigned DEFAULT NULL,
  UNIQUE KEY tag_node_id (node_id,tag),
  KEY node_id (node_id),
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

DROP TABLE IF EXISTS cmsearch_hit; 
CREATE TABLE cmsearch_hit (
  hit_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  recovered_id int(10) unsigned NOT NULL,
  node_id int(10) unsigned NOT NULL,
  target_start int(10) NOT NULL,
  target_stop  int(10) NOT NULL,
  query_start int(10) NOT NULL,
  query_stop  int(10) NOT NULL,
  bit_sc float(10,5) DEFAULT NULL,
  evalue double DEFAULT NULL,
  PRIMARY KEY (hit_id)
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
	seq_member_id   	int(10) unsigned UNIQUE NOT NULL,
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
	start int(11) NOT NULL,
	end int(11) NOT NULL,
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
      seq_member_id             INT(10) UNSIGNED NOT NULL, # FK homology.homology_id
      root_id                   INT(10) UNSIGNED NOT NULL,
      evalue                    float,
      score                     float,
      bias                      float,

      PRIMARY KEY (root_id,seq_member_id),
      KEY (root_id),
      KEY (seq_member_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


-- ----------------------------------------------------------------------------------
--
-- Table structure for tables 'ortholog_goc_metric'
-- overview: This table contains the full breakdown of what is used to calculate the goc score.

CREATE TABLE IF NOT EXISTS ortholog_goc_metric ( 
  method_link_species_set_id int(10) unsigned NOT NULL,
  homology_id int(10) unsigned NOT NULL,
  gene_member_id int(10) unsigned NOT NULL,
  goc_score TINYINT NOT NULL,
  left1 TINYINT(1),
  left2 TINYINT(1),
  right1 TINYINT(1),
  right2 TINYINT(1),

  PRIMARY KEY (homology_id, gene_member_id),
  
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set (method_link_species_set_id),
  FOREIGN KEY (gene_member_id) REFERENCES gene_member (gene_member_id),
  FOREIGN KEY (homology_id) REFERENCES homology (homology_id)
)  ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ----------------------------------------------------------------------------------
--
-- Table structure for tables 'prev_ortholog_goc_metric'
-- overview: This table contains the full breakdown of what was used to
-- calculate the goc score in the last release. The schema is almost the
-- same as ortholog_goc_metric but we use stable_id instead of gene_member_id

CREATE TABLE IF NOT EXISTS prev_ortholog_goc_metric (
  method_link_species_set_id int(10) unsigned NOT NULL,
  homology_id int(10) unsigned NOT NULL,
  stable_id varchar(128) NOT NULL, # e.g. ENSP000001234 or P31946
  goc_score TINYINT NOT NULL,
  left1 TINYINT(1),
  left2 TINYINT(1),
  right1 TINYINT(1),
  right2 TINYINT(1),

  PRIMARY KEY (homology_id, stable_id),
  KEY (method_link_species_set_id)

)  ENGINE=InnoDB DEFAULT CHARSET=latin1;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'seq_member_id_current_reused_map'
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
-- Table structure for table 'homology_id_mapping'
--
-- overview: Mapping between homology_id in this database and the previous one
--
-- semantics:
--   curr_release_homology_id  - homology_id in this database
--   prev_release_homology_id  - homology_id in the previous database
--   mlss_id                   - method_link_species_set_id of this homology

CREATE TABLE homology_id_mapping (
	curr_release_homology_id  INT UNSIGNED NOT NULL,
	prev_release_homology_id  INT UNSIGNED NOT NULL,
	mlss_id                   INT UNSIGNED NOT NULL,
	PRIMARY KEY (curr_release_homology_id),
	UNIQUE KEY (prev_release_homology_id),
	FOREIGN KEY (mlss_id) REFERENCES method_link_species_set(method_link_species_set_id),
	INDEX (mlss_id)
) ENGINE=InnoDB;

