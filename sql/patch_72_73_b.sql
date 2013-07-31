# patch_72_73_b.sql
#
# Title: Allows homologies not to be linked to gene-trees
#
# Description:
#   Change the ancestor_node_id and tree_node_id columns in the homology
#   table to allow NULL. This is needed for the gene projections between
#   the reference sequence and the patch regions.

ALTER TABLE homology MODIFY COLUMN ancestor_node_id int(10) unsigned;
ALTER TABLE homology MODIFY COLUMN tree_node_id     int(10) unsigned;
UPDATE homology SET ancestor_node_id = NULL WHERE ancestor_node_id = 0;
UPDATE homology SET tree_node_id     = NULL WHERE tree_node_id     = 0;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_72_73_b.sql|homology_genetree_links');
