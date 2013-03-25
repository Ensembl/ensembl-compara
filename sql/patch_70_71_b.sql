# patch_70_71_a.sql
#
# Title: member_xref
#
# Description: Create member_xref and external_db tables using for gene tree highlighting

#
# Table structure for table 'external_db'
#

CREATE TABLE `external_db` (
  `external_db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `db_name` varchar(100) NOT NULL,
  `db_release` varchar(255) DEFAULT NULL,
  `status` enum('KNOWNXREF','KNOWN','XREF','PRED','ORTH','PSEUDO') NOT NULL,
  `priority` int(11) NOT NULL,
  `db_display_name` varchar(255) DEFAULT NULL,
  `type` enum('ARRAY','ALT_TRANS','ALT_GENE','MISC','LIT','PRIMARY_DB_SYNONYM','ENSEMBL') DEFAULT NULL,
  `secondary_db_name` varchar(255) DEFAULT NULL,
  `secondary_db_table` varchar(255) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`external_db_id`),
  UNIQUE KEY `db_name_db_release_idx` (`db_name`,`db_release`)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;


#
# Table structure for table 'member_xref'
#

CREATE TABLE `member_xref` (
  `member_id` int(10) unsigned NOT NULL,
  `dbprimary_acc` varchar(10) NOT NULL,
  `external_db_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`member_id`,`dbprimary_acc`,`external_db_id`),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  FOREIGN KEY (external_db_id) REFERENCES external_db(external_db_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_70_71_b.sql|member_xref');

