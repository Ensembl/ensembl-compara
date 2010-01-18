# modifications to be applied to pre-57 databases to bring them to rel-57 state

ALTER TABLE genomic_align_group DROP KEY genomic_align_id;

ALTER TABLE genomic_align_group DROP COLUMN type;
ALTER TABLE genomic_align_group CHANGE group_id node_id bigint unsigned NOT NULL AUTO_INCREMENT;

#ALTER TABLE genomic_align_group ADD KEY node_id(node_id);
#ALTER TABLE genomic_align_group DROP KEY group_id;
ALTER TABLE genomic_align_group ADD UNIQUE KEY genomic_align_id(genomic_align_id);

