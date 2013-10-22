# patch_73_74_d.sql
#
# Title: Drops the threshold_on_ds column in homology
#
# Description:
#   Drops the threshold_on_ds column in the homology
#   table. Stores the information in mlss_tag instead

SET session sql_mode='TRADITIONAL';

INSERT INTO method_link_species_set_tag
  SELECT method_link_species_set_id, 'threshold_on_ds', threshold_on_ds
  FROM homology
  WHERE threshold_on_ds IS NOT NULL
  GROUP BY method_link_species_set_id;

ALTER TABLE homology
  DROP COLUMN threshold_on_ds;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_d.sql|threshold_on_ds');
