# conventions taken from the new clean scheam of EnsEMBL
# use lower case and underscores
# internal ids are integers named tablename_id
# same name is given in foreign key relations


create table genome_db (
       genome_db_id integer(10) NOT NULL auto_increment,
       name varchar(40) NOT NULL,
       locator varchar(255) NOT NULL,
       PRIMARY KEY(genome_db_id),
       UNIQUE KEY (name,locator)
);


create table dnafrag (
       dnafrag_id integer(10) NOT NULL auto_increment,
       name      varchar(40) NOT NULL,
       genome_db_id integer(10) NOT NULL,
       dnafrag_type ENUM ( 'RawContig', 'Chromosome'),
       PRIMARY KEY(dnafrag_id), 
       UNIQUE KEY (name,dnafrag_type)
);

#
# We have now decided that Synteny is inherently pairwise
# these tables hold the pairwise information for the synteny
# regions. We reuse the dnafrag table as a link out for identifiers
# (eg, '2' on mouse).
#

create table synteny_region (
    synteny_region_id integer(10) NOT NULL auto_increment,
    rel_orientation   tinyint(1)  NOT NULL DEFAULT 1,
    PRIMARY KEY (synteny_region_id)
);

create table dnafrag_region (
    synteny_region_id integer(10) NOT NULL, # PK synteny_region
    dnafrag_id        integer(10) NOT NULL, # PK dnafrag
    seq_start         int (10) unsigned NOT NULL,
    seq_end           int (10) unsigned NOT NULL,
    UNIQUE KEY unique_synteny (synteny_region_id,dnafrag_id),
    UNIQUE KEY unique_synteny_reversed (dnafrag_id,synteny_region_id)
);



#
# Table structure for table 'gene_relationship'
#

CREATE TABLE gene_relationship (
  gene_relationship_id int(10) NOT NULL auto_increment,
  relationship_stable_id varchar(40),
  relationship_type enum('homologous_pair','family','interpro'),
  description varchar(255),
  annotation_confidence_score double,
  PRIMARY KEY (gene_relationship_id)
);

#
# Table structure for table 'gene_relationship_member'
#

CREATE TABLE gene_relationship_member (
  gene_relationship_id int(10),
  genome_db_id int(10),
  member_stable_id varchar(40),
  chrom_start int(10),
  chrom_end int(10),
  chromosome varchar(10),
  KEY gene_relationship_id (gene_relationship_id),
  KEY member_stable_id (member_stable_id)
);









create table align (
       align_id integer(10) NOT NULL auto_increment,
       score    varchar(20),
       align_name     varchar(40),

       PRIMARY KEY (align_id),
       KEY (align_name)
);

create table align_row (
       align_row_id integer(10) NOT NULL auto_increment,
       align_id     integer(10),
       PRIMARY KEY (align_row_id)
);

create table genomic_align_block (
       align_id      integer(10) NOT NULL,
       align_start   integer(10) NOT NULL,
       align_end     integer(10) NOT NULL,
       align_row_id  integer(10) NOT NULL,
       dnafrag_id    integer(10) NOT NULL,
       raw_start     integer(10) NOT NULL,
       raw_end       integer(10) NOT NULL,
       raw_strand    integer(10) NOT NULL,
       score         double   ,
       perc_id       integer(10) ,
       cigar_line    mediumtext,

       PRIMARY KEY (align_id,align_start,align_end,align_row_id,dnafrag_id),
       KEY (dnafrag_id,raw_start,raw_end),
       KEY (dnafrag_id,raw_end),
       KEY (dnafrag_id)
       );




#
# Table structure for table 'protein'
#

CREATE TABLE protein (
  protein_id int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  protein_sequence_id int(10) NOT NULL,
  protein_external_id varchar(40) DEFAULT '0' NOT NULL,
  protein_external_dbname varchar(40) NOT NULL,
  dnafrag_id int(10) DEFAULT '' ,
  seq_start int(10) unsigned DEFAULT '0' ,
  seq_end int(10) unsigned DEFAULT '0' ,
  strand tinyint(2) DEFAULT '0' ,

  PRIMARY KEY (protein_id),
  KEY (dnafrag_id),
  KEY (protein_sequence_id),
  UNIQUE KEY (protein_external_id)

);

# SEMANTICS
# protein_id - internal 
# protein_external_id - id of protein in another database (stable_id if external_id is an ensembl core database)
# dnafrag_id - foreign key (dnafrag internal id from dnafrag table)
# seq_start, seq_end - coordinates of the protein on the dnafrag

CREATE TABLE protein_sequence(
       protein_sequence_id int(10) NOT NULL auto_increment,
       sequence mediumtext,

       PRIMARY KEY(protein_sequence_id)
);

# SEMANTICS
# protein_sequence_id - internal id 
# sequence - protein sequence

CREATE TABLE score (
  score_id    int(10) NOT NULL auto_increment,
  score       int(10) NOT NULL,
  
  PRIMARY KEY (score_id),
  KEY (score)
);

# SEMANTICS
# score_id - internal id
# score - value of the score
# This table stores the score of a protein-protein blastp result
# The actual proteins involved in the comparison are stored in the score_protein table

#
# Table structure for table 'score_protein'
#
CREATE TABLE score_protein (
  score_id    int(10) NOT NULL,
  protein_id       int(10) NOT NULL,
  
  PRIMARY KEY (score_id),
  KEY (protein_id)
);

# SEMANTICS
# score_id - internal id
# protein_id - foreign key from protein table
# The proteins of the blastp comparison are stored here to use symmetrical design 
# and avoid the asymmetrical protein_a protein_b kind of table

#
# Table structure for table 'family_'
#
CREATE TABLE family (
   family_id    int(10) NOT NULL auto_increment,
   threshold    int(10) ,
   description  varchar(255), 
   annotation_confidence_score double DEFAULT 0,

   PRIMARY KEY(family_id),
   KEY (threshold)
);
# SEMANTICS
# family_id - internal id
# threshold - similarity threshold with which the family was built 

#
# Table structure for table 'family_'
#
CREATE TABLE family_stable_id (
   family_id	int(10) NOT NULL auto_increment,
   stable_id varchar(40), # ensembl family ids
   version   int(10) DEFAULT '1' NOT NULL,
   created   datetime NOT NULL,
   modified  datetime NOT NULL,
    
   PRIMARY KEY(family_id),
   UNIQUE(stable_id,version)
);
# SEMANTICS
# family_id - internal id
# threshold - similarity threshold with which the family was built


#
#Table structure for table 'family_alignment'
#
CREATE TABLE family_alignment (
   family_alignment_id	int(10) unsigned NOT NULL auto_increment,
   family_id int(10) unsigned NOT NULL, # ensembl family ids
   alignment_type varchar(40) NOT NULL,
   alignment_cigar_line mediumtext,

   PRIMARY KEY(family_alignment_id),
   UNIQUE KEY(family_id ,alignment_type),
   KEY(alignment_type)
);

# SEMANTICS
# family_alignment_id - internal id
# family - the family for which the multiple alignment was done on
# alignment - the alignment string

#
# Table structure for table 'family_protein'
#
CREATE TABLE family_protein (
   family_protein_id     int(10) unsigned NOT NULL auto_increment,
   family_id     int(10) NOT NULL,
   protein_id    int(10) NOT NULL,
   score         float(10) DEFAULT 0,
 
   PRIMARY KEY(family_protein_id),
   KEY(family_id),
   KEY (protein_id)
);
# SEMANTICS
# family_protein_id - internal id
# family_id - foreign key to family table
# protein_id - foreign key to protein table
# score - the score of this protein associated with this family
# Families are simply collections of proteins, and each protein
# has a rank in the family according to how closely similar it is to the best match in the family

#
# Table structure for table 'conserved_clusters'
#
CREATE TABLE conserved_cluster(
  conserved_cluster_id int(10) unsigned NOT NULL auto_increment,
  conserved_gene_families         int(10) unsigned NOT NULL,
  
  PRIMARY KEY (conserved_cluster_id),
  KEY (conserved_gene_families)
);
# SEMANTICS
# csonserved_cluster_id - internal id
# conserved_gene_familes - number of conserved genes famailes in the segment

#
# Table structure for table 'conserved_segment'
#
CREATE TABLE conserved_segment(
  conserved_segment_id int(10) unsigned NOT NULL auto_increment,
  conserved_cluster_id           int(10) unsigned NOT NULL,
  dnafrag_id                 int(10) unsigned NOT NULL,
  seq_start               int(10) unsigned NOT NULL,
  seq_end                 int(10) unsigned NOT NULL,
  intervening_genes       int(10) unsigned NULL,  
#  length                  int(10) select (seq_end-seq_start),

  PRIMARY KEY (conserved_segment_id),
  KEY (conserved_cluster_id),
  KEY (dnafrag_id),
  KEY (seq_start),
  KEY (seq_end)
);
# SEMANTICS
# conserved_segment_id- internal id
# conserved_cluster_id - foreign key to conserved_cluster table
# dnafrag_id - foreign key from dnafrag, indicates which dna fragment
#               this conserved segment is found on
# seq_start - start of the conserved segment on the dnafrag
# seq_end - end of the conserved segment on the dnafrag
# length - auto-calculated column for convenience

#
# Table structure for table 'conserved_segment_protein'
#
CREATE TABLE conserved_segment_protein (
  conserved_segment_protein_id    int(10) unsigned NOT NULL auto_increment,
  conserved_segment_id    int(10) unsigned NOT NULL,
  protein_id             int(10) unsigned NOT NULL,
  
  PRIMARY KEY (conserved_segment_protein_id),
  KEY (conserved_segment_id),
  KEY (protein_id)
);
# SEMANTICS
# conserved_segment_id - internal id
# protein_id - foreign key from protein, indicates which proteins belong to the segment

