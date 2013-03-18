-- Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


CREATE TABLE seq_member (
  seq_member_id               int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  stable_id                   varchar(128) NOT NULL, # e.g. ENSP000001234 or P31946
  version                     int(10) DEFAULT 0,
  source_name                 ENUM('ENSEMBLPEP','Uniprot/SPTREMBL','Uniprot/SWISSPROT','ENSEMBLTRANS','EXTERNALCDS') NOT NULL,
  taxon_id                    int(10) unsigned NOT NULL, # FK taxon.taxon_id
  genome_db_id                int(10) unsigned, # FK genome_db.genome_db_id
  sequence_id                 int(10) unsigned, # FK sequence.sequence_id
  gene_member_id              int(10) unsigned, # FK gene_member.gene_member_id
  description                 text DEFAULT NULL,
  chr_name                    char(40),
  chr_start                   int(10),
  chr_end                     int(10),
  chr_strand                  tinyint(1) NOT NULL,
  display_label               varchar(128) default NULL,

  PRIMARY KEY (seq_member_id),
  UNIQUE source_stable_id (stable_id, source_name),
  KEY (stable_id),
  KEY (source_name),
  KEY (sequence_id),
  KEY (gene_member_id),
  KEY gdb_name_start_end (genome_db_id,chr_name,chr_start,chr_end)
) MAX_ROWS = 100000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM

AS SELECT
	member_id AS seq_member_id,
	stable_id,
	version,
	source_name,
	taxon_id,
	genome_db_id,
	sequence_id,
	gene_member_id,
	description,
	chr_name,
	chr_start,
	chr_end,
	chr_strand,
	display_label
FROM member
WHERE source_name != "ENSEMBLGENE";



CREATE TABLE gene_member (
  gene_member_id              int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  stable_id                   varchar(128) NOT NULL, # e.g. ENSP000001234 or P31946
  version                     int(10) DEFAULT 0,
  source_name                 ENUM('ENSEMBLGENE') NOT NULL,
  taxon_id                    int(10) unsigned NOT NULL, # FK taxon.taxon_id
  genome_db_id                int(10) unsigned, # FK genome_db.genome_db_id
  canonical_member_id         int(10) unsigned, # FK seq_member.seq_member_id
  description                 text DEFAULT NULL,
  chr_name                    char(40),
  chr_start                   int(10),
  chr_end                     int(10),
  chr_strand                  tinyint(1) NOT NULL,
  display_label               varchar(128) default NULL,

  PRIMARY KEY (gene_member_id),
  UNIQUE source_stable_id (stable_id, source_name),
  KEY (stable_id),
  KEY (source_name),
  KEY (canonical_member_id),
  KEY gdb_name_start_end (genome_db_id,chr_name,chr_start,chr_end)
) MAX_ROWS = 100000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM

AS SELECT
	member_id AS gene_member_id,
	stable_id,
	version,
	source_name,
	taxon_id,
	genome_db_id,
	canonical_member_id,
	description,
	chr_name,
	chr_start,
	chr_end,
	chr_strand,
	display_label
FROM member
WHERE source_name = "ENSEMBLGENE";


DROP TABLE member;


ALTER TABLE family_member CHANGE COLUMN member_id seq_member_id int(10) unsigned not null;
ALTER TABLE gene_align_member CHANGE COLUMN member_id seq_member_id int(10) unsigned not null;
ALTER TABLE gene_tree_node CHANGE COLUMN member_id seq_member_id int(10) unsigned;
ALTER TABLE homology_member CHANGE COLUMN member_id gene_member_id int(10) unsigned not null, CHANGE COLUMN peptide_member_id seq_member_id int(10) unsigned;
ALTER TABLE member_xref CHANGE COLUMN member_id gene_member_id int(10) unsigned not null;
ALTER TABLE other_member_sequence CHANGE COLUMN member_id seq_member_id int(10) unsigned not null;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_75_76_d.sql|gene_member_seq_member');

