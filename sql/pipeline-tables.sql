
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

 UNIQUE (gene_member_id, peptide_member_id),
 KEY(peptide_member_id),
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
  KEY hmember_id  (hmember_id),
  KEY hmember_qgenome  (hmember_id, qgenome_db_id),
  KEY qmember_hgenome  (qmember_id, hgenome_db_id),
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

  analysis_id                 int(10) unsigned NOT NULL auto_increment,
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

