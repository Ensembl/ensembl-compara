# patch_73_74_h.sql
#
# Title: Adds a key on canonical_member_id
#
# Description:
#   Ads a key on canonical_member_id in the member table

ALTER TABLE member ADD KEY (canonical_member_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_h.sql|canonical_member');
