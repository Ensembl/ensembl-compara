--
-- Table structure for table `genome_db_stats`
--
-- table to hold genome level summary statistics 
-- Used by Bio::EnsEMBL::Compara::RunnableDB::GenomeCalcStats module
-- 

CREATE TABLE genome_db_stats (
  genome_db_id    int(10) NOT NULL default '0',
  data_type       varchar(20) NOT NULL,
  count           int(10) NOT NULL,
  mean            double NOT NULL default '0',
  median          double NOT NULL default '0',
  mode            double NOT NULL,
  stddev          double NOT NULL,
  variance        double NOT NULL,
  min             double NOT NULL default '0',
  max             double NOT NULL default '0',
  overlap_count   int(10) NOT NULL default '0',
  
  UNIQUE KEY genome_db_id_type (genome_db_id, data_type)
);


