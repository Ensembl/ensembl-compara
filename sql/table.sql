# conventions taken from the new clean scheam of EnsEMBL
# use lower case and underscores
# internal ids are integers named tablename_id
# same name is given in foreign key relations

#
# Table structure for table 'dnafrag'
#
-- Index <name> has genome_db_id in the first place because unless fetching all danfrags
--   or fetching by dnafrag_id, genome_db_id appears always in the WHERE clause
-- Unique key <name> is used to ensure that
--   Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor->fetch_by_GenomeDB_and_name
--   will always fetch a single row. This can be used in the EnsEMBL Compara DB
--   because we store top-level dnafrags only.

CREATE TABLE dnafrag (
  dnafrag_id int(10) NOT NULL auto_increment,
  length int(11) DEFAULT '0' NOT NULL,
  name varchar(40) DEFAULT '' NOT NULL,
  genome_db_id int(10) DEFAULT '0' NOT NULL,
  coord_system_name varchar(40) DEFAULT NULL,

  PRIMARY KEY (dnafrag_id),
  UNIQUE name (genome_db_id, name)
);

#
# Table structure for table 'dnafrag_region'
#

CREATE TABLE dnafrag_region (
  synteny_region_id int(10) DEFAULT '0' NOT NULL,
  dnafrag_id int(10) DEFAULT '0' NOT NULL,
  seq_start int(10) unsigned DEFAULT '0' NOT NULL,
  seq_end int(10) unsigned DEFAULT '0' NOT NULL,
  
  UNIQUE unique_synteny (synteny_region_id,dnafrag_id),
  UNIQUE unique_synteny_reversed (dnafrag_id,synteny_region_id)
);

#
# Table structure for table 'genome_db'
#

CREATE TABLE genome_db (
  genome_db_id      int(10) NOT NULL auto_increment,
  taxon_id          int(10) DEFAULT '0' NOT NULL,
  name              varchar(40) DEFAULT '' NOT NULL,
  assembly          varchar(100) DEFAULT '' NOT NULL,
  assembly_default  tinyint(1) DEFAULT 1,
  genebuild         varchar(100) DEFAULT '' NOT NULL,
  locator           varchar(255),

  PRIMARY KEY (genome_db_id),
  UNIQUE name (name,assembly,genebuild)
);

#
# Table structure for table 'genomic_align_block'
#
#    This table indexes the genomic alignments
#

CREATE TABLE genomic_align_block (
  genomic_align_block_id int(10) NOT NULL AUTO_INCREMENT,
  method_link_species_set_id int(10) DEFAULT '0' NOT NULL,
  score double,
  perc_id int(10) DEFAULT NULL,
  length int(10),

  PRIMARY KEY genomic_align_block_id (genomic_align_block_id),
  KEY method_link_species_set (genomic_align_block_id, method_link_species_set_id)
);

#
# Table structure for table 'genomic_align'
# 
#   This table stores the sequences belonging to the same genomic_align_block entry
#

CREATE TABLE genomic_align (
  genomic_align_id int(10) NOT NULL AUTO_INCREMENT,
  genomic_align_block_id int(10) NOT NULL,
  method_link_species_set_id int(10) DEFAULT '0' NOT NULL,
  dnafrag_id int(10) DEFAULT '0' NOT NULL,
  dnafrag_start int(10) DEFAULT '0' NOT NULL,
  dnafrag_end int(10) DEFAULT '0' NOT NULL,
  dnafrag_strand tinyint(4) DEFAULT '0' NOT NULL,
  cigar_line mediumtext,
  level_id int(10) DEFAULT '0' NOT NULL,

  PRIMARY KEY genomic_align_id (genomic_align_id),
  KEY genomic_align_block_id (genomic_align_block_id),
  KEY dnafrag_id (dnafrag_id, dnafrag_start, dnafrag_start),
  KEY dnafrag_id2 (dnafrag_id, method_link_species_set_id, dnafrag_start, dnafrag_end)
);

#
# Table structure for table 'genomic_align_group'
# 
#   This table can store several groupings of the genomic aligned sequences
#

CREATE TABLE genomic_align_group (
  group_id int(10) NOT NULL AUTO_INCREMENT,
  type varchar(40) NOT NULL,
  genomic_align_id int(10) NOT NULL,

  KEY group_id (group_id),
  KEY genomic_align_id (genomic_align_id, type)
);

-- #
-- # Table structure for table 'genomic_align_genome'
-- #
-- 
-- CREATE TABLE genomic_align_genome (
--   consensus_genome_db_id int(11) DEFAULT '0' NOT NULL,
--   query_genome_db_id int(11) DEFAULT '0' NOT NULL,
--   method_link_id int(10) DEFAULT '0' NOT NULL
-- );

# method_link table specifies which kind of link can exist between species
# (dna/dna alignment, synteny regions, homologous gene pairs,...)

#
# Table structure for table 'method_link'
#

CREATE TABLE method_link (
  method_link_id int(10) NOT NULL auto_increment,
  type varchar(50) DEFAULT '' NOT NULL,
  
  PRIMARY KEY (method_link_id),
  KEY type (type)
);

# method_link_species table specifying which species are part of a 
# method_link_id

#
# Table structure for table 'method_link_species_set'
#
-- method_link_species_set_id is a multiple key. It defines a set of species
--   (genome_db_ids) linked through a method_link_id. 

CREATE TABLE method_link_species_set (
  method_link_species_set_id int(10) NOT NULL AUTO_INCREMENT,
  method_link_id int(10),
  genome_db_id int(10),

  KEY method_link_species_set (method_link_species_set_id),
  KEY method_link_id (method_link_id, method_link_species_set_id, genome_db_id)
);

#
# We have now decided that Synteny is inherently pairwise
# these tables hold the pairwise information for the synteny
# regions. We reuse the dnafrag table as a link out for identifiers
# (eg, '2' on mouse).
#

#
# Table structure for table 'synteny_region'
#

CREATE TABLE synteny_region (
  synteny_region_id int(10) NOT NULL auto_increment,
  rel_orientation tinyint(1) DEFAULT '1' NOT NULL,
  PRIMARY KEY (synteny_region_id)
);


#
# This table stores meta information about the compara database
#
CREATE TABLE meta (
    meta_id INT not null auto_increment,
    meta_key varchar( 40 ) not null,
    meta_value varchar( 255 ) not null,

    PRIMARY KEY( meta_id ),
    KEY meta_key_index ( meta_key ),
    KEY meta_value_index ( meta_value )
);

#CREATE TABLE source (
# source_id	int(10) NOT NULL auto_increment,
# source_name	varchar(40) NOT NULL,
#
# PRIMARY KEY (source_id),
# UNIQUE KEY (source_name)
#);

CREATE TABLE taxon (
 taxon_id         int(10) NOT NULL,
 genus            varchar(50),
 species          varchar(50),
 sub_species      varchar(50),
 common_name      varchar(100),
 classification   mediumtext,

 PRIMARY KEY (taxon_id),
 KEY (genus,species),
 KEY (common_name)
);

CREATE TABLE member (
 member_id      int(10) NOT NULL auto_increment,
 stable_id      varchar(40) NOT NULL, # e.g. ENSP000001234 or P31946
 version        int(10) DEFAULT '0', 
# source_id      int(10) NOT NULL, # foreign key from source table
 source_name	varchar(40) NOT NULL,
 taxon_id       int(10) NOT NULL, # foreign key from taxon table
 genome_db_id   int(10), # foreign key from genome_db table
 sequence_id    int(10), # foreign key from sequence table
 description    varchar(255),
 chr_name       char(40),
 chr_start      int(10),
 chr_end        int(10),
 chr_strand     tinyint(1) NOT NULL,

 PRIMARY KEY (member_id),
 UNIQUE KEY (stable_id, source_name),
 KEY (sequence_id)
);

CREATE TABLE sequence (
 sequence_id    int(10) NOT NULL auto_increment,
 sequence       mediumtext NOT NULL,
 length         int(10) NOT NULL,

 PRIMARY KEY (sequence_id)
);


CREATE TABLE family (
 family_id		int(10) NOT NULL auto_increment,
 stable_id		varchar(40) NOT NULL, # e.g. ENSF0000012345
# source_id              int(10) NOT NULL, # foreign key from source table
 method_link_species_set_id int(10) NOT NULL,
 description		varchar(255),
 description_score	double,

 PRIMARY KEY (family_id), 
 UNIQUE KEY (stable_id),
 KEY (method_link_species_set_id),
 KEY (description)
);

CREATE TABLE family_member (
 family_id	int(10) NOT NULL, # foreign key from family table
 member_id	int(10) NOT NULL, # foreign key from member table
 cigar_line	mediumtext,
 
 UNIQUE KEY (family_id,member_id),
 UNIQUE KEY (member_id,family_id)
);


CREATE TABLE domain (
 domain_id	int(10) NOT NULL auto_increment,
 stable_id      varchar(40) NOT NULL,
# source_id	int(10) NOT NULL,
 method_link_species_set_id int(10) NOT NULL,
 description	varchar(255),

 PRIMARY KEY (domain_id),
 UNIQUE KEY (stable_id, method_link_species_set_id)
);

CREATE TABLE domain_member (
 domain_id	int(10) NOT NULL,
 member_id	int(10) NOT NULL,
 member_start	int(10),
 member_end	int(10),

 UNIQUE KEY (domain_id,member_id,member_start,member_end),
 UNIQUE KEY (member_id,domain_id,member_start,member_end)
);

CREATE TABLE homology (
 homology_id	int(10) NOT NULL auto_increment,
 stable_id      varchar(40),
# source_id      int(10) NOT NULL, # foreign key from source table
 method_link_species_set_id int(10) NOT NULL,
 description    varchar(40), # UBRH, MBRH, RHS
 subtype        varchar(40) NOT NULL DEFAULT '',
 dn             float(10,5),
 ds             float(10,5),
 n              float(10,1),
 s              float(10,1),
 lnl            float(10,3),
 threshold_on_ds float(10,5),

 PRIMARY KEY (homology_id),
 KEY (method_link_species_set_id)
);

CREATE TABLE homology_member (
 homology_id               int(10) NOT NULL,
 member_id                 int(10) NOT NULL,
 peptide_member_id         int(10),
 peptide_align_feature_id  int(10),
 cigar_line                mediumtext,
 cigar_start               int(10),
 cigar_end                 int(10),
 perc_cov                  int(10),
 perc_id                   int(10),
 perc_pos                  int(10),

 UNIQUE KEY (member_id,homology_id),
 UNIQUE KEY (homology_id,member_id)
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
  KEY qmember_hgenome  (qmember_id, hgenome_db_id)
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

