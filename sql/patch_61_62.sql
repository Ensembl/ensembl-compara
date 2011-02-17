# Updating the schema version:
UPDATE meta SET meta_value = 62 where meta_key = "schema_version";

# extending analysis.module field to 255 characters (used to be 80, which is too limiting):
ALTER TABLE analysis MODIFY COLUMN module varchar(255);

# extending the length of meta.meta_value to text
ALTER TABLE meta DROP INDEX species_key_value_idx;
ALTER TABLE meta DROP INDEX species_value_idx;
ALTER TABLE meta MODIFY COLUMN meta_value TEXT;
ALTER TABLE meta ADD UNIQUE KEY species_key_value_idx (species_id,meta_key,meta_value(255));
ALTER TABLE meta ADD        KEY species_value_idx (species_id,meta_value(255));

# Done to alter the mapping session code
alter table mapping_session drop index `type`;
alter table mapping_session add column prefix CHAR(4);
update mapping_session set prefix = 'ENS';
alter table mapping_session modify column prefix CHAR(4) NOT NULL;

alter table mapping_session add index `type` (`type`,`rel_from`,`rel_to`, `prefix`);
