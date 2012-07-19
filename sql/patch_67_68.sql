
-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

-- Unique keys promoted to primary keys
ALTER TABLE method_link_species_set_tag 
DROP KEY tag_mlss_id, 
ADD PRIMARY KEY tag_mlss_id (method_link_species_set_id,tag);

ALTER TABLE subset_member 
DROP KEY subset_member_id, 
ADD PRIMARY KEY subset_member_id (subset_id, member_id);

ALTER TABLE sequence_exon_bounded 
DROP PRIMARY KEY, DROP KEY member_id, 
DROP COLUMN sequence_exon_bounded_id, 
ADD PRIMARY KEY (member_id);

ALTER TABLE sequence_cds
DROP PRIMARY KEY,
DROP KEY member_id,
DROP COLUMN sequence_cds_id,
ADD PRIMARY KEY (member_id);

ALTER TABLE family_member
DROP KEY family_member_id,
ADD PRIMARY KEY family_member_id (family_id,member_id);

ALTER TABLE gene_tree_member
DROP KEY node_id,
ADD PRIMARY KEY (node_id);

-- clusterset_id is now a string
-- NOTE, NULL values in this field are 'truncated' in this step, so we
-- set NULLs to 1 first, then update all values
UPDATE gene_tree_root SET clusterset_id = 1 WHERE clusterset_id IS NULL;
ALTER TABLE gene_tree_root
MODIFY COLUMN clusterset_id VARCHAR(20) NOT NULL DEFAULT 'default';
UPDATE gene_tree_root SET clusterset_id = "default";

-- New (generic) name
ALTER TABLE nc_profile
RENAME hmm_profile,
MODIFY COLUMN model_id VARCHAR(40) NOT NULL,
MODIFY COLUMN type VARCHAR(40) NOT NULL,
ADD COLUMN consensus MEDIUMTEXT;

-- New version
REPLACE INTO meta (species_id, meta_key, meta_value)
VALUES (NULL, 'schema_version', '68');
