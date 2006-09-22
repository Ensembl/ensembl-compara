
# Updating the schema version

DELETE FROM meta WHERE meta_key="schema_version";
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",40);

# add table structure for table 'conservation_score'

CREATE TABLE conservation_score (
  genomic_align_block_id bigint unsigned not null,
  window_size            smallint unsigned not null,
  position	         int unsigned not null,
  observed_score         blob,
  expected_score         blob,
  diff_score             blob,

  KEY (genomic_align_block_id, window_size)
) MAX_ROWS = 15000000 AVG_ROW_LENGTH = 841 COLLATE=latin1_swedish_ci;
