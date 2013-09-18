# patch_73_74_b.sql
#
# Title: Compress the HMM profiles
#
# Description:
#   Change the type of the HMM profile from TEXT to BLOB
#   They are now compressed with zlib to save sapce (~6x smaller)

ALTER TABLE hmm_profile ADD COLUMN compressed_profile MEDIUMBLOB AFTER hc_profile;
UPDATE hmm_profile SET compressed_profile = COMPRESS(hc_profile);
ALTER TABLE hmm_profile DROP COLUMN hc_profile;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_b.sql|hmm_profile');
