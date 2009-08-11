# Updating the schema version

UPDATE meta SET meta_value = 56 where meta_key = "schema_version";


# Add strand info to constrained_element for EPO anchor generation

alter table constrained_element add column dnafrag_strand int(2);


-- Adding lr_index_offset if not already there (introduced into 55
-- post release).
CREATE TABLE IF NOT EXISTS lr_index_offset (
	table_name  varchar(64) NOT NULL,
	lr_index    int(10) unsigned NOT NULL,

	PRIMARY KEY (table_name)
) COLLATE=latin1_swedish_ci;


-- Increasing the size of 3 columns in analysis
ALTER TABLE analysis MODIFY COLUMN db_file varchar(255);
ALTER TABLE analysis MODIFY COLUMN program varchar(255);
ALTER TABLE analysis MODIFY COLUMN program_file varchar(255);
