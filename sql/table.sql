# conventions taken from the new clean scheam of EnsEMBL
# use lower case and underscores
# internal ids are integers named tablename_id
# same name is given in foreign key relations

#
# We have now decided that Synteny is inherently pairwise
# these tables hold the pairwise information for the synteny
# regions. We reuse the dnafrag table as a link out for identifiers
# (eg, '2' on mouse).
#
create table synteny_region (
    synteny_region_id integer(10) NOT NULL auto_increment,
    orientation       tinyint(1)  NOT NULL DEFAULT 1,

    PRIMARY KEY (synteny_region_id)
);

create table dna_region (
    dna_region_id integer(10) NOT NULL auto_increment,
    synteny_region_id integer(10) NOT NULL,
    dnafrag_id        integer(10) NOT NULL,
    start             integer(10) NOT NULL,
    end               integer(10) NOT NULL,

    PRIMARY KEY (dna_region_id),
    UNIQUE KEY unique_synteny (synteny_region_id,dnafrag_id),
    UNIQUE KEY unique_synteny_reversed (dnafrag_id,synteny_region_id)
);

create table dnafrag (
    dnafrag_id   integer(10) NOT NULL auto_increment,
    name         varchar(40) NOT NULL,
    source_db_id integer(10) NOT NULL,
    species_id   integer(10) NOT NULL,
    type         ENUM ( 'RawContig', 'Chromosome'),

    PRIMARY KEY(dnafrag_id), 
    UNIQUE KEY (name,type)
);


create table source_db (
    source_db_id integer(10) NOT NULL auto_increment,
    name         varchar(40) NOT NULL,
    locator      varchar(255) NOT NULL,

    PRIMARY KEY(source_db_id),
    UNIQUE KEY (name,locator)
);

create table species (
    species_id integer(10) NOT NULL auto_increment,
    name       varchar(255) NOT NULL,

    PRIMARY KEY(species_id)
);

CREATE TABLE protein_relationship (
    protein_relationship_id integer(10) NOT NULL auto_increment,
    stable_id   varchar(40) NOT NULL,
    type        enum('homologous_pair','family','interpro','domain'),
    description varchar(255),

    PRIMARY KEY (protein_relationship_id)
);


CREATE TABLE protein_relationship_member (
    protein_relationship_member_id integer(10) NOT NULL auto_increment,
    protein_relationship_id integer(10) NOT NULL,
    source_db_id            integer(10) NOT NULL,
    species_id              integer(10) NOT NULL,
    member_stable_id        varchar(40) NOT NULL,

    PRIMARY KEY (protein_relationship_member_id),
    KEY protein_relationship_id (protein_relationship_id)
);


create table dna_align (
    dna_align_id integer(10) NOT NULL auto_increment,
    name         varchar(40) NOT NULL,

    PRIMARY KEY (dna_align_id)
);

create table dna_align_block (
    dna_align_block_id integer(10) NOT NULL auto_increment,
    dna_align_id       integer(10) NOT NULL,
    dna_align_start    integer(10) NOT NULL,
    dna_align_end      integer(10) NOT NULL,
    dnafrag_id         integer(10) NOT NULL,
    hit_start          integer(10) NOT NULL,
    hit_end            integer(10) NOT NULL,
    hit_strand         integer(10) NOT NULL,
    score              double,
    perc_id            integer(10),
    cigar_line         mediumtext,
    dna_align_row_id   integer(10) NOT NULL,

    PRIMARY KEY (dna_align_block_id),
    KEY (dnafrag_id,hit_start,hit_end),
    KEY (dnafrag_id,hit_end),
    KEY (dnafrag_id)
);

# Table containing denormalised data to allow conversion between 
# protein and DNA coordinates
create table _protein_locator (
    _protein_locator_id integer(10) NOT NULL auto_increment,
    protein_relationship_member_id integer(10) NOT NULL,
    dnafrag_id          integer(10) NOT NULL,
    start               integer(10) NOT NULL,
    end                 integer(10) NOT NULL,
    strand              integer(10) NOT NULL,

    PRIMARY KEY (_protein_locator_id),
    KEY (dnafrag_id,start,end),
    KEY (dnafrag_id,end)
);

create table _protein_gene (
    _protein_gene_id integer(10) NOT NULL auto_increment,
    protein_relationship_member_id integer(10) NOT NULL,
    gene_stable_id varchar(40) NOT NULL,

    PRIMARY KEY (_protein_gene_id)
);

create table dna_align_row (
    dna_align_row_id integer(10) NOT NULL auto_increment,
    dna_align_id     integer(10) NOT NULL,

    PRIMARY KEY (dna_align_row_id)
);

create table protein_relationship_alignment (
   protein_relationship_alignment_id  integer(10) NOT NULL auto_increment,
   protein_relationship_id integer(10) NOT NULL, 
   alignment_type          varchar(40) NOT NULL,
   alignment_cigar_line    mediumtext,
 
   PRIMARY KEY(protein_relationship_alignment_id),
   UNIQUE KEY(protein_relationship_id ,alignment_type),
   KEY(alignment_type)
);
