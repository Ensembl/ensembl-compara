# conventions taken from the new clean scheam of EnsEMBL
# use lower case and underscores
# internal ids are integers named tablename_id
# same name is given in foreign key relations

#
# Table structure for table 'meta'
#
# This table stores meta information about the compara database
#

CREATE TABLE meta (
  meta_id                     int unsigned not null auto_increment, # unique internal id
  meta_key                    varchar(40) not null,
  meta_value                  varchar(255) not null,

  PRIMARY KEY (meta_id),
  KEY meta_key_index (meta_key),
  KEY meta_value_index (meta_value)
);


#
# Table structure for table 'taxon'
#
# Contains all taxa used in this database.
#

CREATE TABLE taxon (
  taxon_id                    int(10) unsigned NOT NULL, # unique internal id
  genus                       varchar(50),
  species                     varchar(50),
  sub_species                 varchar(50),
  common_name                 varchar(100),
  classification              mediumtext,

  PRIMARY KEY (taxon_id),
  KEY (genus,species),
  KEY (common_name)
);


#
# Table structure for table 'genome_db'
#
# Contains information about the version of the genome assemblies used in this database
#

CREATE TABLE genome_db (
  genome_db_id                int(10) unsigned NOT NULL auto_increment, # unique internal id
  taxon_id                    int(10) unsigned DEFAULT '0' NOT NULL, # KF taxon.taxon_id
  name                        varchar(40) DEFAULT '' NOT NULL,
  assembly                    varchar(100) DEFAULT '' NOT NULL,
  assembly_default            tinyint(1) DEFAULT 1,
  genebuild                   varchar(100) DEFAULT '' NOT NULL,
  locator                     varchar(255),

  FOREIGN KEY (taxon_id) REFERENCES taxon(taxon_id),
  PRIMARY KEY (genome_db_id),
  UNIQUE name (name,assembly,genebuild)
);


#
# Table structure for table 'method_link'
#
# Specifies which kind of link can exist between species
# (dna/dna alignment, synteny regions, homologous gene pairs,...)
#

CREATE TABLE method_link (
  method_link_id              int(10) unsigned NOT NULL auto_increment, # unique internal id
  type                        varchar(50) DEFAULT '' NOT NULL,
  
  PRIMARY KEY (method_link_id),
  KEY type (type)
);


#
# Table structure for table 'method_link_species_set'
#
-- KEY method_link_species_set_id is a multiple key. It defines a set of species
--   (genome_db_ids) linked through a method_link_id. 

CREATE TABLE method_link_species_set (
  method_link_species_set_id  int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  method_link_id              int(10) unsigned, # FK method_link.method_link_id
  genome_db_id                int(10) unsigned, # FK genome_db.genome_db_id

  FOREIGN KEY (method_link_id) REFERENCES method_link(method_link_id),
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),

  KEY method_link_species_set (method_link_species_set_id),
  KEY method_link_id (method_link_id, method_link_species_set_id, genome_db_id)
);


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
  dnafrag_id                  int(10) unsigned NOT NULL auto_increment, # unique internal id
  length                      int(11) DEFAULT '0' NOT NULL,
  name                        varchar(40) DEFAULT '' NOT NULL,
  genome_db_id                int(10) unsigned DEFAULT '0' NOT NULL, # FK genome_db.genome_db_id
  coord_system_name           varchar(40) DEFAULT NULL,

  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),

  PRIMARY KEY (dnafrag_id),
  UNIQUE name (genome_db_id, name)
);


#
# Table structure for table 'genomic_align_block'
#
#    This table indexes the genomic alignments
#
-- All queries in the API uses the primary key as rows are always fetched using
--   the genomic_align_block_id. The key "method_link_species_set_id" is used by
--   MART when fetching all the genomic_align_blocks corresponding to a given
--   method_link_species_set_id.z

CREATE TABLE genomic_align_block (
  genomic_align_block_id      bigint unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  method_link_species_set_id  int(10) unsigned DEFAULT '0' NOT NULL, # FK method_link_species_set_id.method_link_species_set_id
  score                       double,
  perc_id                     tinyint(3) unsigned DEFAULT NULL,
  length                      int(10),

  # method_link_species_set(method_link_species_set_id) is not a unique key. Some RDBMS may complain
  # FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY genomic_align_block_id (genomic_align_block_id),
  KEY method_link_species_set_id (method_link_species_set_id)
);


#
# Table structure for table 'genomic_align'
# 
#   This table stores the sequences belonging to the same genomic_align_block entry
#
-- primary key is used when fecthing by dbID
-- key genomic_align_block_id is used when fetching by genomic_align_block_id
-- key dnafrag is used in all other queries

CREATE TABLE genomic_align (
  genomic_align_id            bigint unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  genomic_align_block_id      bigint unsigned NOT NULL, # FK genomic_align_block.genomic_align_block_id
  method_link_species_set_id  int(10) unsigned DEFAULT '0' NOT NULL, # FK method_link_species_set_id.method_link_species_set_id
  dnafrag_id                  int(10) unsigned DEFAULT '0' NOT NULL, # FK dnafrag.dnafrag_id
  dnafrag_start               int(10) DEFAULT '0' NOT NULL,
  dnafrag_end                 int(10) DEFAULT '0' NOT NULL,
  dnafrag_strand              tinyint(4) DEFAULT '0' NOT NULL,
  cigar_line                  mediumtext,
  level_id                    tinyint(2) unsigned DEFAULT '0' NOT NULL,

  FOREIGN KEY (genomic_align_block_id) REFERENCES genomic_align_block(genomic_align_block_id),
  # method_link_species_set(method_link_species_set_id) is not a unique key. Some RDBMS may complain
  # FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),
  
  PRIMARY KEY genomic_align_id (genomic_align_id),
  KEY genomic_align_block_id (genomic_align_block_id),
  KEY dnafrag (dnafrag_id, method_link_species_set_id, dnafrag_start, dnafrag_end)
) MAX_ROWS = 1000000000 AVG_ROW_LENGTH = 60;


#
# Table structure for table 'genomic_align_group'
# 
#   This table can store several groupings of the genomic aligned sequences
#

CREATE TABLE genomic_align_group (
  group_id                    int(10) unsigned NOT NULL AUTO_INCREMENT, # internal id, groups genomic_align_ids
  type                        varchar(40) NOT NULL,
  genomic_align_id            bigint unsigned NOT NULL, # FK genomic_align.genomic_align_id

  FOREIGN KEY (genomic_align_id) REFERENCES genomic_align(genomic_align_id),

  KEY group_id (group_id),
  KEY genomic_align_id (genomic_align_id, type)
);


#
# Table structure for table 'synteny_region'
#
# We have now decided that Synteny is inherently pairwise
# these tables hold the pairwise information for the synteny
# regions. We reuse the dnafrag table as a link out for identifiers
# (eg, '2' on mouse).
#

CREATE TABLE synteny_region (
  synteny_region_id           int(10) unsigned NOT NULL auto_increment, # unique internal id
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK method_link_species_set.method_link_species_set_id
  rel_orientation             tinyint(1) DEFAULT '1' NOT NULL,

  # method_link_species_set(method_link_species_set_id) is not a unique key. Some RDBMS may complain
  # FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY (synteny_region_id),
  KEY (method_link_species_set_id)
);


#
# Table structure for table 'dnafrag_region'
#

CREATE TABLE dnafrag_region (
  synteny_region_id           int(10) unsigned DEFAULT '0' NOT NULL, # unique internal id
  dnafrag_id                  int(10) unsigned DEFAULT '0' NOT NULL, # FK dnafrag.dnafrag_id
#  seq_start                   int(10) unsigned DEFAULT '0' NOT NULL,
#  seq_end                     int(10) unsigned DEFAULT '0' NOT NULL,
  dnafrag_start               int(10) unsigned DEFAULT '0' NOT NULL,
  dnafrag_end                 int(10) unsigned DEFAULT '0' NOT NULL,
  
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),

  UNIQUE unique_synteny (synteny_region_id,dnafrag_id),
  UNIQUE unique_synteny_reversed (dnafrag_id,synteny_region_id)
);


#
# Table structure for table 'sequence'
#

CREATE TABLE sequence (
  sequence_id                 int(10) unsigned NOT NULL auto_increment, # unique internal id
  length                      int(10) NOT NULL,
  sequence                    longtext NOT NULL,

  PRIMARY KEY (sequence_id),
  KEY sequence (sequence(18))
) MAX_ROWS = 1000000 AVG_ROW_LENGTH = 19000;


#
# Table structure for table 'member'
#

CREATE TABLE member (
  member_id                   int(10) unsigned NOT NULL auto_increment, # unique internal id
  stable_id                   varchar(40) NOT NULL, # e.g. ENSP000001234 or P31946
  version                     int(10) DEFAULT '0', 
  source_name                 varchar(40) NOT NULL,
  taxon_id                    int(10) unsigned NOT NULL, # FK taxon.taxon_id
  genome_db_id                int(10) unsigned, # FK genome_db.genome_db_id
  sequence_id                 int(10) unsigned, # FK sequence.sequence_id
  gene_member_id              int(10) unsigned, # FK member.member_id
  description                 varchar(255),
  chr_name                    char(40),
  chr_start                   int(10),
  chr_end                     int(10),
  chr_strand                  tinyint(1) NOT NULL,

  FOREIGN KEY (taxon_id) REFERENCES taxon(taxon_id),
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),
  FOREIGN KEY (sequence_id) REFERENCES sequence(sequence_id),
  FOREIGN KEY (gene_member_id) REFERENCES member(member_id),

  PRIMARY KEY (member_id),
  UNIQUE source_stable_id (stable_id, source_name),
  KEY (stable_id),
  KEY (source_name),
  KEY (sequence_id),
  KEY (gene_member_id)
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

  analysis_id                 int(10) unsigned NOT NULL auto_increment, # unique internal id
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
  UNIQUE (logic_name)

);

CREATE TABLE analysis_description (
  analysis_id                int(10) unsigned NOT NULL,
  description                text,
  display_label              varchar(255),

  KEY analysis_idx( analysis_id )
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

  peptide_align_feature_id    int(10) unsigned NOT NULL auto_increment, # unique internal id
  qmember_id                  int(10) unsigned NOT NULL, # FK member.member_id
  hmember_id                  int(10) unsigned NOT NULL, # FK member.member_id
  qgenome_db_id               int(10) unsigned NOT NULL, # FK genome.genome_id
  hgenome_db_id               int(10) unsigned NOT NULL, # FK genome.genome_id
  analysis_id                 int(10) unsigned NOT NULL, # FK analysis.analysis_id
  qstart                      int(10) DEFAULT '0' NOT NULL,
  qend                        int(10) DEFAULT '0' NOT NULL,
  hstart                      int(11) DEFAULT '0' NOT NULL,
  hend                        int(11) DEFAULT '0' NOT NULL,
  score                       double(16,4) DEFAULT '0.0000' NOT NULL,
  evalue                      double,
  align_length                int(10),
  identical_matches           int(10),
  perc_ident                  int(10),
  positive_matches            int(10),
  perc_pos                    int(10),
  hit_rank                    int(10),
  cigar_line                  mediumtext,

  FOREIGN KEY (qmember_id) REFERENCES member(member_id),
  FOREIGN KEY (hmember_id) REFERENCES member(member_id),
  FOREIGN KEY (qgenome_db_id) REFERENCES genome_db(genome_db_id),
  FOREIGN KEY (hgenome_db_id) REFERENCES genome_db(genome_db_id),
  FOREIGN KEY (analysis_id) REFERENCES analysis(analysis_id),

  PRIMARY KEY (peptide_align_feature_id),
  KEY qmember_id  (qmember_id),
  KEY hmember_id  (hmember_id),
  KEY hmember_qgenome  (hmember_id, qgenome_db_id),
  KEY qmember_hgenome  (qmember_id, hgenome_db_id)
) MAX_ROWS = 300000000 AVG_ROW_LENGTH = 133;


#
# Table structure for table 'homology'
#

CREATE TABLE homology (
  homology_id                 int(10) unsigned NOT NULL auto_increment, # unique internal id
  stable_id                   varchar(40),
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK method_link_species_set.method_link_species_set_id
  description                 varchar(40), # UBRH, MBRH, RHS
  subtype                     varchar(40) NOT NULL DEFAULT '',
  dn                          float(10,5),
  ds                          float(10,5),
  n                           float(10,1),
  s                           float(10,1),
  lnl                         float(10,3),
  threshold_on_ds             float(10,5),

  # method_link_species_set(method_link_species_set_id) is not a unique key. Some RDBMS may complain
  # FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY (homology_id),
  KEY (method_link_species_set_id)
);


#
# Table structure for table 'homology_member'
#

CREATE TABLE homology_member (
  homology_id                 int(10) unsigned NOT NULL, # FK homology.homology_id
  member_id                   int(10) unsigned NOT NULL, # FK member.member_id
  peptide_member_id           int(10) unsigned, # FK member.member_id
  peptide_align_feature_id    int(10) unsigned, # FK peptide_align_feature.peptide_align_feature_id
  cigar_line                  mediumtext,
  cigar_start                 int(10),
  cigar_end                   int(10),
  perc_cov                    int(10),
  perc_id                     int(10),
  perc_pos                    int(10),

  FOREIGN KEY (homology_id) REFERENCES homology(homology_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  FOREIGN KEY (peptide_member_id) REFERENCES member(member_id),
  FOREIGN KEY (peptide_align_feature_id) REFERENCES peptide_align_feature(peptide_align_feature_id),

  UNIQUE homology_member_id (homology_id,member_id),
  KEY (homology_id),
  KEY (member_id),
  KEY (peptide_member_id),
  KEY (peptide_align_feature_id)
);


#
# Table structure for table 'family'
#

CREATE TABLE family (
  family_id                   int(10) unsigned NOT NULL auto_increment, # unique internal id
  stable_id                   varchar(40) NOT NULL, # unique stable id, e.g. ENSF0000012345
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK method_link_species_set.method_link_species_set_id
  description                 varchar(255),
  description_score           double,

  # method_link_species_set(method_link_species_set_id) is not a unique key. Some RDBMS may complain
  # FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY (family_id), 
  UNIQUE (stable_id),
  KEY (method_link_species_set_id),
  KEY (description)
);


#
# Table structure for table 'family_member'
#

CREATE TABLE family_member (
  family_id                   int(10) unsigned NOT NULL, # FK family.family_id
  member_id                   int(10) unsigned NOT NULL, # FK member.memeber_id
  cigar_line                  mediumtext,

  FOREIGN KEY (family_id) REFERENCES family(family_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
 
  UNIQUE family_member_id (family_id,member_id),
  KEY (family_id),
  KEY (member_id)
);


#
# Table structure for table 'domain'
#

CREATE TABLE domain (
  domain_id                   int(10) unsigned NOT NULL auto_increment, # unique internal id
  stable_id                   varchar(40) NOT NULL,
#  source_id                   int(10) NOT NULL,
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK method_link_species_set.method_link_species_set_id
  description                 varchar(255),

  # method_link_species_set(method_link_species_set_id) is not a unique key. Some RDBMS may complain
  # FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY (domain_id),
  UNIQUE (stable_id, method_link_species_set_id)
);


#
# Table structure for table 'domain_member'
#

CREATE TABLE domain_member (
  domain_id                   int(10) unsigned NOT NULL, # FK domain.domain_id
  member_id                   int(10) unsigned NOT NULL, # FK member.member_id
  member_start                int(10),
  member_end                  int(10),

  FOREIGN KEY (domain_id) REFERENCES domain(domain_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),

  UNIQUE (domain_id,member_id,member_start,member_end),
  UNIQUE (member_id,domain_id,member_start,member_end)
);

