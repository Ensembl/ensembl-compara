-- Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

# patch_83_84.sql
#
# Title: Add new table to store gene tree attributes
#
# Description:
#   Add new _attr table that can be used to store information (tags)
#   this is an improvement over the _tag mechanism since the fields are now
#   searchable by SQL.


/**
@table gene_tree_root_attr
@desc  This table contains several gene tree attributes data attached to root_ids
@colour   #1E90FF

@column root_id                             External reference to root_id in the @link gene_tree_root table.
@column after_filter_length                 Alignment length after filtering.
@column aln_length                          Alignment length before filtering.
@column aln_num_residues                    Total number of residues in the whole alignment.
@column aln_percent_identity                Alignment identity.
@column best_fit_model_family               Best Amino Acid replacement evolution model (WAG, JTT, etc).
@column best_fit_model_parameter            Best paremeters used in the model (I, G, IG, IGF, etc).
@column gene_count                          Number of sequences present in the alignment.
@column k_score                             Tree distance metric.
@column k_score_rank                        Rank of the tree in the comparison.
@column mcoffee_scores_gene_align_id        Gene alignment ID, used to fetch the mcoffee scores used in the alignment.
@column model_name                          Cluster name (TF105041, PTHR26453, PTHR24420_SF637, etc).
@column n_removed_columns                   Number of colunms that were removed by the alignment filtering process.
@column num_of_patterns                     Number of different patterns present in the alignment (used by ExaML).
@column shrinking_factor                    Factor used to measure how much the alignments were filtered (factor: 0..1).
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
  after_filter_length               INT(10) UNSIGNED,
  aln_length                        INT(10) UNSIGNED,
  aln_num_residues                  INT(10) UNSIGNED,
  aln_percent_identity              FLOAT(5,5)
  best_fit_model_family             VARCHAR(10),
  best_fit_model_parameter          VARCHAR(5),
  gene_count                        INT(10) UNSIGNED,
  k_score                           FLOAT(5,5)
  k_score_rank                      INT(10) UNSIGNED, 
  mcoffee_scores_gene_align_id      INT(10) UNSIGNED,      
  model_name                        VARCHAR(25),
  n_removed_columns                 INT(10) UNSIGNED,
  num_of_patterns                   INT(10) UNSIGNED, 
  shrinking_factor                  FLOAT(2,5)
  spec_count                        INT(10) UNSIGNED,
  tree_max_branch                   FLOAT(4,5)
  tree_max_length                   FLOAT(4,5) 
  tree_num_dup_nodes                INT(10) UNSIGNED,
  tree_num_leaves                   INT(10) UNSIGNED,
  tree_num_spec_nodes               INT(10) UNSIGNED,

  FOREIGN KEY (root_id) REFERENCES gene_tree_root(root_id),

  PRIMARY KEY (root_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

# Populate the new table
INSERT INTO gene_tree_root_attr (root_id, after_filter_length) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'after_filter_length';
INSERT INTO gene_tree_root_attr (root_id, aln_length) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'aln_length';
INSERT INTO gene_tree_root_attr (root_id, aln_num_residues) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'aln_num_residues';
INSERT INTO gene_tree_root_attr (root_id, aln_percent_identity) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'aln_percent_identity';
INSERT INTO gene_tree_root_attr (root_id, best_fit_model_family) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'best_fit_model_family';
INSERT INTO gene_tree_root_attr (root_id, best_fit_model_parameter) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'best_fit_model_parameter';
INSERT INTO gene_tree_root_attr (root_id, gene_count) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'gene_count';
INSERT INTO gene_tree_root_attr (root_id, k_score) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'k_score';
INSERT INTO gene_tree_root_attr (root_id, k_score_rank) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'k_score_rank';
INSERT INTO gene_tree_root_attr (root_id, mcoffee_scores_gene_align_id) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'mcoffee_scores';
INSERT INTO gene_tree_root_attr (root_id, model_name) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'model_name';
INSERT INTO gene_tree_root_attr (root_id, n_removed_columns) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'n_removed_columns';
INSERT INTO gene_tree_root_attr (root_id, num_of_patterns) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'num_of_patterns';
INSERT INTO gene_tree_root_attr (root_id, shrinking_factor) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'shrinking_factor';
INSERT INTO gene_tree_root_attr (root_id, spec_count) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'spec_count';
INSERT INTO gene_tree_root_attr (root_id, tree_max_branch) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'tree_max_branch';
INSERT INTO gene_tree_root_attr (root_id, tree_max_length) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'tree_max_length';
INSERT INTO gene_tree_root_attr (root_id, tree_num_dup_nodes) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'tree_num_dup_nodes';
INSERT INTO gene_tree_root_attr (root_id, tree_num_leaves) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'tree_num_leaves';
INSERT INTO gene_tree_root_attr (root_id, tree_num_spec_nodes) SELECT root_id, value FROM gene_tree_root_tag WHERE tag = 'tree_num_spec_nodes';

DELETE FROM gene_tree_root_tag WHERE tag IN ( 'after_filter_length','aln_length','aln_num_residues','aln_percent_identity','best_fit_model_family','best_fit_model_parameter','gene_count','k_score','k_score_rank','mcoffee_scores','model_name','n_removed_columns','num_of_patterns','shrinking_factor','spec_count','tree_max_branch','tree_max_length','tree_num_dup_nodes','tree_num_leaves','tree_num_spec_nodes')
