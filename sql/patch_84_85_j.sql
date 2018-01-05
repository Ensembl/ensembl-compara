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

# patch_84_85_j.sql
#
# Title: Add new table to store method link species set attributes
#
# Description:
#   Add new _attr table that can be used to store information (tags)

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

/**
@table method_link_species_set_attr
@desc This table contains the distribution of the gene order conservation scores 
@colour   #1E90FF
@column method_link_species_set_id          internal unique ID for the orthologs
@column goc_null                            the number of orthologs for with no neighbors
@column goc_0                               the number of orthologs with no gene order conservation among their neighbours
@column goc_25                              the number of orthologs with 25% gene order conservation among their neighbours
@column goc_50                              the number of orthologs with 50% gene order conservation among their neighbours
@column goc_75                              the number of orthologs with 75% gene order conservation among their neighbours
@column goc_100                             the number of orthologs with 100% gene order conservation among their neighbours
@column goc_quality_threshold               the chosen threshold for "high quality" orthologs based on gene order conservation
@column perc_orth_above_goc_thresh          the percentage of orthologs above the goc threshold 
@column wga_quality_threshold               the chosen threshold for "high quality" orthologs based on the whole genome alignments coverage of homologous pairs
@column perc_orth_above_wga_thresh          the percentage of orthologs above the wga threshold
@column threshold_on_ds

@see method_link_species_set
@see ortholog_goc_metric
@see homology
*/

CREATE TABLE method_link_species_set_attr (
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK method_link_species_set.method_link_species_set_id
  n_goc_null                    int,
  n_goc_0                       int,
  n_goc_25                      int,
  n_goc_50                      int,
  n_goc_75                      int,
  n_goc_100                     int,
  perc_orth_above_goc_thresh  float,
  goc_quality_threshold       int,
  wga_quality_threshold       int,
  perc_orth_above_wga_thresh  float,
  threshold_on_ds             int,

  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  PRIMARY KEY (method_link_species_set_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;



# Populate the new table with NULLs
INSERT IGNORE INTO method_link_species_set_attr (method_link_species_set_id) SELECT method_link_species_set_id FROM method_link_species_set_tag
  WHERE tag IN ("n_goc_null","n_goc_0","n_goc_25","n_goc_50","n_goc_75","n_goc_100","perc_orth_above_goc_thresh","goc_quality_threshold",
  "wga_quality_threshold","perc_orth_above_wga_thresh","threshold_on_ds");

UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.n_goc_null = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'n_goc_null' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.n_goc_0 = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'n_goc_0' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.n_goc_25 = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'n_goc_25' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.n_goc_50 = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'n_goc_50' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.n_goc_75 = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'n_goc_75' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.n_goc_100 = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'n_goc_100' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.perc_orth_above_goc_thresh = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'perc_orth_above_goc_thresh' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.goc_quality_threshold = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'goc_quality_threshold' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.wga_quality_threshold = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'wga_quality_threshold' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.perc_orth_above_wga_thresh = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'perc_orth_above_wga_thresh' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;
UPDATE method_link_species_set_attr, method_link_species_set_tag SET method_link_species_set_attr.threshold_on_ds = method_link_species_set_tag.value WHERE method_link_species_set_tag.tag = 'threshold_on_ds' AND method_link_species_set_attr.method_link_species_set_id = method_link_species_set_tag.method_link_species_set_id;

DELETE FROM method_link_species_set_tag WHERE tag IN ( 'n_goc_null','n_goc_0','n_goc_25','n_goc_50','n_goc_75',
  'n_goc_100','perc_orth_above_goc_thresh','goc_quality_threshold','wga_quality_threshold','perc_orth_above_wga_thresh','threshold_on_ds');

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_j.sql|method_link_species_set_attr');
