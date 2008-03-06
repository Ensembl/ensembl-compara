#
# Table structure for table 'anchor_sequence'
#
# This table stores anchor sequences and associated information
#


CREATE TABLE `anchor_sequence` (
  `anchor_seq_id` int(20) unsigned NOT NULL auto_increment,
  `method_link_species_set_id` int(10) unsigned default NULL,
  `test_mlssID` int(10) unsigned default NULL,
  `anchor_id` int(20) unsigned default NULL,
  `dnafrag_id` int(20) unsigned default NULL,
  `start` int(20) unsigned default NULL,
  `end` int(20) unsigned default NULL,
  `strand` tinyint(4) default '0',
  `sequence` varchar(250) default '',
  `length` int(20) unsigned default NULL,
  PRIMARY KEY  (`anchor_seq_id`),
  KEY `anchor_id_mlss_id` (`anchor_id`, `method_link_species_set_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


#
# Table structure for table 'anchor_align'
#
# This table stores anchor information after they have been mapped (exonerated) to target genomes 
#


CREATE TABLE `anchor_align` (
  `anchor_align_id` int(20) unsigned NOT NULL auto_increment,
  `method_link_species_set_id` int(10) unsigned default NULL,
  `anchor_id` int(20) unsigned default NULL,
  `dnafrag_id` int(20) unsigned default NULL,
  `dnafrag_start` int(20) default NULL,
  `dnafrag_end` int(20) default NULL,
  `dnafrag_strand` tinyint(4) default NULL,
  `score` float default NULL,
  `num_of_organisms` smallint(5) unsigned default NULL,
  `num_of_sequences` smallint(5) unsigned default NULL,
  `anchor_status` int(10) default NULL,
  PRIMARY KEY  (`anchor_align_id`),
  KEY `anchor_id_mlss_id` (`anchor_id`,`method_link_species_set_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

