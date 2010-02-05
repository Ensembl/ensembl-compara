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

-- this table is used for production only
DROP TABLE peptide_align_feature_prod;

--   This table holds the sequence exon boundaries information
CREATE TABLE sequence_exon_bounded (
  sequence_exon_bounded_id    int(10) unsigned NOT NULL auto_increment, # unique internal id
  member_id                   int(10) unsigned NOT NULL, # unique internal id
  length                      int(10) NOT NULL,
  sequence_exon_bounded       longtext NOT NULL,

  FOREIGN KEY (member_id) REFERENCES member(member_id),

  PRIMARY KEY (sequence_exon_bounded_id),
  KEY (member_id),
  KEY sequence_exon_bounded (sequence_exon_bounded(18))
);

