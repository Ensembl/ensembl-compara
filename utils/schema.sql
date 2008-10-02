# SQL Manager 2007 for MySQL 4.3.2.3
# ---------------------------------------
# Host     : ensdb-1-10
# Port     : 3307
# Database : ensembl_web_user_db


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

SET FOREIGN_KEY_CHECKS=0;

CREATE DATABASE `ensembl_web_user_db`
    CHARACTER SET 'latin1'
    COLLATE 'latin1_swedish_ci';

USE `ensembl_web_user_db`;

#
# Structure for the `cache_ideo` table : 
#

CREATE TABLE `cache_ideo` (
  `code` varchar(64) NOT NULL default '',
  `modified_at` datetime NOT NULL default '0000-00-00 00:00:00',
  `meta` text NOT NULL,
  `content` mediumblob NOT NULL,
  UNIQUE KEY `code` (`code`),
  KEY `modified_at` (`modified_at`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `cache_map` table : 
#

CREATE TABLE `cache_map` (
  `code` varchar(64) NOT NULL default '',
  `modified_at` datetime NOT NULL default '0000-00-00 00:00:00',
  `meta` text NOT NULL,
  `content` mediumblob NOT NULL,
  UNIQUE KEY `code` (`code`),
  KEY `modified_at` (`modified_at`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `cache_ortho` table : 
#

CREATE TABLE `cache_ortho` (
  `code` varchar(64) NOT NULL default '',
  `modified_at` datetime NOT NULL default '0000-00-00 00:00:00',
  `meta` text NOT NULL,
  `content` mediumblob NOT NULL,
  UNIQUE KEY `code` (`code`),
  KEY `modified_at` (`modified_at`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `cache_para` table : 
#

CREATE TABLE `cache_para` (
  `code` varchar(64) NOT NULL default '',
  `modified_at` datetime NOT NULL default '0000-00-00 00:00:00',
  `meta` text NOT NULL,
  `content` mediumblob NOT NULL,
  UNIQUE KEY `code` (`code`),
  KEY `modified_at` (`modified_at`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `group_member` table : 
#

CREATE TABLE `group_member` (
  `group_member_id` int(11) NOT NULL auto_increment,
  `webgroup_id` int(11) NOT NULL default '0',
  `user_id` int(11) NOT NULL default '0',
  `level` enum('member','administrator','superuser') NOT NULL default 'member',
  `member_status` enum('active','inactive','pending','barred') default 'inactive',
  `created_by` int(11) NOT NULL default '0',
  `modified_by` int(11) NOT NULL default '0',
  `created_at` datetime default NULL,
  `modified_at` datetime default NULL,
  `status` enum('active','inactive','pending','barred') default NULL,
  PRIMARY KEY  (`group_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `group_record` table : 
#

CREATE TABLE `group_record` (
  `group_record_id` int(11) NOT NULL auto_increment,
  `webgroup_id` int(11) default NULL,
  `type` varchar(255) NOT NULL default '',
  `data` text NOT NULL,
  `created_by` int(11) default NULL,
  `modified_by` int(11) default NULL,
  `created_at` datetime default NULL,
  `modified_at` datetime default NULL,
  PRIMARY KEY  (`group_record_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `group_record_vega` table : 
#

CREATE TABLE `group_record_vega` (
  `group_record_vega_id` int(11) NOT NULL auto_increment,
  `webgroup_id` int(11) default NULL,
  `type` varchar(255) NOT NULL default '',
  `data` text NOT NULL,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `modified_at` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`group_record_vega_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `session` table : 
#

CREATE TABLE `session` (
  `last_session_no` int(10) unsigned NOT NULL default '0'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `session_record` table : 
#

CREATE TABLE `session_record` (
  `session_record_id` int(10) unsigned NOT NULL auto_increment,
  `session_id` int(10) unsigned NOT NULL default '0',
  `type_id` int(11) NOT NULL default '1',
  `type` enum('script','das','tmp') default NULL,
  `code` varchar(64) NOT NULL default '',
  `data` text NOT NULL,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `modified_at` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `valid_thru` timestamp NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`session_record_id`),
  UNIQUE KEY `session_id` (`session_id`,`code`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `sessions` table : 
#

CREATE TABLE `sessions` (
  `id` varchar(32) NOT NULL default '',
  `a_session` mediumtext NOT NULL,
  `modified_at` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`id`),
  KEY `modified_at` (`modified_at`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `type` table : 
#

CREATE TABLE `type` (
  `type_id` int(10) unsigned NOT NULL auto_increment,
  `code` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`type_id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `user` table : 
#

CREATE TABLE `user` (
  `user_id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `email` varchar(255) NOT NULL default '',
  `salt` varchar(8) NOT NULL default '',
  `password` varchar(64) NOT NULL default '',
  `data` text NOT NULL,
  `organisation` text NOT NULL,
  `status` enum('active','pending','suspended') NOT NULL default 'pending',
  `created_by` int(11) default NULL,
  `modified_by` int(11) default NULL,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `modified_at` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `user_record` table : 
#

CREATE TABLE `user_record` (
  `user_record_id` int(11) NOT NULL auto_increment,
  `user_id` int(11) NOT NULL default '0',
  `type` varchar(255) NOT NULL default '',
  `data` text NOT NULL,
  `created_by` int(11) default NULL,
  `modified_by` int(11) default NULL,
  `created_at` datetime default NULL,
  `modified_at` datetime default NULL,
  PRIMARY KEY  (`user_record_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `user_record_vega` table : 
#

CREATE TABLE `user_record_vega` (
  `user_record_vega_id` int(11) NOT NULL auto_increment,
  `user_id` int(11) NOT NULL default '0',
  `type` varchar(255) NOT NULL default '',
  `data` text NOT NULL,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `modified_at` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`user_record_vega_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

#
# Structure for the `webgroup` table : 
#

CREATE TABLE `webgroup` (
  `webgroup_id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `blurb` text NOT NULL,
  `data` text NOT NULL,
  `type` enum('open','restricted','private') NOT NULL default 'open',
  `status` enum('active','inactive') NOT NULL default 'active',
  `created_by` int(11) NOT NULL default '0',
  `modified_by` int(11) NOT NULL default '0',
  `created_at` datetime default NULL,
  `modified_at` datetime default NULL,
  PRIMARY KEY  (`webgroup_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;