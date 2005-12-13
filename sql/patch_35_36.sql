alter table genomic_align_group change group_id  group_id bigint(20) unsigned NOT NULL auto_increment;
delete from meta where meta_key="schema_version";
insert into meta (meta_key,meta_value) values ("schema_version",36);
