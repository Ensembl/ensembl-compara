
# Updating the schema version

DELETE FROM meta WHERE meta_key="schema_version";
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",41);

# Add displayable column to analysis_description table

ALTER TABLE analysis_description ADD COLUMN displayable BOOLEAN DEFAULT 1 NOT NULL;

# Add display_label column to member table

ALTER TABLE member ADD COLUMN display_label VARCHAR(128) DEFAULT NULL;

# Add ancestor_node_id to homology table

ALTER TABLE homology ADD COLUMN node_id int(10) unsigned DEFAULT NULL;

# change description column in member table from varchar(255) to text

ALTER TABLE member MODIFY COLUMN description TEXT DEFAULT NULL;
