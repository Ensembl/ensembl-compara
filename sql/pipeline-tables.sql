
-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'genome_db_extn'
--
-- semantics:
-- genome_db_id - foreign key to genome_db table
-- phylum       - string to identify homology groupings
-- dblocator    - string to identify location of the external genome database (or file).

CREATE TABLE genome_db_extn (
  genome_db_id                int(10) DEFAULT 0 NOT NULL,
  phylum                      varchar(40) DEFAULT '' NOT NULL,
  locator                     mediumtext,

  UNIQUE KEY genome_db_id  (genome_db_id)
) ENGINE=InnoDB;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'genome_db_stats'
--
-- overview: This tables statistics related to whole genomes
--           The type of data analyzed is described in the 'data_type' field
-- semantics:
--   genome_db_id - link to genome_db table id
--   data_type    - descriptor of type e.g. intergenic
--   (rest of columns are standard statistical values calculated from the
--    dataset defined by 'data_type')

CREATE TABLE genome_db_stats (
    genome_db_id    int(10) NOT NULL default 0,
    data_type       varchar(20) NOT NULL,
    count           int(10) NOT NULL,
    mean            double NOT NULL default 0,
    median          double NOT NULL default 0,
    mode            double NOT NULL,
    stddev          double NOT NULL,
    variance        double NOT NULL,
    min             double NOT NULL default 0,
    max             double NOT NULL default 0,
    overlap_count   int(10) NOT NULL default 0,

    UNIQUE KEY genome_db_id_type (genome_db_id, data_type)
) ENGINE=InnoDB;


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

DROP TABLE IF EXISTS removed_member; 
CREATE TABLE removed_member (
  removed_id  int(10) unsigned NOT NULL AUTO_INCREMENT,
  node_id int(10) unsigned NOT NULL,
  stable_id varchar(128) NOT NULL,
  genome_db_id int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (removed_id),
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
       fam_id                 VARCHAR(20) NOT NULL,
       tree                   mediumtext NOT NULL,
       tabledata              mediumtext NOT NULL,

PRIMARY KEY (fam_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'protein_tree_qc'
--
-- overview: This table contains statistics related to the protein trees
-- semantics:
--   genome_db_id  - link to genome_db table id
--   total_orphans_num   - number of orphaned genes (not in the set)
--   prop_orphans        - proportion of orphaned genes, compared to the whole set
--   common_orphans_num  - number of still orphaned genes (only if the species is reused)
--   new_orphans_num     - number of new orphaned genes (only if the species is reused)


CREATE TABLE protein_tree_qc (
    genome_db_id                       int(10) unsigned NOT NULL,

    total_orphans_num                  INT UNSIGNED,
    prop_orphans                       DOUBLE,
    common_orphans_num                 INT UNSIGNED,
    new_orphans_num                    INT UNSIGNED,

    PRIMARY KEY (genome_db_id),
    FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id)

) ENGINE=InnoDB DEFAULT CHARSET=latin1;



CREATE TABLE split_genes (
	member_id   	int(10) unsigned UNIQUE NOT NULL,
	gene_split_id	int(10) unsigned NOT NULL AUTO_INCREMENT,

	PRIMARY KEY (member_id),
	KEY gene_split_id (gene_split_id),

	FOREIGN KEY member_id (member_id) REFERENCES member (member_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

