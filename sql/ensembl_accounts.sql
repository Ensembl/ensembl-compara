CREATE TABLE `all_record` (
  `record_id` int(11) NOT NULL AUTO_INCREMENT,
  `record_type` enum('user','group','session') NOT NULL DEFAULT 'session',
  `record_type_id` int(11) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `code` varchar(255) DEFAULT NULL,
  `data` text,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`record_id`),
  UNIQUE KEY `record_type_code` (`record_type`,`record_type_id`,`type`,`code`),
  KEY `record_type_idx` (`record_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;

CREATE TABLE `group_member` (
  `group_member_id` int(11) NOT NULL AUTO_INCREMENT,
  `webgroup_id` int(11) NOT NULL DEFAULT '0',
  `user_id` int(11) NOT NULL DEFAULT '0',
  `level` enum('member','administrator') NOT NULL DEFAULT 'member',
  `status` enum('active','inactive','pending','barred') NOT NULL DEFAULT 'active',
  `member_status` enum('active','inactive','pending','barred') NOT NULL DEFAULT 'inactive',
  `data` text,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`group_member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=39174 DEFAULT CHARSET=latin1;

CREATE TABLE `login` (
  `login_id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `identity` varchar(255) DEFAULT NULL,
  `type` enum('local','openid','ldap') NOT NULL DEFAULT 'local',
  `data` text,
  `status` enum('active','pending') NOT NULL DEFAULT 'pending',
  `salt` varchar(8) DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`login_id`),
  KEY `identityx` (`identity`),
  KEY `user_idx` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=27834 DEFAULT CHARSET=latin1;

CREATE TABLE `session` (
  `last_session_no` int(10) unsigned NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `sessions` (
  `id` varchar(32) NOT NULL DEFAULT '',
  `a_session` mediumtext NOT NULL,
  `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `modified_at` (`modified_at`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `share_url` (
  `code` varchar(64) NOT NULL,
  `url` text NOT NULL,
  `type` varchar(32) NOT NULL,
  `action` varchar(32) NOT NULL,
  `function` varchar(32) NOT NULL,
  `data` text NOT NULL,
  `share_type` varchar(10) NOT NULL,
  `used` int(10) NOT NULL DEFAULT '0',
  `created_at` timestamp,
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `type` (
  `type_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`type_id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

CREATE TABLE `user` (
  `user_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `data` text,
  `organisation` varchar(255) DEFAULT NULL,
  `country` varchar(2) DEFAULT NULL,
  `status` enum('active','suspended') NOT NULL DEFAULT 'active',
  `salt` varchar(8) DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=119291 DEFAULT CHARSET=latin1;

CREATE TABLE `webgroup` (
  `webgroup_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `blurb` text,
  `data` text,
  `type` enum('open','restricted','private','hidden') DEFAULT 'restricted',
  `status` enum('active','inactive') DEFAULT 'active',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`webgroup_id`)
) ENGINE=InnoDB AUTO_INCREMENT=210 DEFAULT CHARSET=latin1;

