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

# Updating the schema version
UPDATE meta SET meta_value = 65 where meta_key = "schema_version";

# Not default in genome_db
ALTER TABLE genome_db MODIFY COLUMN taxon_id INT(10) UNSIGNED NOT NULL;

# No autoincrement in genomic_align_group.node_id
ALTER TABLE genomic_align_group MODIFY COLUMN node_id BIGINT(20) UNSIGNED NOT NULL;

# Add 'projection_unchanged','projection_altered' options (enum) in homology.description
ALTER TABLE homology MODIFY COLUMN description ENUM('ortholog_one2one','apparent_ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','putative_gene_split','contiguous_gene_split','between_species_paralog','possible_ortholog','UBRH','BRH','MBRH','RHS','projection_unchanged','projection_altered') DEFAULT NULL;

# Add ENSEMBLPROJ option (enum) in member.source_name
ALTER TABLE member MODIFY COLUMN source_name ENUM('ENSEMBLGENE','ENSEMBLPEP','Uniprot/SPTREMBL','Uniprot/SWISSPROT','ENSEMBLTRANS','EXTERNALCDS','ENSEMBLPROJ') NOT NULL;

# Create the new nc_tree_attr:
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `nc_tree_attr` (
`node_id` int(10) unsigned NOT NULL,
`duplication` tinyint(3) unsigned DEFAULT NULL,
`taxon_id` int(10) unsigned DEFAULT NULL,
`taxon_name` varchar(255) DEFAULT NULL,
`bootstrap` tinyint(3) unsigned DEFAULT NULL,
`duplication_confidence_score` double(5,4) DEFAULT NULL,
`species_intersection_score` tinyint(3) unsigned DEFAULT NULL,
`acc_name` varchar(50) DEFAULT NULL,
`node_type` enum('duplication','dubious','speciation') DEFAULT NULL,
PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

# Populate the new nc_tree_attr table:
INSERT INTO nc_tree_attr (node_id, duplication) SELECT nc_tree_tag.node_id, nc_tree_tag.value from nc_tree_tag where tag = 'Duplication';
UPDATE nc_tree_attr, nc_tree_tag SET nc_tree_attr.taxon_id = nc_tree_tag.value WHERE nc_tree_tag.tag = 'taxon_id' AND nc_tree_tag.node_id = nc_tree_attr.node_id;
UPDATE nc_tree_attr, nc_tree_tag SET nc_tree_attr.taxon_name = nc_tree_tag.value WHERE nc_tree_tag.tag = 'taxon_name' AND nc_tree_tag.node_id = nc_tree_attr.node_id;
UPDATE nc_tree_attr, nc_tree_tag SET nc_tree_attr.bootstrap = nc_tree_tag.value WHERE nc_tree_tag.tag = 'Bootstrap' AND nc_tree_tag.node_id = nc_tree_attr.node_id;
UPDATE nc_tree_attr, nc_tree_tag SET nc_tree_attr.duplication_confidence_score = nc_tree_tag.value WHERE nc_tree_tag.tag = 'duplication_confidence_score' AND nc_tree_tag.node_id = nc_tree_attr.node_id;
UPDATE nc_tree_attr, nc_tree_tag SET nc_tree_attr.species_intersection_score = nc_tree_tag.value WHERE nc_tree_tag.tag = 'species_intersection_score' AND nc_tree_tag.node_id = nc_tree_attr.node_id;
UPDATE nc_tree_attr SET node_type = 'speciation' WHERE duplication=0;
UPDATE nc_tree_attr SET node_type = 'duplication' WHERE duplication=1;
UPDATE nc_tree_attr JOIN nc_tree_tag USING (node_id) SET node_type = 'dubious' WHERE duplication=1 AND tag="dubious_duplication";
INSERT INTO nc_tree_attr (node_id, acc_name) SELECT node_id, value FROM nc_tree_tag WHERE nc_tree_tag.tag = 'acc_name';
DELETE FROM nc_tree_tag WHERE tag IN ('acc_name', 'Duplication', 'Bootstrap', 'taxon_id', 'taxon_name', 'duplication_confidence_score', 'species_intersection_score');

# nc_tree_node.parent_id and nc_tree_node.root_id defaults to NULL
ALTER TABLE nc_tree_node MODIFY COLUMN parent_id int(10) unsigned DEFAULT NULL, MODIFY COLUMN root_id int(10) unsigned DEFAULT NULL;

# keys in nc_tree_node have changed
ALTER TABLE nc_tree_node DROP KEY `root_id`;
ALTER TABLE nc_tree_node DROP KEY `right_index`;
ALTER TABLE nc_tree_node DROP KEY `left_index`;
ALTER TABLE nc_tree_node ADD KEY `root_id` (`root_id`,`left_index`);
ALTER TABLE nc_tree_node ADD KEY `root_id_2` (`root_id`, `right_index`);

# nc_tree_tag.tag and nc_tree_tag.value cannot be NULL
ALTER TABLE nc_tree_tag MODIFY COLUMN `tag` varchar(50) NOT NULL, MODIFY COLUMN `value` mediumtext NOT NULL;

# changes in keys in nc_tree_tag
ALTER TABLE nc_tree_tag DROP KEY `tag_node_id`;
ALTER TABLE nc_tree_tag ADD KEY `node_id_tag` (`node_id`,`tag`);
ALTER TABLE nc_tree_tag ADD KEY `tag_node_id` (`tag`,`node_id`);

# New table protein_tree_attr
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `protein_tree_attr` (
`node_id` int(10) unsigned NOT NULL,
`node_type` enum('duplication','dubious','speciation','gene_split') DEFAULT NULL,
`taxon_id` int(10) unsigned DEFAULT NULL,
`taxon_name` varchar(255) DEFAULT NULL,
`bootstrap` tinyint(3) unsigned DEFAULT NULL,
`duplication_confidence_score` double(5,4) DEFAULT NULL,
`tree_support` set('phyml_nt','nj_ds','phyml_aa','nj_dn','nj_mm') DEFAULT NULL,
PRIMARY KEY (`node_id`),
KEY `taxon_id` (`taxon_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

# Populate the new table
INSERT INTO protein_tree_attr (node_id, taxon_id) SELECT protein_tree_tag.node_id, protein_tree_tag.value from protein_tree_tag where tag = 'taxon_id';
UPDATE protein_tree_attr JOIN protein_tree_tag USING (node_id) SET taxon_name = value WHERE tag = 'taxon_name';
UPDATE protein_tree_attr JOIN protein_tree_tag USING (node_id) SET bootstrap = value WHERE tag = 'Bootstrap';
UPDATE protein_tree_attr JOIN protein_tree_tag USING (node_id) SET duplication_confidence_score = value WHERE tag = 'duplication_confidence_score';
UPDATE protein_tree_attr JOIN protein_tree_tag USING (node_id) SET node_type = 'speciation' WHERE tag = 'Duplication' AND value = 0;
UPDATE protein_tree_attr JOIN protein_tree_tag USING (node_id) SET node_type = 'duplication' WHERE tag = 'Duplication' AND value >= 1;
UPDATE protein_tree_attr JOIN protein_tree_tag USING (node_id) SET node_type = 'dubious' WHERE tag = 'dubious_duplication';

UPDATE protein_tree_attr SET duplication_confidence_score=0 WHERE node_type="dubious";
UPDATE protein_tree_attr JOIN protein_tree_tag USING (node_id) JOIN protein_tree_node USING (node_id) SET node_type="gene_split" WHERE tag='Gene_split' AND right_index-left_index=5;

DELETE protein_tree_tag FROM protein_tree_tag JOIN protein_tree_node USING (node_id)  WHERE tag='Gene_split' AND right_index-left_index=5;
/* adding species_intersection_score */
DELETE FROM protein_tree_tag WHERE tag IN ('taxon_id', 'taxon_name', 'Bootstrap', 'duplication_confidence_score', 'Duplication', 'dubious_duplication', 'species_intersection_score');


# Changes in protein_tree_node
ALTER TABLE protein_tree_node MODIFY COLUMN `parent_id` int(10) unsigned DEFAULT NULL, MODIFY COLUMN `root_id` int(10) unsigned DEFAULT NULL;

ALTER TABLE protein_tree_node DROP KEY `root_id`;
ALTER TABLE protein_tree_node DROP KEY `left_index`;
ALTER TABLE protein_tree_node DROP KEY `right_index`;
ALTER TABLE protein_tree_node ADD KEY `root_id` (`root_id`,`left_index`);
ALTER TABLE protein_tree_node ADD KEY `root_id_2` (`root_id`,`right_index`);


# Changes in protein_tree_tag
ALTER TABLE protein_tree_tag MODIFY COLUMN `tag` varchar(50) NOT NULL, MODIFY COLUMN `value` mediumtext NOT NULL;
ALTER TABLE protein_tree_tag DROP KEY `tag_node_id`;
ALTER TABLE protein_tree_tag ADD KEY `node_id_tag` (`node_id`,`tag`);
ALTER TABLE protein_tree_tag ADD KEY `tag_node_id` (`tag`,`node_id`);

# Changes in subset
ALTER TABLE subset MODIFY COLUMN `subset_id` int(10) unsigned NOT NULL AUTO_INCREMENT;

# Changes in subset_member
ALTER TABLE subset_member MODIFY COLUMN `subset_id` int(10) unsigned NOT NULL, MODIFY COLUMN `member_id` int(10) unsigned NOT NULL;

# New table super_protein_tree_attr
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `super_protein_tree_attr` (
`node_id` int(10) unsigned NOT NULL,
`duplication` tinyint(3) unsigned DEFAULT NULL,
`taxon_id` int(10) unsigned DEFAULT NULL,
`taxon_name` varchar(255) DEFAULT NULL,
`bootstrap` tinyint(3) unsigned DEFAULT NULL,
`duplication_confidence_score` double(5,4) DEFAULT NULL,
PRIMARY KEY (`node_id`),
KEY `taxon_id` (`taxon_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

# Fill the new table
INSERT INTO super_protein_tree_attr (node_id, taxon_id) SELECT super_protein_tree_tag.node_id, super_protein_tree_tag.value from super_protein_tree_tag where tag = 'taxon_id';
UPDATE super_protein_tree_attr JOIN super_protein_tree_tag USING (node_id) SET taxon_name = value WHERE tag = 'taxon_name';
UPDATE super_protein_tree_attr JOIN super_protein_tree_tag USING (node_id) SET bootstrap = value WHERE tag = 'Bootstrap';
UPDATE super_protein_tree_attr JOIN super_protein_tree_tag USING (node_id) SET duplication_confidence_score = value WHERE tag = 'duplication_confidence_score';
DELETE FROM super_protein_tree_tag WHERE tag in ('Duplication', 'dubious_duplication', 'duplication_confidence_score', 'Bootstrap', 'taxon_name', 'taxon_id');


# Changes in super_protein_tree_node
ALTER TABLE super_protein_tree_node MODIFY COLUMN `parent_id` int(10) unsigned DEFAULT NULL, MODIFY COLUMN `root_id` int(10) unsigned DEFAULT NULL;
ALTER TABLE super_protein_tree_node DROP KEY `root_id`;
ALTER TABLE super_protein_tree_node DROP KEY `left_index`;
ALTER TABLE super_protein_tree_node DROP KEY `right_index`;
ALTER TABLE super_protein_tree_node ADD KEY `root_id` (`root_id`,`left_index`);
ALTER TABLE super_protein_tree_node ADD KEY `root_id_2` (`root_id`,`right_index`);

# Changes in super_protein_tree_tag
ALTER TABLE super_protein_tree_tag MODIFY COLUMN `tag` varchar(50) NOT NULL, MODIFY COLUMN `value` mediumtext NOT NULL;
ALTER TABLE super_protein_tree_tag DROP KEY `tag_node_id`;
ALTER TABLE super_protein_tree_tag ADD KEY `node_id_tag` (`node_id`,`tag`);
ALTER TABLE super_protein_tree_tag ADD KEY `tag_node_id` (`tag`,`node_id`);
