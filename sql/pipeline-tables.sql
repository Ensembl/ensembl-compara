
CREATE TABLE subset (
 subset_id      int(10) NOT NULL auto_increment,
 description    varchar(50),
 dump_loc       varchar(255),

 PRIMARY KEY (subset_id)
);

CREATE TABLE subset_member (
 subset_id   int(10) NOT NULL,
 member_id   int(10) NOT NULL,

 KEY(subset_id),
 KEY(member_id)
);


# table identifies the relationship of which gene member, each
# peptide member is derived from
CREATE TABLE member_gene_peptide(
 gene_member_id       int(10) NOT NULL,
 peptide_member_id    int(10) NOT NULL,

 KEY(gene_member_id),
 KEY(peptide_member_id)
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
-- Table structure for table 'peptide_align_feature'
--
-- overview: This tables stores the raw HSP local alignment results
--           of peptide to peptide alignments returned by a BLAST run
--           it is translated from a FeaturePair object
-- semantics:
-- peptide_align_feature_id  - internal id
-- qmember_id                - member.member_id of query peptide
-- hmember_id                - member.member_id of hit peptide
-- qgenome_db_id             - genome_db_id of query peptide (for query optimization)
-- hgenome_db_id             - genome_db_id of hit peptide (for query optimization)
-- qstart                    - start pos in query peptide sequence
-- qend                      - end  pos in query peptide sequence
-- hstart                    - start pos in hit peptide sequence
-- hend                      - end  pos in hit peptide sequence
-- score                     - blast score for this HSP
-- evalue                    - blast evalue for this HSP
-- align_length              - alignment length of HSP
-- identical_matches         - blast HSP match score
-- positive_matches          - blast HSP positive score
-- perc_ident                - percent identical matches in the HSP length
-- perc_pos                  - precent positive matches in the HSP length
-- cigar_line                - cigar string coding the actual alignment

CREATE TABLE peptide_align_feature (

  peptide_align_feature_id  int(10) unsigned NOT NULL auto_increment,
  qmember_id                int(10) NOT NULL,
  hmember_id                int(10) NOT NULL,
  qgenome_db_id             int(10) NOT NULL,
  hgenome_db_id             int(10) NOT NULL,
  analysis_id               int(10) NOT NULL,
  qstart                    int(10) DEFAULT '0' NOT NULL,
  qend                      int(10) DEFAULT '0' NOT NULL,
  hstart                    int(11) DEFAULT '0' NOT NULL,
  hend                      int(11) DEFAULT '0' NOT NULL,
  score                     double(16,4) DEFAULT '0.0000' NOT NULL,
  evalue                    varchar(20),
  align_length              int(10),
  identical_matches         int(10),
  perc_ident                int(10),
  positive_matches          int(10),
  perc_pos                  int(10),
  hit_rank                  int(10),
  cigar_line                mediumtext,

  PRIMARY KEY (peptide_align_feature_id),
  KEY qmember_id  (qmember_id),
  KEY hmember_id  (hmember_id)

);


------------------------------------------------------------------------------------
--
-- Table structure for table 'analysis'
--
-- semantics:
-- analysis_id - internal id
-- created   - date to distinguish newer and older versions off the
--             same analysis. Not well maintained so far.
-- logic_name  string to identify the analysis. Used mainly inside pipeline.
-- db, db_version, db_file
--  - db should be a database name, db version the version of that db
--    db_file the file system location of that database,
--    probably wiser to generate from just db and configurations
-- program, program_version,program_file
--  - The binary used to create a feature. Similar semantic to above
-- module, module_version
--  - Perl module names (RunnableDBS usually) executing this analysis.
-- parameters a paramter string which is processed by the perl module
-- gff_source, gff_feature
--  - how to make a gff dump from features with this analysis

CREATE TABLE analysis (

  analysis_id                 int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  created                     datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  logic_name                  varchar(40) not null,
  db                          varchar(120),
  db_version                  varchar(40),
  db_file                     varchar(120),
  program                     varchar(80),
  program_version             varchar(40),
  program_file                varchar(80),
  parameters                  varchar(255),
  module                      varchar(80),
  module_version              varchar(40),
  gff_source                  varchar(40),
  gff_feature                 varchar(40),

  PRIMARY KEY (analysis_id),
  KEY logic_name_idx( logic_name ),
  UNIQUE(logic_name)

);

create table hive (
  hive_id          int(10) NOT NULL auto_increment,
  analysis_id      int(10) NOT NULL,
  host	           varchar(40) DEFAULT '' NOT NULL,
  process_id       int(10) NOT NULL,
  work_done        int(11) DEFAULT '0' NOT NULL,
  born	           datetime NOT NULL,
  last_check_in    datetime NOT NULL,
  died             datetime DEFAULT NULL,
  cause_of_death   enum('', 'NATURAL', 'NO_WORK', 'UNKNOWN') default '' NOT NULL,
  PRIMARY KEY (hive_id),
);

------------------------------------------------------------------------------------
--
-- Table structure for table 'simple_rule'
--
-- overview:
--   redesign of pipeline rule system.  Basic design is simplifed so that a
--   'rule' is simply a link from one analysis object to another
--     (ie an edge in a flowchart or object interaction diagram where
--      condition_analysis_id => goal_analysis_id)
--   Each analysis object (analysis_id) is a unique node in the
--   graph that describes the pipeline system.
--     (ie each analysis_id is an 'Instance' of the module it points to)
--   Main reason for redesign that by making a single table we can implement
--   a UNIQUE constraint so that the pipeline can modify itself as it runs
--   and avoid race conditions where the same link is created multiple times
--
-- semantics:
--   simple_rule_id           - internal ID
--   condition_analysis_id    - foreign key to analysis table analysis_id
--   goal_analysis_id         - foreign key to analysis table analysis_id

CREATE TABLE simple_rule (
  simple_rule_id           int(10) unsigned default '0' not null auto_increment,
  condition_analysis_id    int(10) unsigned NOT NULL,
  goal_analysis_id         int(10) unsigned NOT NULL,

  PRIMARY KEY (simple_rule_id),
  UNIQUE (condition_analysis_id, goal_analysis_id)
);



CREATE TABLE analysis_job (
  analysis_job_id        int(10) NOT NULL auto_increment,
  input_analysis_job_id  int(10) NOT NULL,  #analysis_job which created this from rules
  analysis_id            int(10) NOT NULL,
  input_id               varchar(100) not null,
  job_claim              varchar(40) DEFAULT NULL, #UUID
  hive_id                int(10) NOT NULL,
  status                 enum('CREATED', 'GET_INPUT', 'RUN', 'WRITE_OUTPUT', 'DONE') DEFAULT 'CREATED' NOT NULL,
  retry_count            int(10) not NULL default '0',
  completed              datetime NOT NULL,
  result                 smallint(10) unsigned NOT NULL,

  PRIMARY KEY       (analysis_job_id),
  UNIQUE KEY        (analysis_id, input_id)
);


CREATE TABLE job_files (
  analysis_job_id     int(10) NOT NULL,
  stdout_file         varchar(255) NOT NULL,
  stderr_file         varchar(255) NOT NULL,
  temp_dir            varchar(255) DEFAULT ''
);

