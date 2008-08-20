
# Updating the schema version

UPDATE meta SET meta_value = 51 where meta_key = "schema_version";

# Remove sitewise_member table from release

DROP TABLE sitewise_member;

# Update meta table schema to match core meta table (this
# is required as we use the MetaContainer from the core API)
# The rest of the patch is taken from the core patch_50_51_d.sql
#
# Title: make database multi-species capable
#
# Description:
#   Add a species_id column to the meta and coord_system table and make
#   new indexes on these tables.

-- Add the new species_id column after meta_id
ALTER TABLE meta ADD COLUMN
 species_id INT UNSIGNED DEFAULT 1 -- Default species_id is 1
                                   -- NULL means "not species specific"
 AFTER meta_id;

-- Redo the indexes on the meta table
ALTER TABLE meta DROP INDEX key_value;
ALTER TABLE meta DROP INDEX meta_key_index;
ALTER TABLE meta DROP INDEX meta_value_index;

ALTER TABLE meta
 ADD UNIQUE INDEX species_key_value_idx (species_id, meta_key, meta_value);
ALTER TABLE meta
 ADD INDEX species_value_idx (species_id, meta_value);

-- Optimize the modified tables
OPTIMIZE TABLE meta;

-- Update species_id for schema_version entry:
UPDATE meta SET species_id = NULL where meta_key = "schema_version";
