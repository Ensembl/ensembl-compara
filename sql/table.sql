# conventions taken from the new clean scheam of EnsEMBL
# use lower case and underscores
# internal ids are integers named tablename_id
# same name is given in foreign key relations

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
       dnafrag_type ENUM ('RawContig','Chromosome','VirtualContig'),
       PRIMARY KEY(dnafrag_id), 
#       UNIQUE KEY (name,dnafrag_type)
       KEY (dnafrag_id, name),
       UNIQUE KEY (name,genome_db_id,dnafrag_type)
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

# method_link table specifies which kind of link can exist between species 
# (dna/dna alignment, synteny regions, homologous gene pairs,...)

CREATE TABLE method_link (
  method_link_id int(10) NOT NULL auto_increment,
  method_link_type varchar(10) NOT NULL,
  PRIMARY KEY (method_link_id)
);

# method_link_species table specifying which species are part of a method_link_id

CREATE TABLE method_link_species (
  method_link_id int(10), # PK method_link
  genome_db_id int(10), # PK genome_db
  UNIQUE KEY (method_link_id,genome_db_id)
);

##################################################################
##################################################################

# The following tables would probably be part of the new compara schema

# We have now decided that Synteny is inherently pairwise
# these tables hold the pairwise information for the synteny
# regions. We reuse the dnafrag table as a link out for identifiers
# (eg, '2' on mouse).
#
# create table synteny_region (
#     synteny_region_id integer(10) NOT NULL auto_increment,
#     orientation       tinyint(1)  NOT NULL DEFAULT 1,
# 
#     PRIMARY KEY (synteny_region_id)
# );

# create table dna_region (
#     dna_region_id integer(10) NOT NULL auto_increment,
#     synteny_region_id integer(10) NOT NULL,
#     dnafrag_id        integer(10) NOT NULL,
#     start             integer(10) NOT NULL,
#     end               integer(10) NOT NULL,

#     PRIMARY KEY (dna_region_id),
#     UNIQUE KEY unique_synteny (synteny_region_id,dnafrag_id),
#     UNIQUE KEY unique_synteny_reversed (dnafrag_id,synteny_region_id)
# );

# create table dnafrag (
#     dnafrag_id   integer(10) NOT NULL auto_increment,
#     name         varchar(40) NOT NULL,
#     source_db_id integer(10) NOT NULL,
#     species_id   integer(10) NOT NULL,
#     type         ENUM ( 'RawContig', 'Chromosome'),

#     PRIMARY KEY(dnafrag_id), 
#     UNIQUE KEY (name,type)
# );


# create table source_db (
#     source_db_id integer(10) NOT NULL auto_increment,
#     name         varchar(40) NOT NULL,
#     locator      varchar(255) NOT NULL,

#     PRIMARY KEY(source_db_id),
#     UNIQUE KEY (name,locator)
# );

# create table species (
#     species_id integer(10) NOT NULL auto_increment,
#     name       varchar(255) NOT NULL,

#     PRIMARY KEY(species_id)
# );

# CREATE TABLE protein_relationship (
#     protein_relationship_id integer(10) NOT NULL auto_increment,
#     stable_id   varchar(40) NOT NULL,
#     type        enum('homologous_pair','family','interpro','domain'),
#     description varchar(255),

#     PRIMARY KEY (protein_relationship_id)
# );


# CREATE TABLE protein_relationship_member (
#     protein_relationship_member_id integer(10) NOT NULL auto_increment,
#     protein_relationship_id integer(10) NOT NULL,
#     source_db_id            integer(10) NOT NULL,
#     species_id              integer(10) NOT NULL,
#     member_stable_id        varchar(40) NOT NULL,

#     PRIMARY KEY (protein_relationship_member_id),
#     KEY protein_relationship_id (protein_relationship_id)
# );


# create table dna_align (
#     dna_align_id integer(10) NOT NULL auto_increment,
#     name         varchar(40) NOT NULL,

#     PRIMARY KEY (dna_align_id)
# );

# create table dna_align_block (
#     dna_align_block_id integer(10) NOT NULL auto_increment,
#     dna_align_id       integer(10) NOT NULL,
#     dna_align_start    integer(10) NOT NULL,
#     dna_align_end      integer(10) NOT NULL,
#     dnafrag_id         integer(10) NOT NULL,
#     hit_start          integer(10) NOT NULL,
#     hit_end            integer(10) NOT NULL,
#     hit_strand         integer(10) NOT NULL,
#     score              double,
#     perc_id            integer(10),
#     cigar_line         mediumtext,
#     dna_align_row_id   integer(10) NOT NULL,

#     PRIMARY KEY (dna_align_block_id),
#     KEY (dnafrag_id,hit_start,hit_end),
#     KEY (dnafrag_id,hit_end),
#     KEY (dnafrag_id)
# );

# Table containing denormalised data to allow conversion between 
# protein and DNA coordinates

# create table _protein_locator (
#     _protein_locator_id integer(10) NOT NULL auto_increment,
#     protein_relationship_member_id integer(10) NOT NULL,
#     dnafrag_id          integer(10) NOT NULL,
#     start               integer(10) NOT NULL,
#     end                 integer(10) NOT NULL,
#     strand              integer(10) NOT NULL,

#     PRIMARY KEY (_protein_locator_id),
#     KEY (dnafrag_id,start,end),
#     KEY (dnafrag_id,end)
# );

# create table _protein_gene (
#     _protein_gene_id integer(10) NOT NULL auto_increment,
#     protein_relationship_member_id integer(10) NOT NULL,
#     gene_stable_id varchar(40) NOT NULL,

#     PRIMARY KEY (_protein_gene_id)
# );

# create table dna_align_row (
#     dna_align_row_id integer(10) NOT NULL auto_increment,
#     dna_align_id     integer(10) NOT NULL,

#     PRIMARY KEY (dna_align_row_id)
# );

# create table protein_relationship_alignment (
#    protein_relationship_alignment_id  integer(10) NOT NULL auto_increment,
#    protein_relationship_id integer(10) NOT NULL, 
#    alignment_type          varchar(40) NOT NULL,
#    alignment_cigar_line    mediumtext,
 
#    PRIMARY KEY(protein_relationship_alignment_id),
#    UNIQUE KEY(protein_relationship_id ,alignment_type),
#    KEY(alignment_type)
# );
