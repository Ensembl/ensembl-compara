-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2020] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# conventions taken from the new clean schema of EnsEMBL
# use lower case and underscores
# internal ids are integers named tablename_id
# same name is given in foreign key relations


# --------------------------------- common part of the schema ------------------------------------


/**
@header Dataset description
@desc     These are general tables used in the Compara schema
@colour   #3CB371
*/

/**
@table meta
@desc This table stores meta information about the compara database
@colour   #3CB371

@example  This query defines which API version must be used to access this database.
    @sql                SELECT * FROM meta WHERE meta_key = "schema_version";

@column meta_id     Internal unique ID for the table
@column species_id         Only used in core databases
@column meta_key           Key for the key/value pair
@column meta_value         Value for the key/value pair

*/

CREATE TABLE IF NOT EXISTS meta (

  meta_id                     INT NOT NULL AUTO_INCREMENT,
  species_id                  INT UNSIGNED DEFAULT 1,
  meta_key                    VARCHAR(40) NOT NULL,
  meta_value                  TEXT NOT NULL,

  PRIMARY   KEY (meta_id),
  UNIQUE    KEY species_key_value_idx (species_id, meta_key, meta_value(255)),
            KEY species_value_idx (species_id, meta_value(255))

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@header Taxonomy and species-tree
@colour   #24DA06
@desc   Species-tree used in the Compara analyses (incl. new annotations generated in-house), and the NCBI taxonomy (which often used as a template for species-trees)
*/

/**
@table ncbi_taxa_node
@desc This table contains all taxa used in this database, which mirror the data and tree structure from NCBI Taxonomy database (for more details see ensembl-compara/script/taxonomy/README-taxonomy which explain our import process)
@colour   #24DA06

@example    This examples shows how to get the lineage for Homo sapiens:
    @sql    SELECT n2.taxon_id, n2.parent_id, na.name, n2.rank, n2.left_index, n2.right_index FROM ncbi_taxa_node n1 JOIN (ncbi_taxa_node n2 LEFT JOIN ncbi_taxa_name na ON n2.taxon_id = na.taxon_id AND na.name_class = "scientific name")  ON n2.left_index <= n1.left_index AND n2.right_index >= n1.right_index WHERE n1.taxon_id = 9606 ORDER BY left_index;

@column taxon_id                The NCBI Taxonomy ID
@column parent_id               The parent taxonomy ID for this node (refers to ncbi_taxa_node.taxon_id)
@column rank                    E.g. kingdom, family, genus, etc.
@column genbank_hidden_flag     Boolean value which defines whether this rank is used or not in the abbreviated lineage
@column left_index              Sub-set left index. All sub-nodes have left_index and right_index values larger than this left_index
@column right_index             Sub-set right index. All sub-nodes have left_index and right_index values smaller than this right_index
@column root_id                 The root taxonomy ID for this node (refers to ncbi_taxa_node.taxon_id)

@see ncbi_taxa_name
*/

CREATE TABLE ncbi_taxa_node (
  taxon_id                        int(10) unsigned NOT NULL,
  parent_id                       int(10) unsigned NOT NULL,

  rank                            char(32) default '' NOT NULL,
  genbank_hidden_flag             tinyint(1) default 0 NOT NULL,

  left_index                      int(10) DEFAULT 0 NOT NULL,
  right_index                     int(10) DEFAULT 0 NOT NULL,
  root_id                         int(10) default 1 NOT NULL,

  PRIMARY KEY (taxon_id),
  KEY (parent_id),
  KEY (rank),
  KEY (left_index),
  KEY (right_index)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table ncbi_taxa_name
@desc This table contains different names, aliases and meta data for the taxa used in Ensembl.
@colour   #24DA06

@example    Here is an example on how to get the taxonomic ID for a species:
    @sql                          SELECT * FROM ncbi_taxa_name WHERE name_class = "scientific name" AND name = "Homo sapiens";

@column taxon_id              External reference to taxon_id in @link ncbi_taxa_node
@column name                  Information assigned to this taxon_id
@column name_class            Type of information. e.g. common name, genbank_synonym, scientif name, etc.

@see ncbi_taxa_node
*/


CREATE TABLE ncbi_taxa_name (
  taxon_id                    int(10) unsigned NOT NULL,
  name                        varchar(255) NOT NULL,
  name_class                  varchar(50) NOT NULL,

  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),

  KEY (taxon_id),
  KEY (name),
  KEY (name_class)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@header Genomes
@colour   #808000
@desc   Description of the genomes (assembly, sequences, genes, etc)
*/

/**
@table genome_db
@desc  This table contains information about the version of the genome assemblies used in this database
@colour   #808000

@example   This query shows the entries for human and chicken
   @sql                      SELECT * FROM genome_db WHERE name IN ("Homo_sapiens", "Gallus_gallus");

@column genome_db_id      Internal unique ID for this table
@column taxon_id          External reference to taxon_id in the @link ncbi_taxa_node table
@column name              Species name
@column assembly          Assembly version of the genome
@column genebuild         Version of the genebuild
@column has_karyotype     Whether the genome has a karyotype
@column is_good_for_alignment Whether the genome is good enough to be used in multiple alignments
@column genome_component  Only used for polyploid genomes: the name of the genome component
@column strain_name       Name of the particular strain this GenomeDB refers to
@column display_name      Named used for display purposes. Imported from the core databases
@column locator           Used for production purposes or for user configuration in in-house installation.
@column first_release     The first release this genome was present in
@column last_release      The last release this genome was present in, or NULL if it is still current

*/

CREATE TABLE genome_db (
  genome_db_id                int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  taxon_id                    int(10) unsigned DEFAULT NULL, # KF taxon.taxon_id
  name                        varchar(128) DEFAULT '' NOT NULL,
  assembly                    varchar(100) DEFAULT '' NOT NULL,
  genebuild                   varchar(100) DEFAULT '' NOT NULL,
  has_karyotype			tinyint(1) NOT NULL DEFAULT 0,
  is_good_for_alignment       TINYINT(1) NOT NULL DEFAULT 0,
  genome_component            varchar(5) DEFAULT NULL,
  strain_name                 varchar(100) DEFAULT NULL,
  display_name                varchar(255) DEFAULT NULL,
  locator                     varchar(400),
  first_release               smallint,
  last_release                smallint,

  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),

  PRIMARY KEY (genome_db_id),
  UNIQUE name (name,assembly,genebuild)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@header Genomes
@table dnafrag
@desc  This table defines the genomic sequences used in the comparative genomics analyisis. It is used by the @link genomic_align_block table to define aligned sequences. It is also used by the @link dnafrag_region table to define syntenic regions.<br />NOTE: Index &lt;name&gt; has genome_db_id in the first place because unless fetching all dnafrags or fetching by dnafrag_id, genome_db_id appears always in the WHERE clause. Unique key &lt;name&gt; is used to ensure that Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor->fetch_by_GenomeDB_and_name will always fetch a single row. This can be used in the EnsEMBL Compara DB because we store top-level dnafrags only.
@colour #808000

@example    This query shows the chromosome 14 of the Human genome (genome_db.genome_db_id = 150 refers to Human genome in this example) which is 107349540 nucleotides long.
    @sql                   SELECT dnafrag.* FROM dnafrag LEFT JOIN genome_db USING (genome_db_id) WHERE dnafrag.name = "14" AND genome_db.name = "homo_sapiens";

@column dnafrag_id         Internal unique ID
@column length             The total length of the dnafrag
@column name               Name of the DNA sequence (e.g., the name of the chromosome)
@column genome_db_id       External reference to genome_db_id in the @link genome_db table
@column coord_system_name  Refers to the coord system in which this dnafrag has been defined
@column is_reference       Boolean, whether dnafrag is reference (1) or non-reference (0) eg haplotype
@column cellular_component Either "NUC", "MT", "PT" or "OTHER". Represents which organelle genome the dnafrag is part of
@column codon_table_id     Integer. The numeric identifier of the codon-table that applies to this dnafrag (https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi)

@see genomic_align_block
@see dnafrag_region
*/

CREATE TABLE dnafrag (
  dnafrag_id                  bigint unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  length                      int unsigned DEFAULT 0 NOT NULL,
  name                        varchar(255) DEFAULT '' NOT NULL,
  genome_db_id                int(10) unsigned NOT NULL, # FK genome_db.genome_db_id
  coord_system_name           varchar(40) DEFAULT '' NOT NULL,
  cellular_component          ENUM('NUC', 'MT', 'PT', 'OTHER') DEFAULT 'NUC' NOT NULL,
  is_reference                tinyint(1) DEFAULT 1 NOT NULL,
  codon_table_id              tinyint(2) unsigned DEFAULT 1 NOT NULL,

  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),

  PRIMARY KEY (dnafrag_id),
  UNIQUE name (genome_db_id, name)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@header   Gene trees and homologies
@desc     These tables store information about gene alignments, trees and homologies
@colour   #1E90FF
*/

/**
@header Genomes
@table sequence
@desc  This table contains the sequences of the seq_member entries
@colour   #808000

@column sequence_id     Internal unique ID
@column length          Length of the sequence
@column sequence        The actual sequence
@column md5sum          md5sum
*/

CREATE TABLE sequence (
  sequence_id                 int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  length                      int(10) NOT NULL,
  md5sum                      CHAR(32) NOT NULL,
  sequence                    longtext NOT NULL,

  PRIMARY KEY (sequence_id),
  KEY md5sum (md5sum)
) MAX_ROWS = 10000000 AVG_ROW_LENGTH = 19000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table gene_member
@desc  This table links sequences to the EnsEMBL core DB or to external DBs.
@colour   #808000

@example   The following query refers to the human (ncbi_taxa_node.taxon_id = 9606 or genome_db_id = 150) gene ENSG00000176105
      @sql                          SELECT * FROM gene_member WHERE stable_id = "ENSG00000176105";

@column gene_member_id             Internal unique ID
@column stable_id             EnsEMBL stable ID
@column version               Version of the stable ID (see EnsEMBL core DB)
@column source_name           The source of the member
@column taxon_id              External reference to taxon_id in the @link ncbi_taxa_node table
@column genome_db_id          External reference to genome_db_id in the @link genome_db table
@column biotype_group         Biotype of this gene.
@column canonical_member_id   External reference to seq_member_id in the @link seq_member table to allow linkage from a gene to its canonical peptide
@column description           The description of the gene/protein as described in the core database or from the Uniprot entry
@column dnafrag_id            External reference to dnafrag_id in the @link dnafrag table. It shows the dnafrag the member is on.
@column dnafrag_start         Starting position within the dnafrag defined by dnafrag_id
@column dnafrag_end           Ending position within the dnafrag defined by dnafrag_id
@column dnafrag_strand        Strand in the dnafrag defined by dnafrag_id
@column display_label         Display name (imported from the core database)

@see sequence
*/

CREATE TABLE gene_member (
  gene_member_id              int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  stable_id                   varchar(128) NOT NULL, # e.g. ENSP000001234 or P31946
  version                     int(10) DEFAULT 0,
  source_name                 ENUM('ENSEMBLGENE', 'EXTERNALGENE') NOT NULL,
  taxon_id                    int(10) unsigned NOT NULL, # FK taxon.taxon_id
  genome_db_id                int(10) unsigned, # FK genome_db.genome_db_id
  biotype_group               ENUM('coding','pseudogene','snoncoding','lnoncoding','mnoncoding','LRG','undefined','no_group','current_notdumped','notcurrent') NOT NULL DEFAULT 'coding',
  canonical_member_id         int(10) unsigned, # FK seq_member.seq_member_id
  description                 text DEFAULT NULL,
  dnafrag_id                  bigint unsigned, # FK dnafrag.dnafrag_id
  dnafrag_start               int(10),
  dnafrag_end                 int(10),
  dnafrag_strand              tinyint(4),
  display_label               varchar(128) default NULL,

  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),

  PRIMARY KEY (gene_member_id),
  UNIQUE (stable_id),
  KEY (source_name),
  KEY (canonical_member_id),
  KEY dnafrag_id_start (dnafrag_id,dnafrag_start),
  KEY dnafrag_id_end (dnafrag_id,dnafrag_end),
  KEY biotype_dnafrag_id_start_end (biotype_group,dnafrag_id,dnafrag_start,dnafrag_end),
  KEY genome_db_id_biotype (genome_db_id, biotype_group)
) MAX_ROWS = 100000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@header Genomes
@table seq_member
@desc  This table links sequences to the EnsEMBL core DB or to external DBs.
@colour   #808000

@example   The following query refers to the human (ncbi_taxa_node.taxon_id = 9606 or genome_db_id = 150) peptide ENSP00000324740
      @sql                          SELECT * FROM seq_member WHERE stable_id = "ENSP00000324740";

@column seq_member_id             Internal unique ID
@column stable_id             EnsEMBL stable ID or external ID (for Uniprot/SWISSPROT and Uniprot/SPTREMBL)
@column version               Version of the stable ID (see EnsEMBL core DB)
@column source_name           The source of the member
@column taxon_id              External reference to taxon_id in the @link ncbi_taxa_node table
@column genome_db_id          External reference to genome_db_id in the @link genome_db table
@column sequence_id           External reference to sequence_id in the @link sequence table. May be 0 when the sequence is not available in the @link sequence table, e.g. for a gene instance
@column gene_member_id        External reference to gene_member_id in the @link gene_member table to allow linkage from peptides and transcripts to genes
@column has_transcript_edits  Boolean. Whether there are SeqEdits that modify the transcript sequence. When this happens, the (exon) coordinates don't match the transcript sequence
@column has_translation_edits Boolean. Whether there are SeqEdits that modify the protein sequence. When this happens, the protein sequence doesn't match the transcript sequence
@column description           The description of the gene/protein as described in the core database or from the Uniprot entry
@column dnafrag_id            External reference to dnafrag_id in the @link dnafrag table. It shows the dnafrag the member is on.
@column dnafrag_start         Starting position within the dnafrag defined by dnafrag_id
@column dnafrag_end           Ending position within the dnafrag defined by dnafrag_id
@column dnafrag_strand        Strand in the dnafrag defined by dnafrag_id
@column display_label         Display name (imported from the core database)

@see sequence
*/

CREATE TABLE seq_member (
  seq_member_id               int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  stable_id                   varchar(128) NOT NULL, # e.g. ENSP000001234 or P31946
  version                     int(10) DEFAULT 0,
  source_name                 ENUM('ENSEMBLPEP','ENSEMBLTRANS','Uniprot/SPTREMBL','Uniprot/SWISSPROT','EXTERNALPEP','EXTERNALTRANS','EXTERNALCDS') NOT NULL,
  taxon_id                    int(10) unsigned NOT NULL, # FK taxon.taxon_id
  genome_db_id                int(10) unsigned, # FK genome_db.genome_db_id
  sequence_id                 int(10) unsigned, # FK sequence.sequence_id
  gene_member_id              int(10) unsigned, # FK gene_member.gene_member_id
  has_transcript_edits        tinyint(1) DEFAULT 0 NOT NULL,
  has_translation_edits       tinyint(1) DEFAULT 0 NOT NULL,
  description                 text DEFAULT NULL,
  dnafrag_id                  bigint unsigned, # FK dnafrag.dnafrag_id
  dnafrag_start               int(10),
  dnafrag_end                 int(10),
  dnafrag_strand              tinyint(4),
  display_label               varchar(128) default NULL,

  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),
  FOREIGN KEY (sequence_id) REFERENCES sequence(sequence_id),
  FOREIGN KEY (gene_member_id) REFERENCES gene_member(gene_member_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),

  PRIMARY KEY (seq_member_id),
  UNIQUE (stable_id),
  KEY (source_name),
  KEY (sequence_id),
  KEY (gene_member_id),
  KEY dnafrag_id_start (dnafrag_id,dnafrag_start),
  KEY dnafrag_id_end (dnafrag_id,dnafrag_end),
  KEY seq_member_gene_member_id_end (seq_member_id,gene_member_id)
) MAX_ROWS = 100000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;


-- Add schema version to database
DELETE FROM meta WHERE meta_key='schema_version';
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'schema_version', '1');
-- Add schema type to database
DELETE FROM meta WHERE meta_key='schema_type';
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'schema_type', 'compara');
