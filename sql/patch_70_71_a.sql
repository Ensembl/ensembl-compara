# patch_70_71_a.sql
#
# Title: other_member_sequence_keys
#
# Description: Update keys and column types in other_member_sequence

ALTER TABLE other_member_sequence DROP KEY seq_type, DROP KEY sequence, MODIFY COLUMN sequence mediumtext not null;


# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_70_71_a.sql|other_member_sequence_keys');

