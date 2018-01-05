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

# patch_84_85_i.sql
#
# Title: Add new table to store species tree node attributes
#
# Description:
#   Add new _attr table that can be used to store information (tags)

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

/**
@table species_tree_node_attr               this table contains the attribute calculated for each species tree node
@column node_id                             Internal unique ID
@column nb_long_genes                       the number of genes longer than the avg length of their orthologs
@column nb_short_genes                      the number of genes shorter than the avg length of their orthologs
@column avg_dupscore                        the average duplication score
@column avg_dupscore_nondub                 avg_dupscore_nondub
@column nb_dubious_nodes                    nb_dubious_nodes
@column nb_dup_nodes                        nb_dup_nodes
@column nb_genes                            the number of genes
@column nb_genes_in_tree                    the number of genes in the tree 
@column nb_genes_in_tree_multi_species      nb_genes_in_tree_multi_species
@column nb_genes_in_tree_single_species     nb_genes_in_tree_single_species
@column nb_nodes                            the number of nodes
@column nb_orphan_genes                     nb_orphan_genes
@column nb_seq                              the number of sequences
@column nb_spec_nodes                       nb_spec_nodes
@column nb_gene_splits                      the number of split gene events
@column nb_split_genes                      the number of split genes
@column root_avg_gene                       root_avg_gene
@column root_avg_gene_per_spec              root_avg_gene_per_spec
@column root_avg_spec                       root_avg_spec
@column root_max_gene                       root_max_gene
@column root_max_spec                       root_max_spec
@column root_min_gene                       root_min_gene
@column root_min_spec                       root_min_spec
@column root_nb_genes                       root_nb_genes
@column root_nb_trees                       root_nb_trees


@see species_tree_node
@see species_tree_root
*/



CREATE TABLE species_tree_node_attr (
  node_id                                 int(10) unsigned NOT NULL,
  nb_long_genes                           int,
  nb_short_genes                          int,
  avg_dupscore                            float,
  avg_dupscore_nondub                     float,
  nb_dubious_nodes                        int,
  nb_dup_nodes                            int,
  nb_genes                               int,
  nb_genes_in_tree                       int,
  nb_genes_in_tree_multi_species         int,
  nb_genes_in_tree_single_species        int,
  nb_nodes                               int,
  nb_orphan_genes                        int,
  nb_seq                                 int,
  nb_spec_nodes                          int,
  nb_gene_splits                         int,
  nb_split_genes                         int,
  root_avg_gene                          float,
  root_avg_gene_per_spec                 float,
  root_avg_spec                          float,
  root_max_gene                          int,
  root_max_spec                          int,
  root_min_gene                          int,
  root_min_spec                          int,
  root_nb_genes                          int,
  root_nb_trees                          int,

  FOREIGN KEY (node_id) REFERENCES species_tree_node(node_id),
  PRIMARY KEY (node_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

# Populate the new table with NULLs
INSERT IGNORE INTO species_tree_node_attr (node_id) SELECT node_id FROM species_tree_node_tag 
  WHERE tag IN ("nb_long_genes","nb_short_genes","avg_dupscore","avg_dupscore_nondub","nb_dubious_nodes","nb_dup_nodes","nb_genes","nb_genes_in_tree",
  "nb_genes_in_tree_multi_species","nb_genes_in_tree_single_species","nb_nodes","nb_orphan_genes","nb_seq","nb_spec_nodes","nb_gene_splits",
  "nb_split_genes","root_avg_gene","root_avg_gene_per_spec","root_avg_spec","root_max_gene","root_max_spec","root_min_gene","root_min_spec","root_nb_genes","root_nb_trees");

UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_long_genes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_long_genes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_short_genes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_short_genes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.avg_dupscore = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'avg_dupscore' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.avg_dupscore_nondub = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'avg_dupscore_nondub' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_dubious_nodes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_dubious_nodes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_dup_nodes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_dup_nodes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_genes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_genes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_genes_in_tree = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_genes_in_tree' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_genes_in_tree_multi_species = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_genes_in_tree_multi_species' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_genes_in_tree_single_species = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_genes_in_tree_single_species' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_nodes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_nodes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_orphan_genes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_orphan_genes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_seq = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_seq' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_spec_nodes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_spec_nodes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_gene_splits = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_gene_splits' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.nb_split_genes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'nb_split_genes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.root_avg_gene = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'root_avg_gene' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.root_avg_gene_per_spec = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'root_avg_gene_per_spec' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.root_avg_spec = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'root_avg_spec' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.root_max_gene = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'root_max_gene' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.root_max_spec = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'root_max_spec' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.root_min_gene = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'root_min_gene' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.root_min_spec = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'root_min_spec' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.root_nb_genes = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'root_nb_genes' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;
UPDATE species_tree_node_attr, species_tree_node_tag SET species_tree_node_attr.root_nb_trees = species_tree_node_tag.value WHERE species_tree_node_tag.tag = 'root_nb_trees' AND species_tree_node_attr.node_id = species_tree_node_tag.node_id;

DELETE FROM species_tree_node_tag WHERE tag IN ( 'nb_long_genes','nb_short_genes','avg_dupscore','avg_dupscore_nondub','nb_dubious_nodes',
  'nb_dup_nodes','gene_count','nb_genes','nb_genes_in_tree','nb_genes_in_tree_multi_species','nb_genes_in_tree_single_species','nb_nodes',
  'nb_orphan_genes','nb_seq','nb_spec_nodes','nb_gene_splits','nb_split_genes','root_avg_gene','root_avg_gene_per_spec',"root_avg_spec","root_max_gene",
  "root_max_spec","root_min_gene","root_min_spec","root_nb_genes","root_nb_trees");

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_i.sql|species_tree_node_attr');
