-- Updating the schema version
UPDATE meta SET meta_value = 56 where meta_key = "schema_version";


-- Add strand info to constrained_element for EPO anchor generation
alter table constrained_element add column dnafrag_strand int(2);


-- Adding lr_index_offset if not already there (introduced into 55 post release).
--
-- FIXME: this change is not in the rel.56 database for some reason. Should it be?
--
CREATE TABLE IF NOT EXISTS lr_index_offset (
	table_name  varchar(64) NOT NULL,
	lr_index    int(10) unsigned NOT NULL,
	PRIMARY KEY (table_name)
) COLLATE=latin1_swedish_ci;


-- Increasing the size of 3 columns in analysis
ALTER TABLE analysis MODIFY COLUMN db_file varchar(255);
ALTER TABLE analysis MODIFY COLUMN program varchar(255);
ALTER TABLE analysis MODIFY COLUMN program_file varchar(255);


-- extra values for the enum type:
ALTER TABLE homology MODIFY COLUMN description enum('ortholog_one2one','apparent_ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','putative_gene_split','contiguous_gene_split','between_species_paralog ','UBRH','BRH','MBRH','RHS') DEFAULT NULL;


-- extra table for protein pipeline:
CREATE TABLE `protein_tree_hmmprofile` (
    `node_id` int(10) unsigned NOT NULL,
    `type` varchar(40) NOT NULL DEFAULT '',
    `hmmprofile` mediumtext,
    UNIQUE KEY `type_node_id` (`type`,`node_id`),
    KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


-- 3 more extra tables for protein pipeline:
CREATE TABLE super_protein_tree_node LIKE protein_tree_node;
CREATE TABLE super_protein_tree_member LIKE protein_tree_member;
CREATE TABLE super_protein_tree_tag LIKE protein_tree_tag;


-- FIXME: pending a reply from ensembl-compara whether this was deliberate or accidental:
--
-- RENAME TABLE peptide_align_feature TO peptide_align_feature_orig;

