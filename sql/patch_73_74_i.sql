# patch_73_74_i,sql
#
# Title: Links gene_tree_node_attr to species_tree_node
#
# Description:
#   Adds a new column (species_tree_node_id) in gene_tree_node_attr
#   It can be a foreign key to species_tree_node.node_id
#   taxon_id and taxon_name can be removed

SET session sql_mode='TRADITIONAL';

ALTER TABLE gene_tree_node_attr ADD species_tree_node_id INT(10) UNSIGNED;

# This assumes that the species_tree_node table has been populated by a previous patch
UPDATE gene_tree_node_attr SET species_tree_node_id = 500000000+taxon_id;

ALTER TABLE gene_tree_node_attr DROP COLUMN taxon_id, DROP COLUMN taxon_name;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_i.sql|gene_tree_node_attr.taxon_id');
