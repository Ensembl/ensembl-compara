# patch_73_74_g.sql
#
# Title: Change the types in the homology_member table
#
# Description:
#   Reduces the size of the integers in the homology_member table

SET session sql_mode='TRADITIONAL';

ALTER TABLE homology_member 
	MODIFY COLUMN perc_cov tinyint unsigned default 0,
	MODIFY COLUMN perc_id  tinyint unsigned default 0,
	MODIFY COLUMN perc_pos tinyint unsigned default 0;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_g.sql|homology_perc_size');
