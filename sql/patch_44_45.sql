
# Updating the schema version

UPDATE meta SET meta_value = 45 where meta_key = "schema_version";

# Add new column in the genomic_align_block table

ALTER TABLE genomic_align_block ADD group_id bigint unsigned DEFAULT NULL;

# Move "default" and "split" groups to the new column

UPDATE genomic_align_block gab, genomic_align ga, genomic_align_group gag SET gab.group_id = gag.group_id
 WHERE gab.genomic_align_block_id = ga.genomic_align_block_id AND ga.genomic_align_id = gag.genomic_align_id
 AND gag.type IN ("default", "split");

DELETE FROM genomic_align_group WHERE type IN ("default", "split");

