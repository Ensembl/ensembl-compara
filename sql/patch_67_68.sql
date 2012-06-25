
-- Unique keys promoted to primary keys
ALTER TABLE method_link_species_set_tag DROP KEY tag_mlss_id, ADD PRIMARY KEY tag_mlss_id (method_link_species_set_id,tag);
ALTER TABLE subset_member DROP KEY subset_member_id, ADD PRIMARY KEY subset_member_id (subset_id, member_id);
ALTER TABLE sequence_exon_bounded DROP PRIMARY KEY, DROP KEY member_id, DROP COLUMN sequence_exon_bounded_id, ADD PRIMARY KEY (member_id);
ALTER TABLE sequence_cds DROP PRIMARY KEY, DROP KEY member_id, DROP COLUMN sequence_cds_id, ADD PRIMARY KEY (member_id);
ALTER TABLE family_member DROP KEY family_member_id, ADD PRIMARY KEY family_member_id (family_id,member_id);
ALTER TABLE gene_tree_member DROP KEY node_id, ADD PRIMARY KEY (node_id);

-- One more foreign key
ALTER TABLE gene_tree_node ADD FOREIGN KEY (parent_id) REFERENCES gene_tree_node(node_id);

-- clusterset_id is now a string
ALTER TABLE gene_tree_root MODIFY COLUMN clusterset_id VARCHAR(20) NOT NULL;
UPDATE gene_tree_root SET clusterset_id = "default";

-- These things are now stored as tags to make them available via the API
INSERT INTO gene_tree_root_tag SELECT node_id, 'aln_score', cigar_line FROM protein_tree_member_score;
DROP TABLE protein_tree_member_score;
INSERT INTO gene_tree_root_tag SELECT node_id, CONCAT('hmm_', node_id), hmmprofile FROM protein_tree_hmmprofile;
DROP TABLE protein_tree_hmmprofile;

-- New (generic) name
ALTER TABLE nc_profile RENAME hmm_profile, MODIFY COLUMN model_id VARCHAR(40) NOT NULL, MODIFY COLUMN type VARCHAR(40) NOT NULL, ADD COLUMN consensus MEDIUMTEXT;

-- New version
REPLACE INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'schema_version', '68');
