


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
# Synteny cluster is a set of (large) genomic regions
# on different species which we believe to be related. Each
# synteny cluster has an extent on piece of genomic dna 
# (this is held by the synteny_region table) and
# a set of alignments (held by the synteny_cluster_align)
#
# The seq_start and seq_end is sort of semi-denormalisation of
# the inherent information inside the alignments, but remember
# that one is probably using quite an involved computational
# procedure for deducing the extents and that alignments may
# have more species than this cluster

create table synteny_cluster (
       synteny_cluster_id integer(10) NOT NULL auto_increment,
       score double,
       PRIMARY KEY(synteny_cluster_id)
);

create table synteny_region (
       synteny_region_id  integer(10) NOT NULL auto_increment,
       synteny_cluster_id integer(10) NOT NULL, # PK synteny_cluster
       dnafrag_id         integer(10) NOT NULL, # PK dnafrag
       seq_start          integer(10) NOT NULL,
       seq_end            integer(10) NOT NULL,

       PRIMARY KEY (synteny_region_id),       
       KEY (dnafrag_id,seq_start)
);

create table synteny_cluster_align (
       synteny_cluster_id integer(10) NOT NULL, # PK synteny_cluster
       align_id           integer(10) NOT NULL, # PK align

       PRIMARY_KEY(synteny_cluster_id,align_id)
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
