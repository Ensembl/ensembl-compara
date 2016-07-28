CREATE TABLE `gene_member` (
  `gene_member_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `stable_id` varchar(128) NOT NULL,
  `version` int(10) DEFAULT '0',
  `source_name` enum('ENSEMBLGENE','EXTERNALGENE') NOT NULL,
  `taxon_id` int(10) unsigned NOT NULL,
  `genome_db_id` int(10) unsigned DEFAULT NULL,
  `canonical_member_id` int(10) unsigned DEFAULT NULL,
  `description` text,
  `dnafrag_id` bigint(20) unsigned DEFAULT NULL,
  `dnafrag_start` int(10) DEFAULT NULL,
  `dnafrag_end` int(10) DEFAULT NULL,
  `dnafrag_strand` tinyint(4) DEFAULT NULL,
  `display_label` varchar(128) DEFAULT NULL,
  `families` tinyint(1) unsigned DEFAULT '0',
  `gene_trees` tinyint(1) unsigned DEFAULT '0',
  `gene_gain_loss_trees` tinyint(1) unsigned DEFAULT '0',
  `orthologues` int(10) unsigned DEFAULT '0',
  `paralogues` int(10) unsigned DEFAULT '0',
  `homoeologues` int(10) unsigned DEFAULT '0',
  PRIMARY KEY (`gene_member_id`),
  UNIQUE KEY `stable_id` (`stable_id`),
  KEY `taxon_id` (`taxon_id`),
  KEY `genome_db_id` (`genome_db_id`),
  KEY `source_name` (`source_name`),
  KEY `canonical_member_id` (`canonical_member_id`),
  KEY `dnafrag_id_start` (`dnafrag_id`,`dnafrag_start`),
  KEY `dnafrag_id_end` (`dnafrag_id`,`dnafrag_end`)
) ENGINE=MyISAM   MAX_ROWS=100000000;

CREATE TABLE `genome_db` (
  `genome_db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `taxon_id` int(10) unsigned DEFAULT NULL,
  `name` varchar(128) NOT NULL DEFAULT '',
  `assembly` varchar(100) NOT NULL DEFAULT '',
  `genebuild` varchar(100) NOT NULL DEFAULT '',
  `has_karyotype` tinyint(1) NOT NULL DEFAULT '0',
  `is_high_coverage` tinyint(1) NOT NULL DEFAULT '0',
  `genome_component` varchar(5) DEFAULT NULL,
  `locator` varchar(400) DEFAULT NULL,
  `first_release` smallint(6) DEFAULT NULL,
  `last_release` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`genome_db_id`),
  UNIQUE KEY `name` (`name`,`assembly`,`genome_component`),
  KEY `taxon_id` (`taxon_id`)
) ENGINE=MyISAM  ;

CREATE TABLE `homology` (
  `homology_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `description` enum('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','gene_split','between_species_paralog','alt_allele','homoeolog_one2one','homoeolog_one2many','homoeolog_many2many') DEFAULT NULL,
  `is_tree_compliant` tinyint(1) NOT NULL DEFAULT '0',
  `dn` float(10,5) DEFAULT NULL,
  `ds` float(10,5) DEFAULT NULL,
  `n` float(10,1) DEFAULT NULL,
  `s` float(10,1) DEFAULT NULL,
  `lnl` float(10,3) DEFAULT NULL,
  `species_tree_node_id` int(10) unsigned DEFAULT NULL,
  `gene_tree_node_id` int(10) unsigned DEFAULT NULL,
  `gene_tree_root_id` int(10) unsigned DEFAULT NULL,
  `goc_score` int(10),
  `wga_coverage` dec(3,2),
  PRIMARY KEY (`homology_id`),
  KEY `method_link_species_set_id` (`method_link_species_set_id`),
  KEY `species_tree_node_id` (`species_tree_node_id`),
  KEY `gene_tree_node_id` (`gene_tree_node_id`),
  KEY `gene_tree_root_id` (`gene_tree_root_id`)
) ENGINE=MyISAM  ;

CREATE TABLE `homology_member` (
  `homology_id` int(10) unsigned NOT NULL,
  `gene_member_id` int(10) unsigned NOT NULL,
  `seq_member_id` int(10) unsigned DEFAULT NULL,
  `cigar_line` mediumtext,
  `perc_cov` tinyint(3) unsigned DEFAULT '0',
  `perc_id` tinyint(3) unsigned DEFAULT '0',
  `perc_pos` tinyint(3) unsigned DEFAULT '0',
  PRIMARY KEY (`homology_id`,`gene_member_id`),
  KEY `homology_id` (`homology_id`),
  KEY `gene_member_id` (`gene_member_id`),
  KEY `seq_member_id` (`seq_member_id`)
) ENGINE=MyISAM  MAX_ROWS=300000000;

CREATE TABLE `meta` (
  `meta_id` int(11) NOT NULL AUTO_INCREMENT,
  `species_id` int(10) unsigned DEFAULT '1',
  `meta_key` varchar(40) NOT NULL,
  `meta_value` text NOT NULL,
  PRIMARY KEY (`meta_id`),
  UNIQUE KEY `species_key_value_idx` (`species_id`,`meta_key`,`meta_value`(255)),
  KEY `species_value_idx` (`species_id`,`meta_value`(255))
) ENGINE=MyISAM  ;

CREATE TABLE `method_link` (
  `method_link_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(50) NOT NULL DEFAULT '',
  `class` varchar(50) NOT NULL DEFAULT '',
  PRIMARY KEY (`method_link_id`),
  UNIQUE KEY `type` (`type`)
) ENGINE=MyISAM  ;

CREATE TABLE `method_link_species_set` (
  `method_link_species_set_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `method_link_id` int(10) unsigned NOT NULL,
  `species_set_id` int(10) unsigned NOT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  `source` varchar(255) NOT NULL DEFAULT 'ensembl',
  `url` varchar(255) NOT NULL DEFAULT '',
  `first_release` smallint(6) DEFAULT NULL,
  `last_release` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`method_link_species_set_id`),
  UNIQUE KEY `method_link_id` (`method_link_id`,`species_set_id`),
  KEY `species_set_id` (`species_set_id`)
) ENGINE=MyISAM  ;

CREATE TABLE `method_link_species_set_tag` (
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext,
  PRIMARY KEY (`method_link_species_set_id`,`tag`)
) ENGINE=MyISAM ;

CREATE TABLE `seq_member` (
  `seq_member_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `stable_id` varchar(128) NOT NULL,
  `version` int(10) DEFAULT '0',
  `source_name` enum('ENSEMBLPEP','ENSEMBLTRANS','Uniprot/SPTREMBL','Uniprot/SWISSPROT','EXTERNALPEP','EXTERNALTRANS','EXTERNALCDS') NOT NULL,
  `taxon_id` int(10) unsigned NOT NULL,
  `genome_db_id` int(10) unsigned DEFAULT NULL,
  `sequence_id` int(10) unsigned DEFAULT NULL,
  `gene_member_id` int(10) unsigned DEFAULT NULL,
  `description` text,
  `dnafrag_id` bigint(20) unsigned DEFAULT NULL,
  `dnafrag_start` int(10) DEFAULT NULL,
  `dnafrag_end` int(10) DEFAULT NULL,
  `dnafrag_strand` tinyint(4) DEFAULT NULL,
  `display_label` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`seq_member_id`),
  UNIQUE KEY `stable_id` (`stable_id`),
  KEY `taxon_id` (`taxon_id`),
  KEY `genome_db_id` (`genome_db_id`),
  KEY `source_name` (`source_name`),
  KEY `sequence_id` (`sequence_id`),
  KEY `gene_member_id` (`gene_member_id`),
  KEY `dnafrag_id_start` (`dnafrag_id`,`dnafrag_start`),
  KEY `dnafrag_id_end` (`dnafrag_id`,`dnafrag_end`),
  KEY `seq_member_gene_member_id_end` (`seq_member_id`,`gene_member_id`)
) ENGINE=MyISAM   MAX_ROWS=100000000;

CREATE TABLE `species_set` (
  `species_set_id` int(10) unsigned NOT NULL,
  `genome_db_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`species_set_id`,`genome_db_id`),
  KEY `genome_db_id` (`genome_db_id`)
) ENGINE=MyISAM ;

CREATE TABLE `species_set_header` (
  `species_set_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `size` int(10) unsigned NOT NULL,
  `first_release` smallint(6) DEFAULT NULL,
  `last_release` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`species_set_id`)
) ENGINE=MyISAM  ;

CREATE TABLE `species_set_tag` (
  `species_set_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext,
  UNIQUE KEY `tag_species_set_id` (`species_set_id`,`tag`)
) ENGINE=MyISAM ;

CREATE TABLE `homology_id_mapping` (
    `curr_release_homology_id`  INT NOT NULL,
    `prev_release_homology_id`  INT,
    `mlss_id`                   INT NOT NULL
) ENGINE=MyISAM ;

CREATE TABLE `exon_boundaries` (
    `gene_member_id`   INT NOT NULL,
    `dnafrag_start`    INT NOT NULL,
    `dnafrag_end`      INT NOT NULL,
    `seq_member_id`    INT NOT NULL,
    INDEX (`gene_member_id`)  
) ENGINE=InnoDB ;
