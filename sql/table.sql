# conventions taken from the new clean scheam of EnsEMBL
# use lower case and underscores
# internal ids are integers named tablename_id
# same name is given in foreign key relations

#
# Table structure for table 'dnafrag'
#

CREATE TABLE dnafrag (
  dnafrag_id int(10) NOT NULL auto_increment,
  start int(11) DEFAULT '0' NOT NULL,
  end int(11) DEFAULT '0' NOT NULL,
  name varchar(40) DEFAULT '' NOT NULL,
  genome_db_id int(10) DEFAULT '0' NOT NULL,
  dnafrag_type enum('chromosome','scaffold', 'supercontig'),

  PRIMARY KEY (dnafrag_id),
  KEY dnafrag_id (dnafrag_id,name),
  UNIQUE name (name,genome_db_id,dnafrag_type)
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
  locator           varchar(255) DEFAULT '' NOT NULL,

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
  method_link_id int(10) DEFAULT '0' NOT NULL,
  score double,
  length int(10),

  KEY align_block_id (align_block_id),
  KEY method_link_id (align_block_id, method_link_id)
);

#
# Table structure for table 'genomic_align'
# 
#   This table stores the sequences belonging to the same genomic_align_block entry
#

CREATE TABLE genomic_align (
  genomic_align_block_id int(10) NOT NULL,
  method_link_id int(10) DEFAULT '0' NOT NULL,
  dnafrag_id int(10) DEFAULT '0' NOT NULL,
  dnafrag_start int(10) DEFAULT '0' NOT NULL,
  dnafrag_end int(10) DEFAULT '0' NOT NULL,
  dnafrag_strand tinyint(4) DEFAULT '0' NOT NULL,
  cigar_line mediumtext,
  group_id int(10) DEFAULT '0' NOT NULL,
  level_id int(10) DEFAULT '0' NOT NULL,

  KEY align_block_id (align_block_id),
  KEY query_dnafrag_id (dnafrag_id,dnafrag_start,dnafrag_start),
  KEY query_dnafrag_id2 (dnafrag_id,method_link_id,dnafrag_end,dnafrag_end)
);

#
# Table structure for table 'genomic_align_genome'
#

CREATE TABLE genomic_align_genome (
  consensus_genome_db_id int(11) DEFAULT '0' NOT NULL,
  query_genome_db_id int(11) DEFAULT '0' NOT NULL,
  method_link_id int(10) DEFAULT '0' NOT NULL
);

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
# Table structure for table 'method_link_species'
#

CREATE TABLE method_link_species (
  method_link_id int(10),
  species_set int(10),
  genome_db_id int(10),
  UNIQUE method_link_id (method_link_id,species_set,genome_db_id)
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

CREATE TABLE source (
 source_id	int(10) NOT NULL auto_increment,
 source_name	varchar(40) NOT NULL,

 PRIMARY KEY (source_id),
 UNIQUE KEY (source_name)
);

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
 source_id      int(10) NOT NULL, # foreign key from source table
 taxon_id       int(10) NOT NULL, # foreign key from taxon table
 genome_db_id   int(10), # foreign key from genome_db table
 sequence_id    int(10), # foreign key from sequence table
 description    varchar(255),
 chr_name       char(40),
 chr_start      int(10),
 chr_end        int(10),
 chr_strand     tinyint(1) NOT NULL,

 PRIMARY KEY (member_id),
 UNIQUE KEY (source_id,stable_id),
 KEY (sequence_id)
);

CREATE TABLE sequence (
 sequence_id    int(10) NOT NULL auto_increment,
 sequence       mediumtext,
 length         int(10),

 PRIMARY KEY (sequence_id)
);


CREATE TABLE family (
 family_id		int(10) NOT NULL auto_increment,
 stable_id		varchar(40) NOT NULL, # e.g. ENSF0000012345
 source_id              int(10) NOT NULL, # foreign key from source table
 description		varchar(255),
 description_score	double,

 PRIMARY KEY (family_id), 
 UNIQUE KEY (stable_id),
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
 source_id	int(10) NOT NULL,
 description	varchar(255),

 PRIMARY KEY (domain_id),
 UNIQUE KEY (source_id,stable_id)
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
 source_id      int(10) NOT NULL, # foreign key from source table
 description		varchar(40), # SEED, PIP, etc...
 dn             float(10,5),
 ds             float(10,5),
 n              float(10,1),
 s              float(10,1),
 lnl            float(10,3),
 threshold_on_ds float(10,5),

 PRIMARY KEY (homology_id)
);

CREATE TABLE homology_member (
 homology_id            int(10) NOT NULL,
 member_id              int(10) NOT NULL,
 peptide_member_id      int(10),
 cigar_line	        mediumtext,
 cigar_start            int(10),
 cigar_end              int(10),
 perc_cov	        int(10),
 perc_id	        int(10),
 perc_pos	        int(10),

 UNIQUE KEY (member_id,homology_id),
 UNIQUE KEY (homology_id,member_id)
);
