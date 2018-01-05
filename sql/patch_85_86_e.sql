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

# patch_85_86_e.sql
#
# Title: New table with the homology counts of each member
#
# Description:
#   These stats used to be in the gene_member table but are now
#   moved to a separate table so that we can store stats about
#   multiple collections

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

CREATE TABLE gene_member_hom_stats (
  gene_member_id              int(10) unsigned NOT NULL, # FK gene_member.gene_member_id
  collection                  varchar(40) NOT NULL,
  `families`                 int(10) unsigned NOT NULL default 0,
  `gene_trees`               tinyint(1) unsigned NOT NULL default 0,
  `gene_gain_loss_trees`     tinyint(1) unsigned NOT NULL default 0,
  `orthologues`              int(10) unsigned NOT NULL default 0,
  `paralogues`               int(10) unsigned NOT NULL default 0,
  `homoeologues`             int(10) unsigned NOT NULL default 0,

  FOREIGN KEY (gene_member_id) REFERENCES gene_member(gene_member_id),

  PRIMARY KEY (gene_member_id, collection)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

INSERT INTO gene_member_hom_stats
SELECT gene_member_id, "default", families, gene_trees, gene_gain_loss_trees, orthologues, paralogues, homoeologues
FROM gene_member;

ALTER TABLE gene_member
DROP COLUMN families,
DROP COLUMN gene_trees,
DROP COLUMN gene_gain_loss_trees,
DROP COLUMN orthologues,
DROP COLUMN paralogues,
DROP COLUMN homoeologues;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_85_86_e.sql|gene_member_hom_stats');
