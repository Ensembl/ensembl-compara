# Updating the schema version

UPDATE meta SET meta_value = 55 where meta_key = "schema_version";

-- First creation of lr_index which was introduced into 55 after
-- the branch. 56 patches also have this table but will only create it if
-- does not already exist
CREATE TABLE lr_index_offset (
	table_name  varchar(64) NOT NULL,
	lr_index    int(10) unsigned NOT NULL,

	PRIMARY KEY (table_name)
) COLLATE=latin1_swedish_ci;
