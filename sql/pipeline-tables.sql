
################################################################################
#
# Table structure for table 'analysis'
# 
# semantics:
# analysis_id - internal id
# created   - date to distinguish newer and older versions off the 
#             same analysis. Not well maintained so far.
# logic_name  string to identify the analysis. Used mainly inside pipeline.
# db, db_version, db_file
#  - db should be a database name, db version the version of that db
#    db_file the file system location of that database, 
#    probably wiser to generate from just db and configurations
# program, program_version,program_file
#  - The binary used to create a feature. Similar semantic to above
# module, module_version
#  - Perl module names (RunnableDBS usually) executing this analysis.
# parameters a paramter string which is processed by the perl module
# gff_source, gff_feature 
#  - how to make a gff dump from features with this analysis


CREATE TABLE analysis (

  analysis_id                 int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  created                     datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  logic_name                  varchar(40) not null,
  db                          varchar(120),
  db_version                  varchar(40),
  db_file                     varchar(120),
  program                     varchar(80),
  program_version             varchar(40),
  program_file                varchar(80),
  parameters                  varchar(255),
  module                      varchar(80),
  module_version              varchar(40),
  gff_source                  varchar(40),
  gff_feature                 varchar(40),

  PRIMARY KEY (analysis_id),
  KEY logic_name_idx( logic_name )

);

