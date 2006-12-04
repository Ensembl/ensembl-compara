
# Updating the schema version

DELETE FROM meta WHERE meta_key="schema_version";
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",42);

# Add a UNIQUE constraint to the analysis_description.analysis_id

ALTER TABLE analysis_description DROP INDEX analysis_idx;
ALTER TABLE analysis_description ADD UNIQUE analysis_idx (analysis_id);

# description: Add web_data column to analysis_description.

ALTER TABLE analysis_description ADD COLUMN web_data TEXT;

# Add a PRIMARY KEY to the ncbi_taxa_node.taxon_id

ALTER TABLE ncbi_taxa_node DROP INDEX taxon_id;
ALTER TABLE ncbi_taxa_node ADD PRIMARY KEY (taxon_id);
