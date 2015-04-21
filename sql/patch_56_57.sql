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

-- Updating the schema version
UPDATE meta SET meta_value = 57 where meta_key = "schema_version";

-- a partitioned table cannot have any keys but the primary key
ALTER TABLE peptide_align_feature DROP KEY qgenome_db_id;
ALTER TABLE peptide_align_feature DROP KEY hgenome_db_id;
ALTER TABLE peptide_align_feature DROP KEY analysis_id;
ALTER TABLE peptide_align_feature DROP KEY qmember_id;
ALTER TABLE peptide_align_feature DROP KEY hmember_id;
ALTER TABLE peptide_align_feature DROP KEY hmember_qgenome;
ALTER TABLE peptide_align_feature DROP KEY qmember_hgenome;

-- this table is used for production only
DROP TABLE peptide_align_feature_prod;

--   This table holds the sequence exon boundaries information
CREATE TABLE sequence_exon_bounded (
  sequence_exon_bounded_id    int(10) unsigned NOT NULL auto_increment, # unique internal id
  member_id                   int(10) unsigned NOT NULL, # unique internal id
  length                      int(10) NOT NULL,
  sequence_exon_bounded       longtext NOT NULL,

  FOREIGN KEY (member_id) REFERENCES member(member_id),

  PRIMARY KEY (sequence_exon_bounded_id),
  KEY (member_id),
  KEY sequence_exon_bounded (sequence_exon_bounded(18))
);

# modifications to be applied to pre-57 databases to bring them to rel-57 state


## ---------------------renaming group_id into node_id in genomic_align_group table:
#
ALTER TABLE genomic_align_group DROP KEY genomic_align_id;
ALTER TABLE genomic_align_group DROP COLUMN type;
ALTER TABLE genomic_align_group CHANGE group_id node_id bigint unsigned NOT NULL AUTO_INCREMENT;

## The following two lines only "rename" a key, which is unlikely to be needed, but takes A LOT of time to complete:
#
#ALTER TABLE genomic_align_group ADD KEY node_id(node_id);
#ALTER TABLE genomic_align_group DROP KEY group_id;

ALTER TABLE genomic_align_group ADD UNIQUE KEY genomic_align_id(genomic_align_id);


## ---------------------add new keys for speeding things up:
#
ALTER TABLE genomic_align ADD KEY (method_link_species_set_id);



## --------------------making dnafrag_id bigint everywhere:
#
ALTER TABLE constrained_element MODIFY COLUMN dnafrag_id bigint(20) unsigned NOT NULL;
ALTER TABLE dnafrag             MODIFY COLUMN dnafrag_id bigint(20) unsigned NOT NULL AUTO_INCREMENT;
ALTER TABLE dnafrag_region      MODIFY COLUMN dnafrag_id bigint(20) unsigned NOT NULL DEFAULT '0';
ALTER TABLE genomic_align       MODIFY COLUMN dnafrag_id bigint(20) unsigned NOT NULL DEFAULT '0';


## --------------------widening some analysis fields (Andy, you should have warned Compara and added these to the patch as well) :
#
ALTER TABLE analysis MODIFY COLUMN db_file      varchar(255);
ALTER TABLE analysis MODIFY COLUMN program      varchar(255);
ALTER TABLE analysis MODIFY COLUMN program_file varchar(255);


## ------------------- subset and subset_member tables are now becoming a part of the release:
#
CREATE TABLE subset (
 subset_id      int(10) NOT NULL auto_increment,
 description    varchar(255),
 dump_loc       varchar(255),

 PRIMARY KEY (subset_id),
 UNIQUE (description)
);
#
CREATE TABLE subset_member (
 subset_id   int(10) NOT NULL,
 member_id   int(10) NOT NULL,

 KEY (member_id),
 UNIQUE subset_member_id (subset_id, member_id)
);

## ---------------------- Used to populate subset member with a dummy set of data
insert into subset( subset_id, description ) values ( 1, 'DUMMY' );
insert into subset_member select 1, member_id from member;


## ----------------------  This table holds the sequence cds information
#
CREATE TABLE sequence_cds (
  sequence_cds_id             int(10) unsigned NOT NULL auto_increment, # unique internal id
  member_id                   int(10) unsigned NOT NULL, # unique internal id
  length                      int(10) NOT NULL,
  sequence_cds                longtext NOT NULL,

  FOREIGN KEY (member_id) REFERENCES member(member_id),

  PRIMARY KEY (sequence_cds_id),
  KEY (member_id),
  KEY sequence_cds (sequence_cds(64))
);


## ---------------------- Left-Right indices' offsets
#
CREATE TABLE lr_index_offset (
        table_name  varchar(64) NOT NULL,
        lr_index    int(10) unsigned NOT NULL,

        PRIMARY KEY (table_name)
);

## ---------------------- species tags table structure
#
CREATE TABLE species_set_tag (
  species_set_id              int(10) unsigned NOT NULL, # FK species_set.species_set_id
  tag                         varchar(50) DEFAULT NULL,
  value                       mediumtext,

  # FOREIGN KEY (species_set_id) REFERENCES species_set(species_set_id),

  UNIQUE KEY tag_species_set_id (species_set_id,tag)
);

