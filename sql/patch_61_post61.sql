# extending analysis.module field to 255 characters (used to be 80, which is too limiting):
ALTER TABLE analysis MODIFY COLUMN module varchar(255);

# Done to alter the mapping session code
alter table mapping_session add column prefix CHAR(4);
update mapping_session set prefix = 'ENS';
alter table mapping_session alter column prefix CHAR(4) NOT NULL;

alter table mapping_session drop index `type`;
alter table mapping_session add index `type` (`type`,`rel_from`,`rel_to`, `prefix`);