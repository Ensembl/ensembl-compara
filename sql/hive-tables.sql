CREATE TABLE hive (
  hive_id          int(10) NOT NULL auto_increment,
  analysis_id      int(10) NOT NULL,
  host	           varchar(40) DEFAULT '' NOT NULL,
  process_id       int(10) NOT NULL,
  work_done        int(11) DEFAULT '0' NOT NULL,
  born	           datetime NOT NULL,
  last_check_in    datetime NOT NULL,
  died             datetime DEFAULT NULL,
  cause_of_death   enum('', 'NATURAL', 'NO_WORK', 'UNKNOWN') DEFAULT '' NOT NULL,
  PRIMARY KEY (hive_id),
);

------------------------------------------------------------------------------------
--
-- Table structure for table 'simple_rule'
--
-- overview:
--   redesign of pipeline rule system.  Basic design is simplifed so that a
--   'rule' is simply a link from one analysis object to another
--     (ie an edge in a flowchart or object interaction diagram where
--      condition_analysis_id => goal_analysis_id)
--   Each analysis object (analysis_id) is a unique node in the
--   graph that describes the pipeline system.
--     (ie each analysis_id is an 'Instance' of the module it points to)
--   Main reason for redesign that by making a single table we can implement
--   a UNIQUE constraint so that the pipeline can modify itself as it runs
--   and avoid race conditions where the same link is created multiple times
--
-- semantics:
--   simple_rule_id           - internal ID
--   condition_analysis_id    - foreign key to analysis table analysis_id
--   goal_analysis_id         - foreign key to analysis table analysis_id

CREATE TABLE simple_rule (
  simple_rule_id           int(10) unsigned default '0' not null auto_increment,
  condition_analysis_id    int(10) unsigned NOT NULL,
  goal_analysis_id         int(10) unsigned NOT NULL,

  PRIMARY KEY (simple_rule_id),
  UNIQUE (condition_analysis_id, goal_analysis_id)
);


------------------------------------------------------------------------------------
--
-- Table structure for table 'network_rule'
--
-- overview:
--   Extension of simple_rule design except that goal is now in extended URL format e.g.
--   mysql://ensadmin:<pass>@ecs2:3361/compara_hive_test?analysis.logic_name='blast_NCBI34'
--   (full network address of an analysis).  The only requirement is that there are rows in 
--   the analysis_job, analysis, network_rule, and hive tables so that the following join
--   works on the same database 
--   WHERE analysis.analysis_id = network_rule.condition_analysis_id 
--   AND analysis_job.analysis_id=analysis.analysis_id
--   AND hive.analysis_id=analysis.analysis_id
--  
--   The analysis table will be extended so that it can specify different read and write
--   databases, with the default being the database the analysis is on
--
-- semantics:
--   condition_analysis_id    - foreign key to analysis table analysis_id
--   goal_analysis_url        - foreign key to net distributed analysis reference

CREATE TABLE network_rule (
  condition_analysis_id    int(10) unsigned NOT NULL,
  goal_analysis_url        varchar(255) default '' NOT NULL,

  UNIQUE (condition_analysis_id, goal_analysis_url)
);


CREATE TABLE analysis_job (
  analysis_job_id        int(10) NOT NULL auto_increment,
  input_analysis_job_id  int(10) NOT NULL,  #analysis_job which created this from rules
  analysis_id            int(10) NOT NULL,
  input_id               varchar(100) not null,
  job_claim              varchar(40) NOT NULL default '', #UUID
  hive_id                int(10) NOT NULL,
  status                 enum('READY','BLOCKED','CLAIMED','GET_INPUT','RUN','WRITE_OUTPUT','DONE') DEFAULT 'READY' NOT NULL,
  retry_count            int(10) not NULL default '0',
  completed              datetime NOT NULL,
  result                 smallint(10) unsigned NOT NULL,

  PRIMARY KEY                  (analysis_job_id),
  UNIQUE KEY input_id_analysis (input_id, analysis_id),
  INDEX job_claim_analysis     (job_claim, analysis_id)
  INDEX job_status_analysis    (status, analysis_id)
);


CREATE TABLE analysis_job_files (
  analysis_job_id     int(10) NOT NULL,
  stdout_file         varchar(255) NOT NULL,
  stderr_file         varchar(255) NOT NULL,
  temp_dir            varchar(255) DEFAULT ''
);


CREATE TABLE analysis_status (
  analysis_id    int(10) NOT NULL,
  status         enum('BLOCKED', 'READY','WORKING','DONE') DEFAULT 'READY' NOT NULL,
  jobs_todo      int(10) DEFAULT '0' NOT NULL,
  jobs_done      int(10) DEFAULT '0' NOT NULL,
  last_update    datetime NOT NULL,
);


