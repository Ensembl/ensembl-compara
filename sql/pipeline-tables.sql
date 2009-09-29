
CREATE TABLE subset (
 subset_id      int(10) NOT NULL auto_increment,
 description    varchar(255),
 dump_loc       varchar(255),

 PRIMARY KEY (subset_id),
 UNIQUE (description)
);

CREATE TABLE subset_member (
 subset_id   int(10) NOT NULL,
 member_id   int(10) NOT NULL,

 UNIQUE subset_member_id (subset_id, member_id)
);



------------------------------------------------------------------------------------
--
-- Table structure for table 'genome_db_extn'
--
-- semantics:
-- genome_db_id - foreign key to genome_db table
-- phylum       - string to identify homology groupings
-- dblocator    - string to identify location of the external genome database (or file).

CREATE TABLE genome_db_extn (
  genome_db_id                int(10) DEFAULT '0' NOT NULL,
  phylum                      varchar(40) DEFAULT '' NOT NULL,
  locator                     mediumtext,

  UNIQUE KEY genome_db_id  (genome_db_id)
);


------------------------------------------------------------------------------------
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
    genome_db_id    int(10) NOT NULL default '0',
    data_type       varchar(20) NOT NULL,
    count           int(10) NOT NULL,
    mean            double NOT NULL default '0',
    median          double NOT NULL default '0',
    mode            double NOT NULL,
    stddev          double NOT NULL,
    variance        double NOT NULL,
    min             double NOT NULL default '0',
    max             double NOT NULL default '0',
    overlap_count   int(10) NOT NULL default '0',

    UNIQUE KEY genome_db_id_type (genome_db_id, data_type)
);



------------------------------------------------------------------------------------
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
  dnafrag_id                 int(10) NOT NULL DEFAULT '0',
  seq_start                  int(10) unsigned NOT NULL DEFAULT '0',
  seq_end                    int(10) unsigned NOT NULL DEFAULT '0',
  masking_analysis_data_id   int(10) NOT NULL DEFAULT '0',
  sequence_id                int(10) NOT NULL DEFAULT '0',

  PRIMARY KEY (dnafrag_chunk_id),
  UNIQUE KEY uniq_chunk (dnafrag_id, seq_start, seq_end, masking_analysis_data_id),
  KEY (sequence_id)
) ENGINE=InnoDB;


------------------------------------------------------------------------------------
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


------------------------------------------------------------------------------------
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
);


CREATE TABLE genomic_align_block_job_track (
  genomic_align_block_id  bigint unsigned NOT NULL,
  analysis_job_id         int NOT NULL,

  UNIQUE (genomic_align_block_id, analysis_job_id)
);

------------------------------------------------------------------------------------
--
-- Table structure for table 'anchor_sequence'
--
-- This table stores anchor sequences and associated information
--


CREATE TABLE `anchor_sequence` (
  `anchor_seq_id` int(20) unsigned NOT NULL auto_increment,
  `method_link_species_set_id` int(10) unsigned default NULL,
  `test_mlssID` int(10) unsigned default NULL,
  `anchor_id` int(20) unsigned default NULL,
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
  `anchor_align_id` int(20) unsigned NOT NULL auto_increment,
  `method_link_species_set_id` int(10) unsigned default NULL,
  `anchor_id` int(20) unsigned default NULL,
  `dnafrag_id` int(20) unsigned default NULL,
  `dnafrag_start` int(20) default NULL,
  `dnafrag_end` int(20) default NULL,
  `dnafrag_strand` tinyint(4) default NULL,
  `score` float default NULL,
  `num_of_organisms` smallint(5) unsigned default NULL,
  `num_of_sequences` smallint(5) unsigned default NULL,
  `anchor_status` int(10) default NULL,
  PRIMARY KEY  (`anchor_align_id`),
  KEY `anchor_id_mlss_id` (`anchor_id`,`method_link_species_set_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

