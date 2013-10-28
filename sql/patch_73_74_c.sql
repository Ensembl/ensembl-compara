# patch_73_74_c.sql
#
# Title: Changes in the SpeciesTree tables
#
# Description:
#    Compara now has a new SpeciesTree object/adaptor that is now independent of
#    the CAFE analysis.

#    species_tree_root: + Now has a new column, label, to differentiate between different species trees created on the same mlss_id.
#                       + The pvalue_lim column has been dropped (It is only in the code)
#
#    species_tree_node: + Now has the new columns taxon_id, genome_db_id and node_name. This last one is needed to name differently nodes that have the same taxon_id (for example when binarizing the tree in the CAFE analysis).
#                        
#    CAFE_species_gene: + The taxon_id column has been dropped

# species_tree_root
ALTER TABLE species_tree_root ADD COLUMN `label` varchar(20) NOT NULL DEFAULT 'default' AFTER method_link_species_set_id;
ALTER TABLE species_tree_root DROP COLUMN `pvalue_lim`;

ALTER TABLE species_tree_node ADD COLUMN `taxon_id` int(10) unsigned DEFAULT NULL, ADD COLUMN `genome_db_id` int(10) unsigned DEFAULT NULL, ADD COLUMN `node_name` varchar(255) DEFAULT NULL;
UPDATE species_tree_node JOIN CAFE_species_gene USING(node_id) SET species_tree_node.taxon_id = CAFE_species_gene.taxon_id;
ALTER TABLE CAFE_species_gene DROP COLUMN taxon_id;
UPDATE species_tree_node JOIN genome_db using(taxon_id) SET species_tree_node.genome_db_id=genome_db.genome_db_id;

INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_c.sql|species_tree');

