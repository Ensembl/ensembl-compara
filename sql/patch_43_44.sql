
# Updating the schema version

DELETE FROM meta WHERE meta_key="schema_version";
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",44);

# Drop observed score column from the conservation_score table:

ALTER TABLE conservation_score DROP COLUMN observed_score;
