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


-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

-- New version
REPLACE INTO meta (species_id, meta_key, meta_value)
VALUES (NULL, 'schema_version', '69');



-- Please note that it is not possible to write a patch for the conversion of the CAFE tables in schema 68 to schema 69.
-- The way that we *run* CAFE and store the information now is different and it is not possible to copy the data from the older version. 
-- Everything refers to the CAFE tree, but the tree is computed differently now, so no possible mapping can be done.

--
-- Table structure for table `CAFE_gene_family`
--

SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE IF NOT EXISTS `CAFE_gene_family` (
  `cafe_gene_family_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `root_id` int(10) unsigned NOT NULL,
  `lca_id` int(10) unsigned NOT NULL,
  `gene_tree_root_id` int(10) unsigned NOT NULL,
  `pvalue_avg` double(5,4) DEFAULT NULL,
  `lambdas` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`cafe_gene_family_id`),
  KEY `lca_id` (`lca_id`),
  KEY `root_id` (`root_id`),
  KEY `gene_tree_root_id` (`gene_tree_root_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CAFE_species_gene`
--

CREATE TABLE IF NOT EXISTS `CAFE_species_gene` (
  `cafe_gene_family_id` int(10) unsigned NOT NULL,
  `node_id` int(10) unsigned NOT NULL,
  `taxon_id` int(10) unsigned DEFAULT NULL,
  `n_members` int(4) unsigned NOT NULL,
  `pvalue` double(5,4) DEFAULT NULL,
  KEY `node_id` (`node_id`),
  KEY `cafe_gene_family_id` (`cafe_gene_family_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `species_tree_node`
--

CREATE TABLE IF NOT EXISTS `species_tree_node` (
  `node_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned DEFAULT NULL,
  `root_id` int(10) unsigned DEFAULT NULL,
  `left_index` int(10) NOT NULL DEFAULT '0',
  `right_index` int(10) NOT NULL DEFAULT '0',
  `distance_to_parent` double DEFAULT '1',
  PRIMARY KEY (`node_id`),
  KEY `parent_id` (`parent_id`),
  KEY `root_id` (`root_id`,`left_index`),
  KEY `root_id_2` (`root_id`,`right_index`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `species_tree_node_tag`
--

CREATE TABLE IF NOT EXISTS `species_tree_node_tag` (
  `node_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext NOT NULL,
  KEY `node_id_tag` (`node_id`,`tag`),
  KEY `tag_node_id` (`tag`,`node_id`),
  KEY `node_id` (`node_id`),
  KEY `tag` (`tag`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--                                                                                 
-- Table structure for table `species_tree_root`                                   
--                                                                                 
                                                                                   
SET @saved_cs_client     = @@character_set_client;                                 
SET character_set_client = utf8;                                                   
CREATE TABLE `species_tree_root` (                                                 
  `root_id` int(10) unsigned NOT NULL,                                             
  `method_link_species_set_id` int(10) unsigned NOT NULL,                          
  `species_tree` mediumtext,                                                       
  `pvalue_lim` double(5,4) DEFAULT NULL,                                           
  PRIMARY KEY (`root_id`),                                                         
  KEY `method_link_species_set_id` (`method_link_species_set_id`)                  
) ENGINE=MyISAM DEFAULT CHARSET=latin1;                                            
SET character_set_client = @saved_cs_client;


-- Other table changes

ALTER TABLE `peptide_align_feature` DROP KEY `hmember_hit`;
ALTER TABLE `peptide_align_feature` ENGINE=MyISAM DEFAULT CHARSET=latin1 MAX_ROWS=100000000 AVG_ROW_LENGTH=133;

ALTER TABLE `gene_tree_node_tag` DROP KEY `tag_node_id`;
ALTER TABLE `gene_tree_node_tag` DROP KEY `tag`;

ALTER TABLE `gene_tree_node` MODIFY `left_index` int(10) NOT NULL DEFAULT '0';
ALTER TABLE `gene_tree_node` MODIFY `right_index` int(10) NOT NULL DEFAULT '0';
