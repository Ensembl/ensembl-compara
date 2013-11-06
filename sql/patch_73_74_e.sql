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
  SET new_description = CASE
    WHEN description IN ('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog') THEN description
    WHEN description = "apparent_ortholog_one2one" THEN "ortholog_one2one"
    WHEN description IN ("contiguous_gene_split", "putative_gene_split") THEN "gene_split"
    WHEN description IN ('projection_unchanged','projection_altered') THEN "alt_allele",
  SET is_tree_compliant = CASE
    WHEN description IN ('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog') AND node_type != "dubious" THEN 1
    WHEN description = "contiguous_gene_split" THEN 1
    ELSE 0
;

DELETE FROM homology
  WHERE description = "possible_ortholog";

ALTER TABLE homology
  DROP COLUMN description,
  CHANGE new_description description ENUM('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','gene_split','between_species_paralog','alt_allele');

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_e.sql|homology_types');
