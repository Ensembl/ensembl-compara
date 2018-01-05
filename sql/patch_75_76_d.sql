-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

# patch_75_76_d.sql
#
# Title: Split member into seq_member and gene_member
#
# Description:
#   First tranforms chr_name into dnafrag_id
#   Split member into seq_member and gene_member


-- We first need to insert the missing dnafrags

ALTER TABLE dnafrag AUTO_INCREMENT=200000000000001;

INSERT INTO dnafrag (length, name, genome_db_id, coord_system_name, is_reference)
SELECT MAX(chr_end), chr_name, member.genome_db_id, "lrg", 0
FROM member LEFT JOIN dnafrag ON member.genome_db_id = dnafrag.genome_db_id AND member.chr_name = dnafrag.name
WHERE chr_name LIKE "LRG%" and dnafrag.name IS NULL
GROUP BY chr_name, member.genome_db_id;

INSERT INTO dnafrag (length, name, genome_db_id, coord_system_name, is_reference)
SELECT MAX(chr_end), chr_name, member.genome_db_id, "unknown", 0
FROM member LEFT JOIN dnafrag ON member.genome_db_id = dnafrag.genome_db_id AND member.chr_name = dnafrag.name
WHERE chr_name IS NOT NULL AND dnafrag.name IS NULL
GROUP BY chr_name, member.genome_db_id;


-- At this stage, all the chr_name are registered in dnafrag

DROP TABLE IF EXISTS gene_member;
CREATE TABLE gene_member (
  gene_member_id              int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  stable_id                   varchar(128) NOT NULL, # e.g. ENSP000001234 or P31946
  version                     int(10) DEFAULT 0,
  source_name                 ENUM('ENSEMBLGENE','EXTERNALGENE') NOT NULL,
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

/*  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id), */

  PRIMARY KEY (gene_member_id),
  UNIQUE KEY (stable_id),
  KEY (taxon_id),
  KEY (dnafrag_id),
  KEY (source_name),
  KEY (canonical_member_id),
  KEY dnafrag_id_start (dnafrag_id,dnafrag_start),
  KEY dnafrag_id_end (dnafrag_id,dnafrag_end)
) MAX_ROWS = 100000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM

AS SELECT
	member_id AS gene_member_id,
	stable_id,
	version,
	source_name,
	taxon_id,
	member.genome_db_id,
	canonical_member_id,
	description,
	dnafrag_id,
	chr_start AS dnafrag_start,
	chr_end AS dnafrag_end,
	chr_strand AS dnafrag_strand,
	display_label,
	IFNULL(families, 0) AS families,
	IFNULL(gene_trees, 0) AS gene_trees,
	IFNULL(gene_gain_loss_trees, 0) AS gene_gain_loss_trees,
	IFNULL(orthologues, 0) AS orthologues,
	IFNULL(paralogues, 0) AS paralogues,
	IFNULL(homoeologues, 0) AS homoeologues
FROM member LEFT JOIN dnafrag ON member.genome_db_id = dnafrag.genome_db_id AND member.chr_name = dnafrag.name LEFT JOIN member_production_counts USING (stable_id)
WHERE source_name = "ENSEMBLGENE";



DROP TABLE IF EXISTS seq_member;
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

/*  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),
  FOREIGN KEY (sequence_id) REFERENCES sequence(sequence_id),
  FOREIGN KEY (gene_member_id) REFERENCES gene_member(gene_member_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id), */

  PRIMARY KEY (seq_member_id),
  UNIQUE KEY (stable_id),
  KEY (taxon_id),
  KEY (dnafrag_id),
  KEY (source_name),
  KEY (sequence_id),
  KEY (gene_member_id),
  KEY dnafrag_id_start (dnafrag_id,dnafrag_start),
  KEY dnafrag_id_end (dnafrag_id,dnafrag_end),
  KEY seq_member_gene_member_id_end (seq_member_id,gene_member_id)
) MAX_ROWS = 100000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM

AS SELECT
	member_id AS seq_member_id,
	stable_id,
	version,
	source_name,
	taxon_id,
	member.genome_db_id,
	sequence_id,
	gene_member_id,
	description,
	dnafrag_id,
	chr_start AS dnafrag_start,
	chr_end AS dnafrag_end,
	chr_strand AS dnafrag_strand,
	display_label
FROM member LEFT JOIN dnafrag ON member.genome_db_id = dnafrag.genome_db_id AND member.chr_name = dnafrag.name
WHERE source_name != "ENSEMBLGENE";


-- -- Let's not delete them at the moment
-- DROP TABLE member;
-- DROP TABLE member_production_counts;

DELETE family_member FROM family_member JOIN member USING (member_id) WHERE source_name = "ENSEMBLGENE";

ALTER TABLE family_member CHANGE COLUMN member_id seq_member_id int(10) unsigned not null;
ALTER TABLE gene_align_member CHANGE COLUMN member_id seq_member_id int(10) unsigned not null;
ALTER TABLE gene_tree_node CHANGE COLUMN member_id seq_member_id int(10) unsigned;
ALTER TABLE homology_member CHANGE COLUMN member_id gene_member_id int(10) unsigned not null, CHANGE COLUMN peptide_member_id seq_member_id int(10) unsigned;
ALTER TABLE member_xref CHANGE COLUMN member_id gene_member_id int(10) unsigned not null;
ALTER TABLE other_member_sequence CHANGE COLUMN member_id seq_member_id int(10) unsigned not null;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_75_76_d.sql|gene_member_seq_member');

