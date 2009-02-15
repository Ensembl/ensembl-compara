/* The following SQL removes all of the pipeline and hive tables added
   to the compara database as part of the production process */

/* from ensembl-compara/sql/pipeline-tables.sql */
DROP TABLE subset;
DROP TABLE subset_member;
DROP TABLE genome_db_extn;
DROP TABLE genome_db_stats;
DROP TABLE dnafrag_chunk;
DROP TABLE dnafrag_chunk_set;
DROP TABLE dna_collection;
DROP TABLE genomic_align_block_job_track;

/* from  ensembl-hive/sql/tables.sql */
DROP TABLE hive;
DROP TABLE dataflow_rule;
DROP TABLE analysis_ctrl_rule;
DROP TABLE analysis_job;
DROP TABLE analysis_job_file;
DROP TABLE analysis_data;
DROP TABLE analysis_stats;
DROP TABLE analysis_stats_monitor;
DROP TABLE monitor;


