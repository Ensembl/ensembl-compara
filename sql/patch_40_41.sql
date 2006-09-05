
# Updating the schema version

DELETE FROM meta WHERE meta_key="schema_version";
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",41);

# Add displayable column to analysis_description table

ALTER TABLE analysis_description ADD COLUMN displayable BOOLEAN DEFAULT 1 NOT NULL;

# Add display_label column to member table

ALTER TABLE member ADD COLUMN display_label VARCHAR(128) DEFAULT NULL