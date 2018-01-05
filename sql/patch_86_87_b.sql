-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# patch_86_87_b.sql
#
# Title: New table with gene quality information from the geneset_QC pipeline.
#
# Description:
#   This table contains gene quality information from the geneset_QC pipeline

SET session sql_mode='TRADITIONAL';

CREATE TABLE gene_member_qc (

  gene_member_stable_id       varchar(128) NOT NULL,
  genome_db_id                int(10) unsigned NOT NULL,
  seq_member_id               int(10),
  n_species                   INT,
  n_orth                      INT,
  avg_cov                     FLOAT,
  status                      varchar(50) NOT NULL,

  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),

  key (gene_member_stable_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_86_87_b.sql|gene_member_qc');
