


create table genome_db (
       genome_db_id integer(10) NOT NULL auto_increment,
       name varchar(40) NOT NULL,
       locator varchar(255) NOT NULL,
       PRIMARY KEY(genome_db_id)
);


create table dnafrag (
       dnafrag_id integer(10) NOT NULL auto_increment,
       name      varchar(40) NOT NULL,
       genome_db_id integer(10) NOT NULL,
       dnafrag_type ENUM ( 'RawContig', 'Chromosome'),
       PRIMARY KEY(dnafrag_id), 
       KEY (dnafrag_id, name),
       UNIQUE KEY (name)
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
    seq_start         unsigned int (10) NOT NULL,
    seq_end           unsigned int (10) NOT NULL,
    UNIQUE KEY unique_synteny (synteny_region_id,dnafrag_id),
    UNIQUE KEY unique_synteny_reversed (dnafrag_id,synteny_region_id)
);




create table align (
       align_id integer(10) NOT NULL auto_increment,
       score    varchar(20),
       align_name     varchar(40),

       PRIMARY KEY (align_id)
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

       PRIMARY KEY (align_id,align_start,align_end,dnafrag_id),
       KEY (dnafrag_id,raw_start,raw_end),
       KEY (dnafrag_id,raw_end),
       KEY (dnafrag_id)
       );
