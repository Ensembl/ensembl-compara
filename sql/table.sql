


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
       PRIMARY KEY(dnafrag_id), 
       KEY (dnafrag_id), 
       KEY (dnafrag_id, name),
       UNIQUE KEY (name)
);
#added by tania = align_name
create table align (
       align_id integer(10) NOT NULL auto_increment,
       score    varchar(20),
       align_name     varchar(40),

       PRIMARY KEY (align_id)
);


#added by tania to store the results of the synteny region

create table synteny_cluster(
       syn_cluster_id   integer(10) NOT NULL ,
       align_id   integer(10) NOT NULL,
       dnafrag_id   integer(10) NOT NULL,

       PRIMARY KEY (syn_cluster_id,align_id,dnafrag_id),
       KEY (dnafrag_id),
       KEY (syn_cluster_id), 
       KEY (align_id)
);

#added by tania to store the results of the synteny cluster
#changed synteny->cluster_description
create table cluster_description(
       syn_cluster_id    integer(10) NOT NULL auto_increment,
       dnafrag_id	 integer(10) NOT NULL, 
       cluster_start     integer(10) NOT NULL, 
       cluster_end       integer(10) NOT NULL,
       
       PRIMARY KEY(syn_cluster_id,dnafrag_id),
       KEY(dnafrag_id),
       KEY(cluster_start, cluster_end)
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
