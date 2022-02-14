CREATE TABLE `ncbi_taxa_name` (
  `taxon_id` int(10) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `name_class` varchar(50) NOT NULL,
  KEY `taxon_id` (`taxon_id`),
  KEY `name` (`name`),
  KEY `name_class` (`name_class`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ncbi_taxa_node` (
  `taxon_id` int(10) unsigned NOT NULL,
  `parent_id` int(10) unsigned NOT NULL,
  `rank` char(32) NOT NULL DEFAULT '',
  `genbank_hidden_flag` tinyint(1) NOT NULL DEFAULT '0',
  `left_index` int(10) NOT NULL DEFAULT '0',
  `right_index` int(10) NOT NULL DEFAULT '0',
  `root_id` int(10) NOT NULL DEFAULT '1',
  PRIMARY KEY (`taxon_id`),
  KEY `parent_id` (`parent_id`),
  KEY `rank` (`rank`),
  KEY `left_index` (`left_index`),
  KEY `right_index` (`right_index`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
