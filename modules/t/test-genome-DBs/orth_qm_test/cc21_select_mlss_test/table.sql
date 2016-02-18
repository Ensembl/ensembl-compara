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

