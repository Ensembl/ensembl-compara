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

# patch_83_84_b.sql
#
# Title: Add new table to store gene tree attributes
#
# Description:
#   Add new _attr table that can be used to store information (tags)

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

/**
@table gene_tree_root_attr
@desc  This table contains several gene tree attributes data attached to root_ids
@colour   #1E90FF

@column root_id                             External reference to root_id in the @link gene_tree_root table.
@column aln_after_filter_length             Alignment length after filtering.
@column aln_length                          Alignment length before filtering.
@column aln_num_residues                    Total number of residues in the whole alignment.
@column aln_percent_identity                Alignment identity.
@column best_fit_model_family               Best Amino Acid replacement evolution model (WAG, JTT, etc).
@column best_fit_model_parameter            Best paremeters used in the model (I, G, IG, IGF, etc).
@column gene_count                          Number of sequences present in the alignment.
@column k_score                             Tree distance metric.
@column k_score_rank                        Rank of the tree in the comparison.
@column mcoffee_scores_gene_align_id        Gene alignment ID, used to fetch the mcoffee scores used in the alignment.
@column aln_n_removed_columns               Number of colunms that were removed by the alignment filtering process.
@column aln_num_of_patterns                 Number of different patterns present in the alignment (used by ExaML).
@column aln_shrinking_factor                Factor used to measure how much the alignments were filtered (factor: 0..1).
@column spec_count                          Number of different species present in the cluster
@column tree_max_branch                     Maximum branch length.
@column tree_max_length                     Maximum tree length.
@column tree_num_dup_nodes                  Number of duplication nodes.
@column tree_num_leaves                     Number of leaves in a tree.
@column tree_num_spec_nodes                 Number of speciation events.

@see gene_tree_root
@see gene_tree_root_tag
*/

CREATE TABLE `gene_tree_root_attr` (
  root_id                           INT(10) UNSIGNED NOT NULL,
  aln_after_filter_length           INT(10) UNSIGNED,
  aln_length                        INT(10) UNSIGNED,
  aln_num_residues                  INT(10) UNSIGNED,
  aln_percent_identity              FLOAT(5),
  best_fit_model_family             VARCHAR(10),
  best_fit_model_parameter          VARCHAR(5),
  gene_count                        INT(10) UNSIGNED,
  k_score                           FLOAT(5),
  k_score_rank                      INT(10) UNSIGNED, 
  mcoffee_scores_gene_align_id      INT(10) UNSIGNED,      
  aln_n_removed_columns             INT(10) UNSIGNED,
  aln_num_of_patterns               INT(10) UNSIGNED, 
  aln_shrinking_factor              FLOAT(2),
  spec_count                        INT(10) UNSIGNED,
  tree_max_branch                   DEC(8,2),
  tree_max_length                   FLOAT(5),
  tree_num_dup_nodes                INT(10) UNSIGNED,
  tree_num_leaves                   INT(10) UNSIGNED,
  tree_num_spec_nodes               INT(10) UNSIGNED,

  FOREIGN KEY (root_id) REFERENCES gene_tree_root(root_id),

  PRIMARY KEY (root_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

ALTER TABLE gene_tree_root_tag ADD KEY (tag);

# Populate the new table with NULLs
INSERT IGNORE INTO gene_tree_root_attr (root_id) SELECT root_id FROM gene_tree_root_tag WHERE tag IN ("after_filter_length","aln_length","aln_num_residues","aln_percent_identity","best_fit_model_family","best_fit_model_parameter","gene_count","k_score","k_score_rank","mcoffee_scores","n_removed_columns","num_of_patterns","shrinking_factor","spec_count","tree_max_branch","tree_max_length","tree_num_dup_nodes","tree_num_leaves","tree_num_spec_nodes");

UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.aln_after_filter_length = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'after_filter_length' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.aln_length = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'aln_length' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.aln_num_residues = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'aln_num_residues' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.aln_percent_identity = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'aln_percent_identity' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.best_fit_model_family = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'best_fit_model_family' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.best_fit_model_parameter = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'best_fit_model_parameter' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.gene_count = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'gene_count' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.k_score = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'k_score' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.k_score_rank = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'k_score_rank' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.mcoffee_scores_gene_align_id = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'mcoffee_scores' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.aln_n_removed_columns = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'n_removed_columns' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.aln_num_of_patterns = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'num_of_patterns' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.aln_shrinking_factor = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'shrinking_factor' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.spec_count = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'spec_count' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.tree_max_branch = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'tree_max_branch' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.tree_max_length = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'tree_max_length' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.tree_num_dup_nodes = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'tree_num_dup_nodes' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.tree_num_leaves = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'tree_num_leaves' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;
UPDATE gene_tree_root_attr, gene_tree_root_tag SET gene_tree_root_attr.tree_num_spec_nodes = gene_tree_root_tag.value WHERE gene_tree_root_tag.tag = 'tree_num_spec_nodes' AND gene_tree_root_attr.root_id = gene_tree_root_tag.root_id;

DELETE FROM gene_tree_root_tag WHERE tag IN ( 'after_filter_length','aln_length','aln_num_residues','aln_percent_identity','best_fit_model_family','best_fit_model_parameter','gene_count','k_score','k_score_rank','mcoffee_scores','n_removed_columns','num_of_patterns','shrinking_factor','spec_count','tree_max_branch','tree_max_length','tree_num_dup_nodes','tree_num_leaves','tree_num_spec_nodes');

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_83_84_b.sql|gene_tree_attributes_table');
