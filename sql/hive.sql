create table hive (
  hive_id          int(10) NOT NULL auto_increment,
  analysis_id      int(10) NOT NULL,
  host	           varchar(40) DEFAULT '' NOT NULL,
  process_id       int(10) NOT NULL,
  work_done        int(11) DEFAULT '0' NOT NULL,
  born	           datetime NOT NULL,
  last_check_in    datetime NOT NULL,
  died             datetime DEFAULT NULL,
  cause_of_death   enum('', 'NATURAL', 'NO_WORK', 'UNKNOWN') default '' NOT NULL,
  PRIMARY KEY (hive_id),
);
