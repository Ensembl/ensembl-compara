-- Updating the schema version
UPDATE meta SET meta_value = 57 where meta_key = "schema_version";

-- a partitioned table cannot have any keys but the primary key
ALTER TABLE peptide_align_feature DROP KEY qgenome_db_id;
ALTER TABLE peptide_align_feature DROP KEY hgenome_db_id;
ALTER TABLE peptide_align_feature DROP KEY analysis_id;
ALTER TABLE peptide_align_feature DROP KEY qmember_id;
ALTER TABLE peptide_align_feature DROP KEY hmember_id;
ALTER TABLE peptide_align_feature DROP KEY hmember_qgenome;
ALTER TABLE peptide_align_feature DROP KEY qmember_hgenome;

