
CREATE TABLE subset (
 subset_id      int(10) NOT NULL auto_increment,
 description    varchar(50),
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
  KEY (sequence_id)
);

CREATE TABLE subset_dnafrag_chunk (
 subset_id          int(10) NOT NULL,
 dnafrag_chunk_id   int(10) NOT NULL,

 UNIQUE(subset_id, dnafrag_chunk_id)
);

