# patch_70_71_c.sql
#
# Title: Update schema version.
#
# Description:
#   Update schema_version in meta table to 71.

DELETE FROM meta WHERE meta_key='schema_version';
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'schema_version', '71');

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_70_71_c.sql|schema_version');
