# patch_70_71_e.sql
#
# Title: Drop CAFE_data table
#
# Description: Delete production only table CAFE_data

DROP TABLE IF EXISTS CAFE_data;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_70_71_e.sql|drop_cafe_data');

