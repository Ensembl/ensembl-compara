# Updating the schema version

UPDATE meta SET meta_value = 52 where meta_key = "schema_version";

#Update sitewise_aln table
ALTER TABLE sitewise_aln ADD COLUMN optimal float(10,5) AFTER omega_upper;
ALTER TABLE sitewise_aln ADD COLUMN ncod int(10) AFTER optimal;
ALTER TABLE sitewise_aln ADD INDEX (tree_node_id);
ALTER TABLE sitewise_aln MODIFY COLUMN type
ENUM('all_gaps','constant','default','negative1','negative2','negative3','negative4','positive1','positive2','positive3','positive4','synonymous') NOT NULL;

#Change from varchar to enum field
ALTER TABLE homology MODIFY COLUMN description
ENUM('ortholog_one2one','apparent_ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','between_species_paralog');
