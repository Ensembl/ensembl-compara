CREATE TABLE `dnafrag` (
  `dnafrag_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `length` int(11) NOT NULL DEFAULT '0',
  `name` varchar(255) NOT NULL DEFAULT '',
  `genome_db_id` int(10) unsigned NOT NULL,
  `coord_system_name` varchar(40) NOT NULL DEFAULT '',
  `cellular_component` enum('NUC','MT','PT') NOT NULL DEFAULT 'NUC',
  `is_reference` tinyint(1) NOT NULL DEFAULT '1',
  `codon_table_id` tinyint(2) unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`dnafrag_id`),
  UNIQUE KEY `name` (`genome_db_id`,`name`)
);

CREATE TABLE `genome_db` (
  `genome_db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `taxon_id` int(10) unsigned DEFAULT NULL,
  `name` varchar(128) NOT NULL DEFAULT '',
  `assembly` varchar(100) NOT NULL DEFAULT '',
  `genebuild` varchar(100) NOT NULL DEFAULT '',
  `has_karyotype` tinyint(1) NOT NULL DEFAULT '0',
  `is_good_for_alignment` tinyint(1) NOT NULL DEFAULT '0',
  `genome_component` varchar(5) DEFAULT NULL,
  `strain_name` varchar(40) DEFAULT NULL,
  `display_name` varchar(255) DEFAULT NULL,
  `locator` varchar(400) DEFAULT NULL,
  `first_release` smallint(6) DEFAULT NULL,
  `last_release` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`genome_db_id`),
  UNIQUE KEY `name` (`name`,`assembly`,`genome_component`),
  KEY `taxon_id` (`taxon_id`)
);

CREATE TABLE `mapping_session` (
  `mapping_session_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('family','tree','hmm') DEFAULT NULL,
  `when_mapped` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `rel_from` int(10) unsigned DEFAULT NULL,
  `rel_to` int(10) unsigned DEFAULT NULL,
  `prefix` char(4) NOT NULL,
  PRIMARY KEY (`mapping_session_id`),
  UNIQUE KEY `type` (`type`,`rel_from`,`rel_to`,`prefix`)
);

CREATE TABLE `meta` (
  `meta_id` int(11) NOT NULL AUTO_INCREMENT,
  `species_id` int(10) unsigned DEFAULT '1',
  `meta_key` varchar(40) NOT NULL,
  `meta_value` text NOT NULL,
  PRIMARY KEY (`meta_id`),
  UNIQUE KEY `species_key_value_idx` (`species_id`,`meta_key`,`meta_value`(255)),
  KEY `species_value_idx` (`species_id`,`meta_value`(255))
);

CREATE TABLE `method_link` (
  `method_link_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(50) NOT NULL DEFAULT '',
  `class` varchar(50) NOT NULL DEFAULT '',
  `display_name` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`method_link_id`),
  UNIQUE KEY `type` (`type`)
);

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
);

CREATE TABLE `method_link_species_set_attr` (
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `n_goc_null` int(11) DEFAULT NULL,
  `n_goc_0` int(11) DEFAULT NULL,
  `n_goc_25` int(11) DEFAULT NULL,
  `n_goc_50` int(11) DEFAULT NULL,
  `n_goc_75` int(11) DEFAULT NULL,
  `n_goc_100` int(11) DEFAULT NULL,
  `perc_orth_above_goc_thresh` float DEFAULT NULL,
  `goc_quality_threshold` int(11) DEFAULT NULL,
  `wga_quality_threshold` int(11) DEFAULT NULL,
  `perc_orth_above_wga_thresh` float DEFAULT NULL,
  `threshold_on_ds` int(11) DEFAULT NULL,
  PRIMARY KEY (`method_link_species_set_id`)
);

CREATE TABLE `method_link_species_set_tag` (
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext NOT NULL,
  PRIMARY KEY (`method_link_species_set_id`,`tag`),
  KEY `tag` (`tag`)
);

CREATE TABLE `species_set` (
  `species_set_id` int(10) unsigned NOT NULL,
  `genome_db_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`species_set_id`,`genome_db_id`),
  KEY `genome_db_id` (`genome_db_id`)
);

CREATE TABLE `species_set_header` (
  `species_set_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `size` int(10) unsigned NOT NULL,
  `first_release` smallint(6) DEFAULT NULL,
  `last_release` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`species_set_id`)
);

CREATE TABLE `species_set_tag` (
  `species_set_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext NOT NULL,
  PRIMARY KEY (`species_set_id`,`tag`),
  KEY `tag` (`tag`)
);
