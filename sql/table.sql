


create table genome_db (
       genome_db_id integer(10) NOT NULL auto_increment,
       name varchar(40) NOT NULL,
       locator varchar(255) NOT NULL
);

create table dnafrag (
       dnafrag_id integer(10) NOT NULL auto_increment,
       name      varchar(40) NOT NULL,
       genome_db_id integer(10) NOT NULL,
       PRIMAY KEY(contig_id)
);


create table genomic_align_block (
       align_id      integer(10) NOT NULL,
       align_start   integer(10) NOT NULL,
       align_end     integer(10) NOT NULL,
       align_row     integer(10) NOT NULL,
       dnafrag_id    integer(10) NOT NULL,
       raw_start     integer(10) NOT NULL,
       raw_end       integer(10) NOT NULL,
       raw_strand    integer(10) NOT NULL,

       PRIMARY KEY (align_id,align_start,align_end,contig_id),
       KEY (contig_id,raw_start,raw_end),
       KEY (contig_id,raw_end)
       );
