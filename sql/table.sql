-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
@header   General Tables
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
@table ncbi_taxa_node
@desc This table contains all taxa used in this database, which mirror the data and tree structure from NCBI Taxonomy database (for more details see ensembl-compara/script/taxonomy/README-taxonomy which explain our import process)
@colour   #3CB371

@example    This examples shows how to get the lineage for Homo sapiens:
    @sql    SELECT * FROM ncbi_taxa_node WHERE left_index <= 339687 AND right_index >= 339690 ORDER BY left_index;

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
@colour   #3CB371

@example    Here is an example on how to get the taxonomic ID for a species:
    @sql                          SELECT * FROM ncbi_taxa_name WHERE name_class = "scientific name" AND name = "Homo sapiens";

@column taxon_id              External reference to taxon_id in @link ncbi_taxa_node
@column name                  Information assigned to this taxon_id
@column name_class            Type of information. e.g. common name, genbank_synonym, scientif name, etc.

@see ncbi_taxa_node
*/


CREATE TABLE ncbi_taxa_name (
  taxon_id                    int(10) unsigned NOT NULL,
  name                        varchar(255),
  name_class                  varchar(50),

  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),

  KEY (taxon_id),
  KEY (name),
  KEY (name_class)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table genome_db
@desc  This table contains information about the version of the genome assemblies used in this database
@colour   #3CB371

@example   This query shows the entries for human and chicken
   @sql                      SELECT * FROM genome_db WHERE name IN ("Homo_sapiens", "Gallus_gallus");

@column genome_db_id      Internal unique ID for this table
@column taxon_id          External reference to taxon_id in the @link ncbi_taxa_node table
@column name              Species name
@column assembly          Assembly version of the genome
@column assembly_default  Boolean value describing if this assembly is the default one or not, so that we can handle more than one assembly version for a given species.
@column genebuild         Version of the genebuild
@column has_karyotype     Whether the genome has a karyotype
@column is_high_coverage  Whether the assembly coverage depth is high enough
@column genome_component  Only used for polyploid genomes: the name of the genome component
@column locator           Used for production purposes or for user configuration in in-house installation.

*/

CREATE TABLE genome_db (
  genome_db_id                int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  taxon_id                    int(10) unsigned DEFAULT NULL, # KF taxon.taxon_id
  name                        varchar(128) DEFAULT '' NOT NULL,
  assembly                    varchar(100) DEFAULT '' NOT NULL,
  assembly_default            tinyint(1) DEFAULT 1,
  genebuild                   varchar(100) DEFAULT '' NOT NULL,
  has_karyotype			tinyint(1) NOT NULL DEFAULT 0,
  is_high_coverage            tinyint(1) NOT NULL DEFAULT 0,
  genome_component            varchar(5) DEFAULT NULL,
  locator                     varchar(400),

  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),

  PRIMARY KEY (genome_db_id),
  UNIQUE name (name,assembly,genebuild,genome_component)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table species_set
@desc  Contains groups or sets of species which are used in the @link method_link_species_set table. Each species_set is a set of @link genome_db objects
@colour   #3CB371

@example     This query shows the first 10 species_sets having human
   @sql      SELECT species_set_id, GROUP_CONCAT(name) AS species FROM species_set JOIN genome_db USING(genome_db_id) GROUP BY species_set_id HAVING species LIKE '%homo_sapiens%' ORDER BY species_set_id LIMIT 10;
  
@column species_set_id    Internal (non-unique) ID for the table
@column genome_db_id      External reference to genome_db_id in the @link genome_db table


@see method_link_species_set
@see genome_db
*/

CREATE TABLE species_set (
  species_set_id              int(10) unsigned NOT NULL AUTO_INCREMENT,
  genome_db_id                int(10) unsigned DEFAULT NULL,

  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),

  UNIQUE KEY  (species_set_id,genome_db_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table species_set_tag
@desc  This table contains descriptive tags for the species_set_ids in the species_set table. It is used to store options on clades and group of species. It has been initially developed for the gene tree view.
@colour   #3CB371

@example     This query retrieves all the species_sets tagged as 'primates' and links to the @link genome_db table to retrieve the species names 
     @sql     SELECT species_set_id, name, tag, value FROM species_set JOIN species_set_tag USING(species_set_id) JOIN genome_db USING(genome_db_id) WHERE value = 'primates';

@column species_set_id     External reference to species_set_id in the @link species_set table
@column tag                Tag name
@column value              Tag value

@see species_set
*/

CREATE TABLE species_set_tag (
  species_set_id              int(10) unsigned NOT NULL, # FK species_set.species_set_id
  tag                         varchar(50) NOT NULL,
  value                       mediumtext,

  ## NB: species_set_id is not unique so cannot be used as a foreign key
  # FOREIGN KEY (species_set_id) REFERENCES species_set(species_set_id),

  UNIQUE KEY tag_species_set_id (species_set_id,tag)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table method_link
@desc  This table specifies which kind of link can exist between entities in compara (dna/dna alignment, synteny regions, homologous gene pairs, etc...)<br/>NOTE: We use method_link_ids between 1 and 100 for DNA-DNA alignments, between 101 and 200 for genomic syntenies, between 201 and 300 for protein homologies, between 301 and 400 for protein families and between 401 and 500 for protein and ncRNA trees. Each category corresponds to data stored in different tables.
@colour   #3CB371

@example  These are our current entries:
     @sql                             SELECT * FROM method_link;

@column method_link_id           Internal unique ID
@column type                     The common name of the linking method between species
@column class                    Description of type of data associated with the \"type\" field and the main table to find these data

@see method_link_species_set
@see species_set
*/

CREATE TABLE method_link (
  method_link_id              int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  type                        varchar(50) DEFAULT '' NOT NULL,
  class                       varchar(50) DEFAULT '' NOT NULL,

  PRIMARY KEY (method_link_id),
  UNIQUE KEY type (type)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table method_link_species_set
@desc  This table contains information about the comparisons stored in the database. A given method_link_species_set_id exist for each comparison made and relates a method_link_id in @link method_link with a set of species (species_set_id) in the @link species_set table.
@colour   #3CB371

@example     This query shows all the EPO alignments in this database:
   @sql                                  SELECT * FROM method_link_species_set WHERE method_link_id = 13;

@column method_link_species_set_id    Internal unique ID
@column method_link_id                External reference to method_link_id in the @link method_link table
@column species_set_id                External reference to species_set_id in the @link species_set table
@column name                          Human-readable description for this method_link_species_set
@column source                        Source of the data. Currently either "ensembl" or "ucsc" if data were imported from UCSC
@column url                           A URL where you can find the orignal data if they were imported

@see method_link
@see species_set
*/

CREATE TABLE method_link_species_set (
  method_link_species_set_id  int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  method_link_id              int(10) unsigned, # FK method_link.method_link_id
  species_set_id              int(10) unsigned NOT NULL default 0,
  name                        varchar(255) NOT NULL default '',
  source                      varchar(255) NOT NULL default 'ensembl',
  url                         varchar(255) NOT NULL default '',

  FOREIGN KEY (method_link_id) REFERENCES method_link(method_link_id),
  ## NB: species_set_id is not unique so cannot be used as a foreign key
  # FOREIGN KEY (species_set_id) REFERENCES species_set(species_set_id),

  PRIMARY KEY (method_link_species_set_id),
  UNIQUE KEY method_link_id (method_link_id,species_set_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table method_link_species_set_tag
@desc  Contains serveral tag/value data associated with method_link_species_set entries
@colour   #3CB371

@column method_link_species_set_id         External reference to method_link_species_set_id in the @link method_link_species_set table
@column tag                                Tag name
@column value                              Tag value

@see method_link_species_set
*/


CREATE TABLE method_link_species_set_tag (
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK species_set.species_set_id
  tag                         varchar(50) NOT NULL,
  value                       mediumtext,

  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY tag_mlss_id (method_link_species_set_id,tag)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table species_tree_node
@desc  This table contains the nodes of the species tree used in the gene gain/loss analysis
@colour   #1E90FF

@column node_id                 Internal unique ID
@column parent_id               Link to the parent node
@column root_id                 Link to the root node
@column left_index              Internal index
@column right_index             Internal index
@column distance_to_parent      Phylogenetic distance between this node and its parent
@column taxon_id                Link to NCBI taxon node
@column genome_db_id            Link to the genome_db
@column node_name               A name that can be set to the taxon name or any other arbitrary name

@see species_tree_node_tag
@see species_tree_root
@see CAFE_gene_family
@see CAFE_species_gene
*/

CREATE TABLE `species_tree_node` (
  `node_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned,
  `root_id` int(10) unsigned,
  `left_index` int(10) NOT NULL DEFAULT 0,
  `right_index` int(10) NOT NULL DEFAULT 0,
  `distance_to_parent` double DEFAULT '1',
  `taxon_id` int(10) UNSIGNED,
  `genome_db_id` int(10) UNSIGNED,
  `node_name` VARCHAR(255),

  FOREIGN KEY (`taxon_id`) REFERENCES ncbi_taxa_node(taxon_id),
  FOREIGN KEY (`genome_db_id`) REFERENCES genome_db(genome_db_id), 
  PRIMARY KEY (`node_id`),
  KEY `parent_id` (`parent_id`),
  KEY `root_id` (`root_id`,`left_index`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/**
@table species_tree_root
@desc  This table stores species trees used in compara. Each tree is made of species_tree_node's
@colour   #1E90FF

@column root_id                       Internal unique ID
@column method_link_species_set_id    External reference to method_link_species_set_id in the @link method_link_species_set table
@column label                         Label to differentiate different trees with the same mlss_id
@column species_tree                  Newick formatted version of the whole species_tree

@example   Retrieve all the species trees stored in the database
    @sql SELECT * FROM species_tree_root

@see species_tree_node
*/

CREATE TABLE `species_tree_root` (
  `root_id` int(10) unsigned NOT NULL,
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `label` VARCHAR(256) NOT NULL DEFAULT 'default',
  `species_tree` mediumtext,

  FOREIGN KEY (root_id) REFERENCES species_tree_node(node_id),
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  UNIQUE KEY (method_link_species_set_id, label),

  PRIMARY KEY (root_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


/**
@table species_tree_node_tag
@desc  This table contains tag/value data for species_tree_nodes
@colour   #1E90FF

@column node_id           Internal unique ID
@column tag               Tag name for the tag/value pair
@column value             Value for the tag/value pair

@see species_tree_node
@see species_tree_root
*/

CREATE TABLE `species_tree_node_tag` (
  `node_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext NOT NULL,

  FOREIGN KEY (node_id) REFERENCES species_tree_node(node_id),

  KEY `node_id_tag` (`node_id`,`tag`),
  KEY `tag_node_id` (`tag`,`node_id`),
  KEY `node_id` (`node_id`),
  KEY `tag` (`tag`)
  
) ENGINE=MyISAM DEFAULT CHARSET=latin1;



/**
@header Genomic alignments tables
@desc   These tables store information about genomic alignments in the Compara schema
@colour #FF8500
*/

/**
@table synteny_region
@desc  Contains all the syntenic relationships found and the relative orientation of both syntenic regions.
@colour #FF8500

@example    This query shows that the syntenic region 34965 corresponds to a synteny relationship between the Human and Opossum genomes
   @sql                                  SELECT * FROM synteny_region WHERE synteny_region_id = 41285;

@example    Linking with the @link method_link_species_set table we get the names:
   @sql                                  SELECT synteny_region_id, name FROM synteny_region join method_link_species_set USING(method_link_species_set_id) WHERE synteny_region_id = 41285;

@column synteny_region_id             Internal unique ID
@column method_link_species_set_id    External reference to method_link_species_set_id in the @link method_link_species_set table

@see method_link_species_set
*/

CREATE TABLE synteny_region (
  synteny_region_id           int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK method_link_species_set.method_link_species_set_id

  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY (synteny_region_id),
  KEY (method_link_species_set_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table dnafrag
@desc  This table defines the genomic sequences used in the comparative genomics analyisis. It is used by the @link genomic_align_block table to define aligned sequences. It is also used by the @link dnafrag_region table to define syntenic regions.<br />NOTE: Index <name> has genome_db_id in the first place because unless fetching all dnafrags or fetching by dnafrag_id, genome_db_id appears always in the WHERE clause. Unique key <name> is used to ensure that Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor->fetch_by_GenomeDB_and_name will always fetch a single row. This can be used in the EnsEMBL Compara DB because we store top-level dnafrags only.
@colour #FF8500

@example    This query shows the chromosome 14 of the Human genome (genome_db.genome_db_id = 90 refers to Human genome in this example) which is 107349540 nucleotides long.
    @sql                   SELECT dnafrag.* FROM dnafrag LEFT JOIN genome_db USING (genome_db_id) WHERE dnafrag.name = "14" AND genome_db.name = "homo_sapiens";

@column dnafrag_id         Internal unique ID
@column length             The total length of the dnafrag
@column name               Name of the DNA sequence (e.g., the name of the chromosome)
@column genome_db_id       External reference to genome_db_id in the @link genome_db table
@column coord_system_name  Refers to the coord system in which this dnafrag has been defined
@column is_reference       Boolean, whether dnafrag is reference (1) or non-reference (0) eg haplotype

@see genomic_align_block
@see dnafrag_region
*/

CREATE TABLE dnafrag (
  dnafrag_id                  bigint unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  length                      int(11) DEFAULT 0 NOT NULL,
  name                        varchar(40) DEFAULT '' NOT NULL,
  genome_db_id                int(10) unsigned NOT NULL, # FK genome_db.genome_db_id
  coord_system_name           varchar(40) DEFAULT NULL,
  is_reference                tinyint(1) DEFAULT 1,

  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),

  PRIMARY KEY (dnafrag_id),
  UNIQUE name (genome_db_id, name)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table dnafrag_region
@desc  This table contains the genomic regions corresponding to every synteny relationship found. There are two genomic regions for every synteny relationship.
@colour #FF8500

@example     Example of dnafrag_region query
    @sql                        SELECT * FROM dnafrag_region WHERE synteny_region_id = 41285;
@example     When joining to @link dnafrag and @link genome_db tables we get more comprehensive information:
    @sql                        SELECT genome_db.name, dnafrag.name, dnafrag_start, dnafrag_end, dnafrag_strand FROM dnafrag_region LEFT JOIN dnafrag USING (dnafrag_id) LEFT JOIN genome_db USING (genome_db_id) WHERE synteny_region_id = 41285;

@column synteny_region_id   External reference to synteny_region_id in the @link synteny_region table
@column dnafrag_id          External reference to dnafrag_id in the @link dnafrag table
@column dnafrag_start       Position of the first nucleotide from this dnafrag which is in synteny
@column dnafrag_end         Position of the last nucleotide from this dnafrag which is in synteny
@column dnafrag_strand              Strand of this region

@see synteny_region
@see dnafrag
*/

CREATE TABLE dnafrag_region (
  synteny_region_id           int(10) unsigned DEFAULT 0 NOT NULL, # unique internal id
  dnafrag_id                  bigint unsigned DEFAULT 0 NOT NULL, # FK dnafrag.dnafrag_id
  dnafrag_start               int(10) unsigned DEFAULT 0 NOT NULL,
  dnafrag_end                 int(10) unsigned DEFAULT 0 NOT NULL,
  dnafrag_strand              tinyint(4) DEFAULT 0 NOT NULL,

  FOREIGN KEY (synteny_region_id) REFERENCES synteny_region(synteny_region_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),

  KEY synteny (synteny_region_id,dnafrag_id),
  KEY synteny_reversed (dnafrag_id,synteny_region_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table genomic_align_block
@desc  This table is the key table for the genomic alignments. The software used to align the genomic blocks is refered as an external key to the @link method_link table. Nevertheless, actual aligned sequences are defined in the @link genomic_align table.<br />Tree alignments (EPO alignments) are best accessed through the @link genomic_align_tree table although the alignments are also indexed in this table. This allows the user to also access the tree alignments as normal multiple alignments.<br />NOTE: All queries in the API uses the primary key as rows are always fetched using the genomic_align_block_id. The key 'method_link_species_set_id' is used by MART when fetching all the genomic_align_blocks corresponding to a given method_link_species_set_id
@colour #FF8500

@example    The following query refers to a primates EPO alignment:
    @sql                                 SELECT * FROM genomic_align_block WHERE genomic_align_block_id = 2250002943513;

@column genomic_align_block_id       Internal unique ID
@column method_link_species_set_id   External reference to method_link_species_set_id in the @link method_link_species_set table
@column score                        Score returned by the homology search program
@column perc_id                      Used for pairwise comparison. Defines the percentage of identity between both sequences
@column length                       Total length of the alignment
@column group_id                     Used to group alignments
@column level_id                     Level of orthologous layer. 1 corresponds to the principal layer of orthologous sequences found (the largest), 2 and over are additional layers. Use for building the syntenies (based on level_id = 1 only). Note that level_ids are not computed on whole chromosomes but rather on chunks. This means that level_ids can be inconsistent within an alignment-net.

@see method_link_species_set
@see genomic_align_tree
*/

CREATE TABLE genomic_align_block (
  genomic_align_block_id      bigint unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  method_link_species_set_id  int(10) unsigned DEFAULT 0 NOT NULL, # FK method_link_species_set_id.method_link_species_set_id
  score                       double,
  perc_id                     tinyint(3) unsigned DEFAULT NULL,
  length                      int(10),
  group_id                    bigint unsigned DEFAULT NULL,
  level_id                    tinyint(2) unsigned DEFAULT 0 NOT NULL,

  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY genomic_align_block_id (genomic_align_block_id),
  KEY method_link_species_set_id (method_link_species_set_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table genomic_align_tree
@desc  This table is used to index tree alignments, e.g. EPO alignments. These alignments include inferred ancestral sequences. The tree required to index these sequences is stored in this table. This table stores the structure of the tree. Each node links to an entry in the @link genomic_align_group table, which links to one or several entries in the @link genomic_align table.<br />NOTE: Left_index and right_index are used to speed up fetching trees from the database. Any given node has its left_index larger than the left_index of its parent node and its right index smaller than the right_index of its parent node. In other words, all descendent nodes of a given node can be obtained by fetching all the node with a left_index (or right_index or both) between the left_index and the right_index of that node.
@colour #FF8500

@example      The following query corresponds to the root of a tree, because parent_id = 0 and root_id = node_id
      @sql                        SELECT * FROM genomic_align_tree WHERE node_id = root_id LIMIT 1;

@example      In order to fetch all the nodes of this tree, one can use the left_index and right_index values:
      @sql                        SELECT * FROM genomic_align_tree WHERE left_index >= 100000019 and left_index <= 100000096;

@column node_id             Internal unique ID
@column parent_id           Link to the parent node
@column root_id             Link to root node
@column left_index          Internal index. See above
@column right_index         Internal index. See above
@column left_node_id        Link to the node on the left side of this node
@column right_node_id       Link to the node on the right side of this node
@column distance_to_parent  Phylogenetic distance between this node and its parent

@see genomic_align_group
*/

CREATE TABLE genomic_align_tree (
  node_id                     bigint(20) unsigned NOT NULL AUTO_INCREMENT, # internal id, FK genomic_align.node_id
  parent_id                   bigint(20) unsigned NOT NULL default 0,
  root_id                     bigint(20) unsigned NOT NULL default 0,
  left_index                  int(10) NOT NULL default 0,
  right_index                 int(10) NOT NULL default 0,
  left_node_id                bigint(10) NOT NULL default 0,
  right_node_id               bigint(10) NOT NULL default 0,
  distance_to_parent          double NOT NULL default 1,

  PRIMARY KEY node_id (node_id),
  KEY parent_id (parent_id),
  KEY root_id (root_id),
  KEY left_index (root_id, left_index)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table genomic_align
@desc  This table contains the coordinates and all the information needed to rebuild genomic alignments. Every entry corresponds to one of the aligned sequences. It also contains an external key to the @link method_link_species_set which refers to the software and set of species used for getting the corresponding alignment. The aligned sequence is defined by an external reference to the @link dnafrag table, the starting and ending position within this dnafrag, the strand and a cigar_line.<br />
The original aligned sequence is not stored but it can be retrieved using the <b>cigar_line</b> field and the original sequence. The cigar line defines the sequence of matches/mismatches and deletions (or gaps). For example, this cigar line <b>2MD3M2D2M</b> will mean that the alignment contains 2 matches/mismatches, 1 deletion (number 1 is omitted in order to save some space), 3 matches/mismatches, 2 deletions and 2 matches/mismatches. If the original sequence is:<br />
<ul><li>Original sequence: AACGCTT</li></ul>

The aligned sequence will be:<br />
    <table>
      <caption>cigar line: 2MD3M2D2M</caption>
      <thead><tr>
	<th>M</th>
	<th>M</th>
	<th>D</th>
	<th>M</th>
	<th>M</th>
	<th>M</th>
	<th>D</th>
	<th>D</th>
	<th>M</th>
	<th>M</th>
      </tr>
      </thead>
      <tbody>
	<tr>
	  <td>A</td>
	  <td>A</td>
	  <td>-</td>
	  <td>C</td>
	  <td>G</td>
	  <td>C</td>
	  <td>-</td>
	  <td>-</td>
	  <td>T</td>
	  <td>T</td>
	</tr>
      </tbody>
    </table>

@example      The following query corresponds to the three sequences included in the alignment described above (see @link genomic_align_block table description).
      @sql                                   SELECT * FROM genomic_align WHERE genomic_align_block_id = 2250002943513;
@example      Here is a better way to get this by joining the @link dnafrag and @link genome_db tables:
      @sql                                   SELECT genome_db.name, dnafrag.name, dnafrag_start, dnafrag_end, dnafrag_strand str, cigar_line FROM genomic_align LEFT JOIN dnafrag USING (dnafrag_id) LEFT JOIN genome_db USING (genome_db_id) WHERE genomic_align_block_id = 2250002943513;
@colour #FF8500

@column genomic_align_id               Unique internal ID
@column genomic_align_block_id         External reference to genomic_align_block_id in the @link genomic_align_block table
@column method_link_species_set_id     External reference to method_link_species_set_id in the @link method_link_species_set table. This information is redundant because it also appears in the @link genomic_align_block table but it is used to speed up the queries
@column dnafrag_id                     External reference to dnafrag_id in the @link dnafrag table
@column dnafrag_start                  Starting position within the dnafrag defined by dnafrag_id
@column dnafrag_end                    Ending position within the dnafrag defined by dnafrag_id
@column dnafrag_strand                 Strand in the dnafrag defined by dnafrag_id
@column cigar_line                     Internal description of the aligned sequence
@column visible                        Used in self alignments to ensure only one Bio::EnsEMBL::Compara::GenomicAlignBlock is visible when you have more than 1 block covering the same region
@column node_id                        External reference to node_id in the @link genomic_align_tree table

@see genomic_align_block
@see method_link_species_set
@see dnafrag
*/

CREATE TABLE genomic_align (
  genomic_align_id            bigint unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  genomic_align_block_id      bigint unsigned NOT NULL, # FK genomic_align_block.genomic_align_block_id
  method_link_species_set_id  int(10) unsigned DEFAULT 0 NOT NULL, # FK method_link_species_set_id.method_link_species_set_id
  dnafrag_id                  bigint unsigned DEFAULT 0 NOT NULL, # FK dnafrag.dnafrag_id
  dnafrag_start               int(10) DEFAULT 0 NOT NULL,
  dnafrag_end                 int(10) DEFAULT 0 NOT NULL,
  dnafrag_strand              tinyint(4) DEFAULT 0 NOT NULL,
  cigar_line                  mediumtext,
  visible                     tinyint(2) unsigned DEFAULT 1 NOT NULL,
  node_id                     bigint(20) unsigned DEFAULT NULL,

  FOREIGN KEY (genomic_align_block_id) REFERENCES genomic_align_block(genomic_align_block_id),
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),
  FOREIGN KEY (node_id) REFERENCES genomic_align_tree(node_id),

  PRIMARY KEY genomic_align_id (genomic_align_id),
  KEY genomic_align_block_id (genomic_align_block_id),
  KEY method_link_species_set_id (method_link_species_set_id),
  KEY dnafrag (dnafrag_id, method_link_species_set_id, dnafrag_start, dnafrag_end),
  KEY node_id (node_id)
) MAX_ROWS = 1000000000 AVG_ROW_LENGTH = 60 COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table conservation_score
@desc  This table contains conservation scores calculated from the whole-genome multiple alignments stored in the @link genomic_align_block table. Several scores are stored per row. expected_score and diff_score are binary columns and you need to use the Perl API to access these data.
@colour #FF8500

@column genomic_align_block_id   External reference to genomic_align_block_id in the @link genomic_align_block table
@column window_size              The scores are stored at different resolution levels. This column defines the window size used to calculate the average score
@column position                 Position of the first score (in alignment coordinates)
@column expected_score           Expected score. The observed score can be determined using the diff_score and the expected_score
@column diff_score               The difference between the expected and observed variation, i.e. the conservation score

@see genomic_align_block
*/

CREATE TABLE conservation_score (
  genomic_align_block_id bigint unsigned not null,
  window_size            smallint unsigned not null,
  position               int unsigned not null,
  expected_score         blob,
  diff_score             blob,

  FOREIGN KEY (genomic_align_block_id) REFERENCES genomic_align_block(genomic_align_block_id),

  KEY (genomic_align_block_id, window_size)
) MAX_ROWS = 15000000 AVG_ROW_LENGTH = 841 COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table constrained_element
@desc  This table contains constrained elements calculated from the whole-genome multiple alignments stored in the @link genomic_align_block table
@colour #FF8500

@example   Example entry for a constrained_element:
     @sql                                SELECT * FROM constrained_element LIMIT 1;
@example   There are 2 other elements in the same constrained_element:
     @sql                                SELECT constrained_element_id, genome_db.name, dnafrag.name FROM constrained_element JOIN dnafrag USING (dnafrag_id) JOIN genome_db USING (genome_db_id) WHERE constrained_element_id = 6650000000001;

@column constrained_element_id      Internal ID
@column dnafrag_id                  External reference to dnafrag_id in the @link dnafrag table
@column dnafrag_start               Start of the constrained element
@column dnafrag_end                 End of the constrained element
@column dnafrag_strand              Strand of the constrained element
@column method_link_species_set_id  External reference to method_link_species_set_id in the @link method_link_species_set table
@column p_value                     p-value derived from Gerp
@column score                       Score derived from Gerp

@see dnafrag
@see genomic_align_block
*/

CREATE TABLE constrained_element (
  constrained_element_id bigint(20) unsigned NOT NULL,
  dnafrag_id bigint unsigned NOT NULL,
  dnafrag_start int(12) unsigned NOT NULL,
  dnafrag_end int(12) unsigned NOT NULL,
  dnafrag_strand int(2),
  method_link_species_set_id int(10) unsigned NOT NULL,
  p_value double,
  score double NOT NULL default 0,

  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  KEY constrained_element_id_idx (constrained_element_id),
  KEY mlssid_idx (method_link_species_set_id),
  KEY mlssid_dfId_dfStart_dfEnd_idx (method_link_species_set_id,dnafrag_id,dnafrag_start,dnafrag_end),
  KEY mlssid_dfId_idx (method_link_species_set_id,dnafrag_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


# --------------------------------- Protein part of the schema ------------------------------------

/**
@header   Gene trees and homologies tables
@desc     These tables store information about gene alignments, trees and homologies
@colour   #1E90FF
*/

/**
@table sequence
@desc  This table contains the sequences of the seq_member entries
@colour   #1E90FF

@column sequence_id     Internal unique ID
@column length          Length of the sequence
@column sequence        The actual sequence
*/

CREATE TABLE sequence (
  sequence_id                 int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  length                      int(10) NOT NULL,
  sequence                    longtext NOT NULL,

  PRIMARY KEY (sequence_id),
  KEY sequence (sequence(18))
) MAX_ROWS = 10000000 AVG_ROW_LENGTH = 19000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table gene_member
@desc  This table links sequences to the EnsEMBL core DB or to external DBs.
@colour   #1E90FF

@example   The following query refers to the human (ncbi_taxa_node.taxon_id = 9606 or genome_db_id = 90) gene ENSG00000173213
      @sql                          SELECT * FROM gene_member WHERE stable_id = "ENSG00000173213";

@column gene_member_id             Internal unique ID
@column stable_id             EnsEMBL stable ID
@column version               Version of the stable ID (see EnsEMBL core DB)
@column source_name           The source of the member
@column taxon_id              External reference to taxon_id in the @link ncbi_taxa_node table
@column genome_db_id          External reference to genome_db_id in the @link genome_db table
@column canonical_member_id   External reference to seq_member_id in the @link seq_member table to allow linkage from a gene to its canonical peptide
@column description           The description of the gene/protein as described in the core database or from the Uniprot entry
@column dnafrag_id            External reference to dnafrag_id in the @link dnafrag table. It shows the dnafrag the member is on.
@column dnafrag_start         Starting position within the dnafrag defined by dnafrag_id
@column dnafrag_end           Ending position within the dnafrag defined by dnafrag_id
@column dnafrag_strand        Strand in the dnafrag defined by dnafrag_id
@column display_label         Display name (imported from the core database)
@column families              The number of families associated with this member
@column gene_trees            If this member is part of a gene tree
@column gene_gain_loss_trees  If this member is part of a gene gain/loss tree
@column orthologues           The number of orthologues for this member
@column paralogues            The number of paralogues for this member
@column homoeologues          The number of homoeologues for this member

@see sequence
*/

CREATE TABLE gene_member (
  gene_member_id              int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  stable_id                   varchar(128) NOT NULL, # e.g. ENSP000001234 or P31946
  version                     int(10) DEFAULT 0,
  source_name                 ENUM('ENSEMBLGENE', 'EXTERNALGENE') NOT NULL,
  taxon_id                    int(10) unsigned NOT NULL, # FK taxon.taxon_id
  genome_db_id                int(10) unsigned, # FK genome_db.genome_db_id
  canonical_member_id         int(10) unsigned, # FK seq_member.seq_member_id
  description                 text DEFAULT NULL,
  dnafrag_id                  bigint unsigned, # FK dnafrag.dnafrag_id
  dnafrag_start               int(10),
  dnafrag_end                 int(10),
  dnafrag_strand              tinyint(4),
  display_label               varchar(128) default NULL,

  `families`                 tinyint(1) unsigned default 0,
  `gene_trees`               tinyint(1) unsigned default 0,
  `gene_gain_loss_trees`     tinyint(1) unsigned default 0,
  `orthologues`              int(10) unsigned default 0,
  `paralogues`               int(10) unsigned default 0,
  `homoeologues`             int(10) unsigned default 0,


  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),

  PRIMARY KEY (gene_member_id),
  UNIQUE (stable_id),
  KEY (source_name),
  KEY (canonical_member_id),
  KEY dnafrag_id_start (dnafrag_id,dnafrag_start),
  KEY dnafrag_id_end (dnafrag_id,dnafrag_end)
) MAX_ROWS = 100000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table seq_member
@desc  This table links sequences to the EnsEMBL core DB or to external DBs.
@colour   #1E90FF

@example   The following query refers to the human (ncbi_taxa_node.taxon_id = 9606 or genome_db_id = 90) peptide ENSP00000309431
      @sql                          SELECT * FROM seq_member WHERE stable_id = "ENSP00000309431";

@column seq_member_id             Internal unique ID
@column stable_id             EnsEMBL stable ID or external ID (for Uniprot/SWISSPROT and Uniprot/SPTREMBL)
@column version               Version of the stable ID (see EnsEMBL core DB)
@column source_name           The source of the member
@column taxon_id              External reference to taxon_id in the @link ncbi_taxa_node table
@column genome_db_id          External reference to genome_db_id in the @link genome_db table
@column sequence_id           External reference to sequence_id in the @link sequence table. May be 0 when the sequence is not available in the @link sequence table, e.g. for a gene instance
@column gene_member_id        External reference to gene_member_id in the @link gene_member table to allow linkage from peptides and transcripts to genes
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



/**
@table external_db
@desc  This table stores data about the external databases in which the objects described in the @link member_xref table are stored.
@colour   #1E90FF

@column external_db_id          Internal unique ID
@column db_name                 External database name
@column db_release              Release information about the external database
@column status                  Status, e.g. 'KNOWNXREF','KNOWN','XREF','PRED','ORTH','PSEUDO'.
@column priority                Determines which one of the xrefs will be used as the gene name.
@column db_display_name         Database display name
@column type                    Type, e.g. 'ARRAY', 'ALT_TRANS', 'ALT_GENE', 'MISC', 'LIT', 'PRIMARY_DB_SYNONYM', 'ENSEMBL'
@column secondary_db_name       Secondary database name
@column secondary_db_table      Secondary database table
@column description             Description of the external database

@see member_xref
*/

#

#
# Table structure for table 'external_db'
#

CREATE TABLE `external_db` (
  `external_db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `db_name` varchar(100) NOT NULL,
  `db_release` varchar(255) DEFAULT NULL,
  `status` enum('KNOWNXREF','KNOWN','XREF','PRED','ORTH','PSEUDO') NOT NULL,
  `priority` int(11) NOT NULL,
  `db_display_name` varchar(255) DEFAULT NULL,
  `type` enum('ARRAY','ALT_TRANS','ALT_GENE','MISC','LIT','PRIMARY_DB_SYNONYM','ENSEMBL') DEFAULT NULL,
  `secondary_db_name` varchar(255) DEFAULT NULL,
  `secondary_db_table` varchar(255) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`external_db_id`),
  UNIQUE KEY `db_name_db_release_idx` (`db_name`,`db_release`)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table member_xref
@desc  This table stores cross-references for gene members derived from the core databases. It is used by Bio::EnsEMBL::Compara::DBSQL::XrefMemberAdaptor and provides the data used in highlighting gene trees by GO and InterPro annotation" 
@colour   #1E90FF

@column gene_member_id   External reference to gene_member_id in the @link gene_member table. Indicates the gene to which the xref applies.
@column dbprimary_acc    Accession of xref (e.g. GO term, InterPro accession)
@column external_db_id   External reference to external_db_id in the @link external_db table. Indicates to which external database the xref belongs.

@see external_db
*/

CREATE TABLE `member_xref` (
  `gene_member_id` int(10) unsigned NOT NULL,
  `dbprimary_acc` varchar(10) NOT NULL,
  `external_db_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`gene_member_id`,`dbprimary_acc`,`external_db_id`),
  FOREIGN KEY (gene_member_id) REFERENCES gene_member(gene_member_id),
  FOREIGN KEY (external_db_id) REFERENCES external_db(external_db_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table other_member_sequence
@desc  This table includes alternative sequences for Member, like sequences with flanking regions
@colour   #1E90FF

@column seq_member_id           External reference to seq_member_id in the @link seq_member table
@column seq_type                A short description of this alternative sequence
@column length                  The length of this sequence
@column sequence                The actual sequence

@see seq_member
@see sequence 
*/

CREATE TABLE other_member_sequence (
  seq_member_id                   int(10) unsigned NOT NULL, # unique internal id
  seq_type                    VARCHAR(40) NOT NULL,
  length                      int(10) NOT NULL,
  sequence                    mediumtext NOT NULL,

  FOREIGN KEY (seq_member_id) REFERENCES seq_member(seq_member_id),

  PRIMARY KEY (seq_member_id, seq_type)

) MAX_ROWS = 10000000 AVG_ROW_LENGTH = 60000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table peptide_align_feature
@desc: This table stores the raw local alignment results of peptide to peptide alignments returned by a BLAST run. The hits are actually stored in species-specific tables rather than in a single table. For example, human has the genome_db_id 90, and all the hits that have a human gene as a query are stored in peptide_align_feature_90
@colour   #1E90FF

@example    Example of peptide_align_feature entry:
     @sql                              SELECT * FROM peptide_align_feature_150 WHERE hgenome_db_id = 111 LIMIT 1;
@example    The following query corresponds to a particular hit found between a Homo sapiens protein and a Anolis carolinensis protein:
     @sql                              SELECT g1.name as qgenome, m1.stable_id as qstable_id, g2.name as hgenome, m2.stable_id as hstable_id, score, evalue FROM peptide_align_feature_150 JOIN seq_member m1 ON (qmember_id = m1.seq_member_id) JOIN seq_member m2 ON (hmember_id = m2.seq_member_id) JOIN genome_db g1 ON (qgenome_db_id = g1.genome_db_id) JOIN genome_db g2 ON (hgenome_db_id = g2.genome_db_id) WHERE hgenome_db_id = 111 LIMIT 1;


@column peptide_align_feature_id  Internal unique ID
@column qmember_id                External reference to seq_member_id in the @link seq_member table for the query peptide
@column hmember_id                External reference to seq_member_id in the @link seq_member table for the hit peptide
@column qgenome_db_id             External reference to genome_db_id in the @link genome_db table for the query peptide (for query optimization)
@column hgenome_db_id             External reference to genome_db_id in the @link genome_db table for the hit peptide (for query optimization)
@column qstart                    Starting position in the query peptide sequence
@column qend                      Ending position in the query peptide sequence
@column hstart                    Starting position in the hit peptide sequence
@column hend                      Ending position in the hit peptide sequence
@column score                     Blast score for this HSP
@column evalue                    Blast evalue for this HSP
@column align_length              Alignment length of HSP
@column identical_matches         Blast HSP match score
@column perc_ident                Percent identical matches in the HSP length
@column positive_matches          Blast HSP positive score
@column perc_pos                  Percent positive matches in the HSP length
@column hit_rank                  Rank in blast result
@column cigar_line                Cigar string coding the actual alignment

@see seq_member
@see genome_db
*/

CREATE TABLE peptide_align_feature (

  peptide_align_feature_id    bigint  unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  qmember_id                  int(10) unsigned NOT NULL, # FK seq_member.seq_member_id
  hmember_id                  int(10) unsigned NOT NULL, # FK seq_member.seq_member_id
  qgenome_db_id               int(10) unsigned, # FK genome.genome_id
  hgenome_db_id               int(10) unsigned, # FK genome.genome_id
  qstart                      int(10) DEFAULT 0 NOT NULL,
  qend                        int(10) DEFAULT 0 NOT NULL,
  hstart                      int(11) DEFAULT 0 NOT NULL,
  hend                        int(11) DEFAULT 0 NOT NULL,
  score                       double(16,4) DEFAULT 0.0000 NOT NULL,
  evalue                      double,
  align_length                int(10),
  identical_matches           int(10),
  perc_ident                  int(10),
  positive_matches            int(10),
  perc_pos                    int(10),
  hit_rank                    int(10),
  cigar_line                  mediumtext,

#  FOREIGN KEY (qmember_id) REFERENCES seq_member(seq_member_id),
#  FOREIGN KEY (hmember_id) REFERENCES seq_member(seq_member_id),
#  FOREIGN KEY (qgenome_db_id) REFERENCES genome_db(genome_db_id),
#  FOREIGN KEY (hgenome_db_id) REFERENCES genome_db(genome_db_id),

  PRIMARY KEY (peptide_align_feature_id)
#  KEY hmember_hit (hmember_id, hit_rank)

#  KEY qmember_id  (qmember_id),
#  KEY hmember_id  (hmember_id),
#  KEY hmember_qgenome  (hmember_id, qgenome_db_id),
#  KEY qmember_hgenome  (qmember_id, hgenome_db_id)
) MAX_ROWS = 100000000 AVG_ROW_LENGTH = 133 COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table family
@desc  This table contains all the group homologies found. There are several family_member entries for each family entry.
@colour   #1E90FF

@example   The following query retrieves families with "CATHELICIDIN" description and description_score of 100
    @sql                                SELECT * FROM family WHERE description like '%CATHELICIDIN%' AND description_score = 100;

@column family_id                    Internal unique ID
@column stable_id                    Stable family ID. NOTE: stable_id are currently not stable. We are working in getting IDs stable between releases.
@column version                      Version of the stable_id (may only change when members migrate between this family and another one; stays the same otherwise)
@column method_link_species_set_id   External reference to method_link_species_set_id in the method_link_species_set table
@column description                  Description of the family as found using the Longest Common String (LCS) of the descriptions of the member proteins.
@column description_score            Scores the accuracy of the annotation (max. 100)

@see method_link_species_set
*/

CREATE TABLE family (
  family_id                   int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  stable_id                   varchar(40) NOT NULL, # unique stable id, e.g. 'ENSFM'.'0053'.'1234567890'
  version                     INT UNSIGNED NOT NULL,# version of the stable_id (changes only when members move to/from existing families)
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK method_link_species_set.method_link_species_set_id
  description                 varchar(255),
  description_score           double,

  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY (family_id),
  UNIQUE (stable_id),
  KEY (method_link_species_set_id),
  KEY (description)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table family_member
@desc  This table contains the proteins corresponding to protein family relationship found. There are several family_member entries for each family entry
@colour   #1E90FF

@example      The following query refers to the four members of the protein family 54177. The proteins can be retieved using the member_ids. The multiple alignment can be restored using the cigar_lines.
    @sql                   SELECT * FROM family_member WHERE family_id = 29739;

@column family_id      External reference to family_id in the @link family table
@column seq_member_id  External reference to the seq_member_id in the @link seq_member table
@column cigar_line     Internal description of the multiple alignment (see the description in the @link homology_member table)

@see family
@see seq_member
*/

CREATE TABLE family_member (
  family_id                   int(10) unsigned NOT NULL, # FK family.family_id
  seq_member_id               int(10) unsigned NOT NULL, # FK seq_member.seq_member_id
  cigar_line                  mediumtext,

  FOREIGN KEY (family_id) REFERENCES family(family_id),
  FOREIGN KEY (seq_member_id) REFERENCES seq_member(seq_member_id),

  PRIMARY KEY family_seq_member_id (family_id,seq_member_id),
  KEY (family_id),
  KEY (seq_member_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;



/**
@table gene_align
@desc  This table stores information about alignments for members
@colour   #1E90FF

@column gene_align_id          Internal unique ID
@column seq_type               Short description of this alignment
@column aln_method             The alignment method used
@column aln_length             The total length of the alignment

@see seq_member
@see gene_align_member
*/
CREATE TABLE gene_align (
         gene_align_id         int(10) unsigned NOT NULL AUTO_INCREMENT,
	 seq_type              varchar(40),
	 aln_method            varchar(40) NOT NULL DEFAULT '',
	 aln_length            int(10) NOT NULL DEFAULT 0,

  PRIMARY KEY (gene_align_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table gene_align_member
@desc  This table allows certain nodes (leaves) to have aligned protein member_scores attached to them
@colour   #1E90FF

@column gene_align_id      External reference to gene_align_id in the @link gene_align table
@column seq_member_id          External reference to seq_member_id in the @link seq_member table in many-to-1 relation (single member per node)
@column cigar_line         String with the alignment score values

@see seq_member
@see gene_align
*/
CREATE TABLE gene_align_member (
       gene_align_id         int(10) unsigned NOT NULL,
       seq_member_id         int(10) unsigned NOT NULL,
       cigar_line            mediumtext,

  FOREIGN KEY (gene_align_id) REFERENCES gene_align(gene_align_id),
  FOREIGN KEY (seq_member_id) REFERENCES seq_member(seq_member_id),

  PRIMARY KEY (gene_align_id,seq_member_id),
  KEY seq_member_id (seq_member_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table gene_tree_node
@desc  This table holds the gene tree data structure, such as root, relation between parent and child, leaves, etc... In our data structure, all the trees of a given clusterset are arbitrarily connected to the same root. This eases to store and query in the same database the data from independant tree building analysis. Hence the "biological roots" of the trees are the children nodes of the main clusterset root. See the examples below.
@colour   #1E90FF

@example    The following query returns the root nodes of the independant protein trees stored in the database
     @sql                           SELECT gtn.node_id FROM gene_tree_node gtn LEFT JOIN gene_tree_root gtr ON (gtn.parent_id = gtr.root_id) WHERE gtr.tree_type = 'clusterset' AND gtr.member_type = 'protein' LIMIT 10;

@column node_id                Internal unique ID
@column parent_id              Link to the parent node
@column root_id                Link to the root node
@column left_index             Internal index. See above
@column right_index            Internal index. See above
@column distance_to_parent     Phylogenetic distance between this node and its parent
@column seq_member_id          External reference to seq_member_id in the @link seq_member table to allow linkage from trees to peptides/transcripts.
@see gene_tree_root
@see seq_member
@see gene_tree_node_attr
@see gene_tree_node_tag
*/

CREATE TABLE gene_tree_node (
  node_id                         int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  parent_id                       int(10) unsigned,
  root_id                         int(10) unsigned,
  left_index                      int(10) NOT NULL DEFAULT 0,
  right_index                     int(10) NOT NULL DEFAULT 0,
  distance_to_parent              double default 1.0 NOT NULL,
  seq_member_id                   int(10) unsigned,

  FOREIGN KEY (root_id) REFERENCES gene_tree_node(node_id),
  FOREIGN KEY (parent_id) REFERENCES gene_tree_node(node_id),
  FOREIGN KEY (seq_member_id) REFERENCES seq_member(seq_member_id),

  PRIMARY KEY (node_id),
  KEY parent_id (parent_id),
  KEY seq_member_id (seq_member_id),
  KEY root_id (root_id),
  KEY root_id_left_index (root_id,left_index)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table gene_tree_root
@desc  Header table for gene_trees. The database is able to contain several sets of trees computed on the same genes. We call these analysis "clustersets" and they can be distinguished with the clusterset_id field. Traditionally, the compara databases have contained only one clusterset (clusterset_id=1), but currently (starting on release 66) we have at least 2 (one for protein trees and one for ncRNA trees). See the examples below.
@colour   #1E90FF

@example   The following query retrieves all the node_id of the current clustersets
     @sql                                  SELECT * from gene_tree_root where tree_type = 'clusterset';
@example   To get the number of trees of each type
     @sql                                  SELECT member_type, tree_type, COUNT(*) FROM gene_tree_root GROUP BY member_type, tree_type;

@column root_id     	              Internal unique ID
@column member_type                   The type of members used in the tree
@column tree_type                     The type of the tree
@column clusterset_id                 Name for the set of clusters/trees
@column method_link_species_set_id    External reference to method_link_species_set_id in the method_link_species_set table
@column gene_align_id                 External reference to gene_align_id in the @link gene_align table
@column ref_root_id                   External reference to default (merged) root_id for this tree
@column stable_id                     Unique, stable ID for the tree (follows the pattern: label(5).release_introduced(4).unique_id(10))
@column version                       Version of the stable ID (changes only when members move to/from existing trees)

@see gene_tree_node
@see gene_tree_root_tag
@see seq_member
@see method_link_species_set
@see gene_align
*/

CREATE TABLE gene_tree_root (
    root_id                         INT(10) UNSIGNED NOT NULL,
    member_type                     ENUM('protein', 'ncrna') NOT NULL,
    tree_type                       ENUM('clusterset', 'supertree', 'tree') NOT NULL,
    clusterset_id                   VARCHAR(20) NOT NULL DEFAULT 'default',
    method_link_species_set_id      INT(10) UNSIGNED NOT NULL,
    gene_align_id                   INT(10) UNSIGNED,
    ref_root_id                     INT(10) UNSIGNED,
    stable_id                       VARCHAR(40),            # unique stable id, e.g. 'ENSGT'.'0053'.'1234567890'
    version                         INT UNSIGNED,           # version of the stable_id (changes only when members move to/from existing trees)

    FOREIGN KEY (root_id) REFERENCES gene_tree_node(node_id),
    FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
    FOREIGN KEY (gene_align_id) REFERENCES gene_align(gene_align_id),
    FOREIGN KEY (ref_root_id) REFERENCES gene_tree_root(root_id),

    PRIMARY KEY (root_id ),
    UNIQUE KEY ( stable_id ),
    KEY ref_root_id (ref_root_id),
    KEY (tree_type)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table gene_tree_node_tag
@desc  This table contains several tag/value data attached to node_ids
@colour   #1E90FF

@column node_id        External reference to node_id in the @link gene_tree_node table
@column tag            Tag name for the tag/value pair
@column value          Value for the tag/value pair

@see gene_tree_node
@see gene_tree_node_attr
*/

CREATE TABLE gene_tree_node_tag (
  node_id                int(10) unsigned NOT NULL,
  tag                    varchar(50) NOT NULL,
  value                  mediumtext NOT NULL,

  FOREIGN KEY (node_id) REFERENCES gene_tree_node(node_id),

  KEY node_id_tag (node_id, tag),
  KEY (node_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table gene_tree_root_tag
@desc  This table contains several tag/value data for gene_tree_roots
@colour   #1E90FF

@column root_id   External reference to root_id in the @link gene_tree_root table
@column tag       Tag name for the tag/value pair
@column value     Value for the tag/value pair

@see gene_tree_root
*/

CREATE TABLE gene_tree_root_tag (
  root_id                int(10) unsigned NOT NULL,
  tag                    varchar(50) NOT NULL,
  value                  mediumtext NOT NULL,

  FOREIGN KEY (root_id) REFERENCES gene_tree_root(root_id),

  KEY root_id_tag (root_id, tag),
  KEY (root_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table gene_tree_node_attr
@desc  This table contains several gene tree attributes data attached to node_ids
@colour   #1E90FF

@column node_id                               External reference to node_id in the @link gene_tree_node table
@column node_type                             Type of homology
@column species_tree_node_id                  Taxon / Ancestral species annotation (given as the node_id in the species tree)
@column bootstrap                             The bootstrap value of the node in the tree
@column duplication_confidence_score          The calculated confidence score for duplications

@see gene_tree_node
@see gene_tree_node_tag
*/

CREATE TABLE gene_tree_node_attr (
  node_id                         INT(10) UNSIGNED NOT NULL,
  node_type                       ENUM("duplication", "dubious", "speciation", "gene_split"),
  species_tree_node_id            INT(10) UNSIGNED,
  bootstrap                       TINYINT UNSIGNED,
  duplication_confidence_score    DOUBLE(5,4),

  FOREIGN KEY (species_tree_node_id) REFERENCES species_tree_node(node_id),
  FOREIGN KEY (node_id) REFERENCES gene_tree_node(node_id),

  PRIMARY KEY (node_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table hmm_profile
@desc  This table stores different HMM-based profiles used and produced by gene trees
@colour   #1E90FF

@column model_id              Model ID of the profile. Can be the external ID in case of imported models
@column name                  Name of the model
@column type                  Short description of the origin of the profile
@column compressed_profile    The HMM profile, compressed with zlib. It can be decompressed with the MySQL function UNCOMPRESS()
@column consensus             The consensus sequence derived from the profile

*/

-- Later
-- @column hmm_id                The internal numeric ID that uniquely identifies the model in the database
--  hmm_id                      int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
--  PRIMARY KEY (hmm_id),
--  UNIQUE KEY (model_id,type)

CREATE TABLE hmm_profile (
  model_id                    varchar(40) NOT NULL,
  name                        varchar(40),
  type                        varchar(40) NOT NULL,
  compressed_profile          mediumblob,
  consensus                   mediumtext,

  PRIMARY KEY (model_id,type)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table hmm_annot
@desc  This table stores the HMM annotation of the seq_members
@colour   #1E90FF

@column seq_member_id         External reference to a seq_member_id in the @link seq_member table
@column model_id              External reference to the internal numeric ID of a HMM profile in @link hmm_profile
@column evalue                The e-value of the hit

*/


-- Later
--  @column hmm_id                External reference to the internal numeric ID of a HMM profile in @link hmm_profile
--   hmm_id                     int(10) unsigned NOT NULL, # FK hmm_profile.hmm_id
--  FOREIGN KEY (hmm_id)        REFERENCES hmm_profile (hmm_id),
--   KEY (hmm_id)

CREATE TABLE hmm_annot (
  seq_member_id              int(10) unsigned NOT NULL, # FK homology.homology_id
  model_id                   varchar(40) DEFAULT NULL,
  evalue                     float,

  FOREIGN KEY (seq_member_id) REFERENCES seq_member  (seq_member_id),

  PRIMARY KEY (seq_member_id),
  KEY (model_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;



/**
@table hmm_curated_annot
@desc  This table stores the curated / forced HMM annotation of the seq_members
@colour   #1E90FF

@column seq_member_stable_id  External reference to a seq_member_id in the @link seq_member table
@column model_id              External reference to the internal numeric ID of a HMM profile in @link hmm_profile
@column library_version       Name of the HMM library against the curation has been done
@column annot_date            When did the curation happened
@column reason                Why are we forcing this curation

*/

CREATE TABLE hmm_curated_annot (
  seq_member_stable_id       varchar(40) NOT NULL,
  model_id                   varchar(40) DEFAULT NULL,
  library_version            varchar(40) NOT NULL,
  annot_date                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reason                     MEDIUMTEXT,

  PRIMARY KEY (seq_member_stable_id),
  KEY (model_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table homology
@desc  This table contains all the genomic homologies. There are two homology_member entries for each homology entry for now, but both the schema and the API can handle more than just pairwise relationships. <br />dN, dS, N, S and lnL are statistical values given by the codeml program of the <a href="http://abacus.gene.ucl.ac.uk/software/paml.html">Phylogenetic Analysis by Maximum Likelihood (PAML)</a> package.
@colour   #1E90FF

@example    The following query defines a pair of paralogous xenopous genes. See @link homology_member for more details
    @sql    SELECT homology.* FROM homology JOIN method_link_species_set USING (method_link_species_set_id) WHERE name="X.tro paralogues" LIMIT 1;

@column homology_id                    Unique internal ID
@column method_link_species_set_id     External reference to method_link_species_set_id in the @link method_link_species_set table
@column description                    A normalized, short description of the homology relationship
@column is_tree_compliant              Whether the homology is fully compliant with the tree and the definition of orthology / paralogy
@column dn                             The non-synonymous mutation rate
@column ds                             The synonymous mutation rate
@column n                              The estimated number of non-synonymous mutations
@column s                              The estimated number of synonymous mutations
@column lnl                            The negative log likelihood of the estimation
@column species_tree_node_id           The node_id of the species-tree node to which the homology is attached
@column gene_tree_node_id              The node_id of the gene-tree node from which the homology is derived
@column gene_tree_root_id              The root_id of the gene tree from which the homology is derived

@example    See species_names that participate in this particular homology entry
    @sql    SELECT homology_id, description, GROUP_CONCAT(genome_db.name) AS species FROM homology JOIN method_link_species_set USING (method_link_species_set_id) JOIN species_set USING (species_set_id) JOIN genome_db USING(genome_db_id) WHERE method_link_id=201 AND homology_id<5000000  GROUP BY homology_id LIMIT 4;

@see homology_member
@see method_link_species_set
*/

CREATE TABLE homology (
  homology_id                 int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK method_link_species_set.method_link_species_set_id
  description                 ENUM('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','gene_split','between_species_paralog','alt_allele','homoeolog_one2one','homoeolog_one2many','homoeolog_many2many'),
  is_tree_compliant           tinyint(1) NOT NULL DEFAULT 0,
  dn                          float(10,5),
  ds                          float(10,5),
  n                           float(10,1),
  s                           float(10,1),
  lnl                         float(10,3),
  species_tree_node_id        int(10) unsigned,
  gene_tree_node_id           int(10) unsigned,
  gene_tree_root_id           int(10) unsigned,

  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  FOREIGN KEY (species_tree_node_id) REFERENCES species_tree_node(node_id),
  FOREIGN KEY (gene_tree_node_id) REFERENCES gene_tree_node(node_id),
  FOREIGN KEY (gene_tree_root_id) REFERENCES gene_tree_root(root_id),

  PRIMARY KEY (homology_id),
  KEY (method_link_species_set_id),
  KEY (species_tree_node_id),
  KEY (gene_tree_node_id),
  KEY (gene_tree_root_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table homology_member
@desc  This table contains the sequences corresponding to every genomic homology relationship found. There are two homology_member entries for each pairwise homology entry. As written in the homology table section, both schema and API can deal with more than pairwise relationships.<br />
The original alignment is not stored but it can be retrieved using the cigar_line field and the original sequences. The cigar line defines the sequence of matches or mismatches and deletions in the alignment.
<ul>
  <li><b>First peptide sequence</b>: SERCQVVVISIGPISVLSMILDFY</li>
  <li><b>Second peptide sequence</b>: SDRCQVLVISILSMIGLDFY</li>
  <li><b>First corresponding cigar line</b>: 20MD4M</li>
  <li><b>Second corresponding cigar line</b>: 11M5D9M</li>
</ul>
The alignment will be:<br />
<table class="spreadsheet">
  <caption>Example of alignment reconstruction</caption>
  <tbody>
    <tr>
      <th>First peptide cigar line</th>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>D</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
    </tr>
    <tr>
      <th>First aligned peptide</th>
      <td>S</td>
      <td>E</td>
      <td>R</td>
      <td>C</td>
      <td>Q</td>
      <td>V</td>
      <td>V</td>
      <td>V</td>
      <td>I</td>
      <td>S</td>
      <td>I</td>
      <td>G</td>
      <td>P</td>
      <td>I</td>
      <td>S</td>
      <td>V</td>
      <td>L</td>
      <td>S</td>
      <td>M</td>
      <td>I</td>
      <td>-</td>
      <td>L</td>
      <td>D</td>
      <td>F</td>
      <td>Y</td>
    </tr>
    <tr>
      <th>Second aligned peptide</th>
      <td>S</td>
      <td>D</td>
      <td>R</td>
      <td>C</td>
      <td>Q</td>
      <td>V</td>
      <td>L</td>
      <td>V</td>
      <td>I</td>
      <td>S</td>
      <td>I</td>
      <td>-</td>
      <td>-</td>
      <td>-</td>
      <td>-</td>
      <td>-</td>
      <td>L</td>
      <td>S</td>
      <td>M</td>
      <td>I</td>
      <td>G</td>
      <td>L</td>
      <td>D</td>
      <td>F</td>
      <td>Y</td>
    </tr>
    <tr>
      <th>Second peptide cigar line</th>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>D</td>
      <td>D</td>
      <td>D</td>
      <td>D</td>
      <td>D</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
      <td>M</td>
    </tr>
  </tbody>
</table>
@colour   #1E90FF

@example    The following query refers to the two homologue sequences from the first xenopus' paralogy object. Gene and peptide sequence of the second homologue can retrieved in the same way.
    @sql    SELECT homology_member.* FROM homology_member JOIN homology USING (homology_id) JOIN method_link_species_set USING (method_link_species_set_id) WHERE name="X.tro paralogues" LIMIT 2;

@column homology_id        External reference to homology_id in the @link homology table
@column gene_member_id     External reference to gene_member_id in the @link gene_member table. Refers to the corresponding "ENSMBLGENE" entry
@column seq_member_id      External reference to seq_member_id in the @link seq_member table. Refers to the corresponding "ENSEMBLPEP" entry
@column cigar_line         An internal description of the alignment. It contains mathces/mismatches (M) and delations (D) and refers to the corresponding seq_member_id sequence
@column perc_cov           Defines the percentage of the peptide which has been aligned
@column perc_id            Defines the percentage of identity between both homologues
@column perc_pos           Defines the percentage of positivity (similarity) between both homologues

@see gene_member
@see seq_member
@see homology
*/

CREATE TABLE homology_member (
  homology_id                 int(10) unsigned NOT NULL, # FK homology.homology_id
  gene_member_id              int(10) unsigned NOT NULL, # FK gene_member.gene_member_id
  seq_member_id               int(10) unsigned, # FK seq_member.seq_member_id
  cigar_line                  mediumtext,
  perc_cov                    tinyint unsigned default 0,
  perc_id                     tinyint unsigned default 0,
  perc_pos                    tinyint unsigned default 0,

  FOREIGN KEY (homology_id) REFERENCES homology(homology_id),
  FOREIGN KEY (gene_member_id) REFERENCES gene_member(gene_member_id),
  FOREIGN KEY (seq_member_id) REFERENCES seq_member(seq_member_id),

  PRIMARY KEY homology_member_id (homology_id,gene_member_id),
  KEY (homology_id),
  KEY (gene_member_id),
  KEY (seq_member_id)
) MAX_ROWS = 300000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table mapping_session
@desc  This table contains one entry per stable_id mapping session (either for Families or for Protein Trees), which contains the type, the date of the mapping, and which releases were linked together. A single mapping_session is the event when mapping between two given releases for a particular class type ('family' or 'tree') is loaded. The whole event is thought to happen momentarily at 'when_mapped' (used for sorting in historical order).
@colour   #1E90FF

@column mapping_session_id    Internal unique ID
@column type                  Type of stable_ids that were mapped during this session
@column when_mapped           Normally, we use the date of creation of the mapping file being loaded. This prevents the date from chaging even if we accidentally remove the entry and have to re-load it.
@column rel_from              rel.number from which the stable_ids were mapped during this session. rel_from < rel_to
@column rel_to                rel.number to which the stable_ids were mapped during this session. rel_from < rel_to
@column prefix                Prefix
*/

CREATE TABLE mapping_session (
    mapping_session_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    type               ENUM('family', 'tree'),
    when_mapped        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rel_from           INT UNSIGNED,
    rel_to             INT UNSIGNED,
    prefix             CHAR(4) NOT NULL,
    PRIMARY KEY ( mapping_session_id ),
    UNIQUE KEY  ( type, rel_from, rel_to, prefix )

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

/**
@table stable_id_history
@desc  This table keeps the history of stable_id changes from one release to another. The primary key 'object' describes a set of members migrating from stable_id_from to stable_id_to. Their volume (related to the 'shared_size' of the new class) is reflected by the fractional 'contribution' field. Since both stable_ids are listed in the primary key, they are not allowed to be NULLs. We shall treat empty strings as NULLs. If stable_id_from is empty, it means these members are newcomers into the new release. If stable_id_to is empty, it means these previously known members are disappearing in the new release. If both neither stable_id_from nor stable_id_to is empty, these members are truly migrating.
@colour   #1E90FF

@column mapping_session_id    Reference to mapping_session.mapping_session_id. All the stable_ids of a given mapping should have the same session_id
@column stable_id_from        The previous stable ID
@column version_from          The version number of the previous stable ID (specific to each stable ID; not to be confused with the release number)
@column stable_id_to          The new stable ID
@column version_to            The new version number
@column contribution          Percentage of of the new object (tree / family) that comes from the previous one
*/

CREATE TABLE stable_id_history (
    mapping_session_id INT UNSIGNED NOT NULL,
    stable_id_from     VARCHAR(40) NOT NULL DEFAULT '',
    version_from       INT UNSIGNED NULL DEFAULT NULL,
    stable_id_to       VARCHAR(40) NOT NULL DEFAULT '',
    version_to         INT UNSIGNED NULL DEFAULT NULL,
    contribution       FLOAT,

    FOREIGN KEY (mapping_session_id) REFERENCES mapping_session(mapping_session_id),

    PRIMARY KEY ( mapping_session_id, stable_id_from, stable_id_to )

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


/**
@table CAFE_gene_family
@desc  This table holds information about each CAFE gene family
@colour   #1E90FF

@column cafe_gene_family_id     Internal unique ID
@column root_id                 External reference to root_id in the @link species_tree_root table
@column lca_id                  External reference to the lowest common ancestor node in the @link species_tree_node table
@column gene_tree_root_id       External reference to root_id in the @link gene_tree_root table
@column pvalue_avg              The average pvalue for the gene family as reported by CAFE
@column lambdas                 The lambda/s values reported/used by CAFE

@see species_tree_node
@see species_tree_root
@see CAFE_species_gene
*/

CREATE TABLE `CAFE_gene_family` (
  `cafe_gene_family_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `root_id` int(10) unsigned NOT NULL,
  `lca_id` int(10) unsigned NOT NULL,
  `gene_tree_root_id` int(10) unsigned NOT NULL,
  `pvalue_avg` double(5,4) DEFAULT NULL,
  `lambdas` varchar(100) DEFAULT NULL,

  FOREIGN KEY (root_id) REFERENCES species_tree_root(root_id),
  FOREIGN KEY (lca_id) REFERENCES species_tree_node(node_id),
  FOREIGN KEY (gene_tree_root_id) REFERENCES gene_tree_root(root_id),

  PRIMARY KEY (`cafe_gene_family_id`),
  KEY `root_id` (`root_id`),
  KEY `gene_tree_root_id` (`gene_tree_root_id`)
) ENGINE=MyISAM AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;

/**
@table CAFE_species_gene
@desc  This table stores per @link species_tree_node information about expansions/contractions of each @link CAFE_gene_family
@colour   #1E90FF

@column cafe_gene_family_id      External reference to cafe_gene_family_id in the @link CAFE_gene_family table.
@column node_id                  External reference to node_id in the @link species_tree_node table
@column n_members                The number of members for the node as reported by CAFE
@column pvalue                   The pvalue of the node as reported by CAFE
*/

CREATE TABLE `CAFE_species_gene` (
  `cafe_gene_family_id` int(10) unsigned NOT NULL,
  `node_id` int(10) unsigned NOT NULL,
  `n_members` int(4) unsigned NOT NULL,
  `pvalue` double(5,4) DEFAULT NULL,

  FOREIGN KEY (cafe_gene_family_id) REFERENCES CAFE_gene_family(cafe_gene_family_id),
  FOREIGN KEY (node_id) REFERENCES species_tree_node(node_id),

  KEY `cafe_gene_family_id` (`cafe_gene_family_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


# ------------------------ End of CAFE tables --------------------------------------

# Auto add schema version to database (this will override whatever hive puts there)
DELETE FROM meta WHERE meta_key='schema_version';
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'schema_version', '79');

#Add schema type
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'schema_type', 'compara');

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_78_79_a.sql|schema_version');
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_78_79_b.sql|genome_component');

