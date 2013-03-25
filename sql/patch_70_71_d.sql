# patch_70_71_d.sql
#
# Title: hmm_profile_key
#
# Description: Update primary key in hmm_profile

ALTER TABLE hmm_profile DROP PRIMARY KEY, ADD PRIMARY KEY (model_id, type);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_70_71_d.sql|hmm_profile_key');

