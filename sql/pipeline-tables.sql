
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
);


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
);


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'dnafrag_chunk'
--
-- overview: This tables holds chunking information so that these
--           DNA chunks can be identified (stable_id) and cached
--
-- semantics:
--   dnafrag_chunk_id - primary key
--   dnafrag_id       - foreign key link to dnafrag table
--   stable_id        - unique string identifying chunk (to be used to
--                      extract this sequence from a flat file)
--                      (ie subset.dump_loc file linked via subset_dnafrag_chunk)
--   seq_start        - start offset in dnafrag
--   seq_end          - end offset in dnafrag
--   sequence_id      - optional use (store chunk sequence in DB)
                       
CREATE TABLE dnafrag_chunk (
  dnafrag_chunk_id           int(10) NOT NULL auto_increment,
  dnafrag_id                 int(10) NOT NULL DEFAULT 0,
  seq_start                  int(10) unsigned NOT NULL DEFAULT 0,
  seq_end                    int(10) unsigned NOT NULL DEFAULT 0,
  masking_analysis_data_id   int(10) NOT NULL DEFAULT 0,
  sequence_id                int(10) NOT NULL DEFAULT 0,

  PRIMARY KEY (dnafrag_chunk_id),
  UNIQUE KEY uniq_chunk (dnafrag_id, seq_start, seq_end, masking_analysis_data_id),
  KEY (sequence_id)
) ENGINE=InnoDB;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'dnafrag_chunk_set'
--
-- overview: This tables holds sets of dnafrag_chunk references
--
-- semantics:
--   subset_id        - foreign key link to subset table
--   dnafrag_chunk_id - foreign key link to dnafrag_chunk table

CREATE TABLE dnafrag_chunk_set (
 subset_id          int(10) NOT NULL,
 dnafrag_chunk_id   int(10) NOT NULL,

 UNIQUE(subset_id, dnafrag_chunk_id)
) ENGINE=InnoDB;


-- ----------------------------------------------------------------------------------
--
-- Table structure for table 'dna_collection'
--
-- overview: ObjectOriented database table design where join logic is encapsulated in 
--           object adaptor not in table schema.
--           This table holds links to variable foreign dna related tables.
--           This allows for the system to create various dnafrag_chunk and
--           dnafrag_chunk_set objects and then to be able to regroup them in
--           any arbirary way.  This allows for the a chunk to be in multiple sets
--           and in multiple collections, and for collections to include both chunks
--           and sets of chunks. Object design allow system to adapt to design changes
--           without needing to alter database schema.
--
-- semantics:
--   dna_collection_id   - foreign key link to subset table, unique for a collection
--                         uses subset table to generate unique ids.
--   table_name          - name of table on which to join the foreign_id to
--   foreign_id          - foreign key link to <table_name> table

CREATE TABLE dna_collection (
 dna_collection_id      int(10) NOT NULL,
 table_name             varchar(80),
 foreign_id             int(10) NOT NULL,
 
 FOREIGN KEY (dna_collection_id) REFERENCES subset(subset_id),

 UNIQUE(dna_collection_id, table_name, foreign_id)
) ENGINE=MyISAM;


CREATE TABLE genomic_align_block_job_track (
  genomic_align_block_id  bigint unsigned NOT NULL,
  analysis_job_id         int NOT NULL,

  UNIQUE (genomic_align_block_id, analysis_job_id)
);

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
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


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
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


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
-- This is a temporary table used by genetree pipeline as a template for partitioned species-specific peptide_align_features
--

CREATE TABLE peptide_align_feature_prod (

  peptide_align_feature_id    int(10) unsigned NOT NULL auto_increment, # unique internal id
  qmember_id                  int(10) unsigned NOT NULL, # FK member.member_id
  hmember_id                  int(10) unsigned NOT NULL, # FK member.member_id
  qgenome_db_id               int(10) unsigned NOT NULL, # FK genome.genome_id
  hgenome_db_id               int(10) unsigned NOT NULL, # FK genome.genome_id
  analysis_id                 int(10) unsigned NOT NULL, # FK analysis.analysis_id
  qstart                      int(10) DEFAULT 0 NOT NULL,
  qend                        int(10) DEFAULT 0 NOT NULL,
  hstart                      int(11) DEFAULT 0 NOT NULL,
  hend                        int(11) DEFAULT 0 NOT NULL,
  score                       double(16,4) DEFAULT 0.0000 NOT NULL,
  evalue                      double,
  align_length                int(10),
  identical_matches           int(10),
  perc_ident                  int(10),
  positive_matches            int(10),
  perc_pos                    int(10),
  hit_rank                    int(10),
  cigar_line                  mediumtext,

#   FOREIGN KEY (qmember_id) REFERENCES member(member_id),
#   FOREIGN KEY (hmember_id) REFERENCES member(member_id),
#   FOREIGN KEY (qgenome_db_id) REFERENCES genome_db(genome_db_id),
#   FOREIGN KEY (hgenome_db_id) REFERENCES genome_db(genome_db_id),
#   FOREIGN KEY (analysis_id) REFERENCES analysis(analysis_id),

  PRIMARY KEY (peptide_align_feature_id)
) MAX_ROWS = 300000000 AVG_ROW_LENGTH = 133 COLLATE=latin1_swedish_ci PARTITION BY LINEAR HASH(peptide_align_feature_id) PARTITIONS 50;

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

--
-- method_id as primary key (auto-incremented)
-- name is an arbitrary name
-- options are the options used to run the method
-- DROP TABLE IF EXISTS alignment_method
-- CREATE TABLE alignment_method (
--        alignment_method_id    int(10) unsigned NOT NULL AUTO_INCREMENT,
--        name                   varchar(100) NOT NULL,
--        options                varchar(255),

-- PRIMARY KEY (alignment_method_id),
-- UNIQUE KEY (name)
-- ) ENGINE=InnoDB;

-- DROP TABLE IF EXISTS alignment
-- CREATE TABLE alignment (
--        alignment_id    int(10) unsigned NOT NULL AUTO_INCREMENT,
--        compara_table   ENUM('compara','ncrna') NOT NULL,
--        compara_key     int(10) unsigned NOT NULL,
--        alignment_method_id       int(10) unsigned NOT NULL,

-- PRIMARY KEY (alignment_id),
-- FOREIGN KEY (alignment_method_id) REFERENCES alignment_method(alignment_method_id)
-- ) ENGINE=InnoDB;


-- DROP TABLE IF EXISTS aligned_sequence
-- CREATE TABLE aligned_sequence (
--        alignment_id           int(10) unsigned NOT NULL,
--        aligned_seq_id         int(10) unsigned NOT NULL AUTO_INCREMENT,
--        aligned_length         int(10) NOT NULL,
--        sequence_id            int(10) unsigned,
--        member_id              int(10) unsigned,
--        aligned_sequence       mediumtext,

-- PRIMARY KEY (aligned_seq_id),
-- FOREIGN KEY (alignment_id) REFERENCES alignment(alignment_id),
-- FOREIGN KEY (sequence_id) REFERENCES sequence(sequence_id),
-- FOREIGN KEY (member_id) REFERENCES member(member_id)
-- ) ENGINE=InnoDB;

