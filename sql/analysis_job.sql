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
);


CREATE TABLE analysis_job_files (
  analysis_job_id     int(10) NOT NULL,
  stdout_file         varchar(255) NOT NULL,
  stderr_file         varchar(255) NOT NULL,
  temp_dir            varchar(255) DEFAULT ''
);

