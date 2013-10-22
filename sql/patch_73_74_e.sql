# patch_73_74_e.sql
#
# Title: Updates the homology type and adds the "is_tree_compliant" column
#
# Description:
#   Creates a new column in the homology table: "is_tree_compliant"
#    and cleans up the list of possible homology types

SET session sql_mode='TRADITIONAL';

ALTER TABLE homology
  ADD COLUMN new_description ENUM('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog', 'gene_split','between_species_paralog','alt_allele') AFTER description,
  ADD COLUMN is_tree_compliant tinyint(1) NOT NULL DEFAULT 0 AFTER new_description;


UPDATE homology JOIN gene_tree_node_attr ON ancestor_node_id = node_id
  SET new_description = description, is_tree_compliant = IF (node_type = "dubious", 0, 1)
  WHERE description IN ('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog');

UPDATE homology
  SET new_description = "ortholog_one2one"
  WHERE description = "apparent_ortholog_one2one";

UPDATE homology
  SET new_description = "gene_split", is_tree_compliant = 1
  WHERE description = "contiguous_gene_split";

UPDATE homology
  SET new_description = "gene_split"
  WHERE description = "putative_gene_split";

UPDATE homology
  SET new_description = 'alt_allele';
  WHERE description IN ('projection_unchanged','projection_altered');

DELETE FROM homology
  WHERE description = "possible_ortholog";

ALTER TABLE homology
  DROP COLUMN description,
  CHANGE new_description description ENUM('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','gene_split','between_species_paralog','alt_allele');

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_e.sql|homology_types');
