# Table structure for table 'method_link_species_set_tag'
CREATE TABLE method_link_species_set_tag (
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK species_set.species_set_id
  tag                         varchar(50) NOT NULL,
  value                       mediumtext,

  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  UNIQUE KEY tag_mlss_id (method_link_species_set_id,tag)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

#Add level_id to genomic_align_block
ALTER TABLE genomic_align_block 
      ADD COLUMN level_id tinyint(2) unsigned DEFAULT 0 NOT NULL;

#Populate genomic_align_block level_id
UPDATE genomic_align_block gab, genomic_align ga SET gab.level_id = ga.level_id WHERE gab.genomic_align_block_id = ga.genomic_align_block_id;

#Remove level_id from genomic_align
ALTER TABLE genomic_align
      DROP COLUMN level_id;

#Add visible column used for self alignments
#Add node_id
ALTER TABLE genomic_align
      ADD COLUMN visible tinyint(2) unsigned DEFAULT 1 NOT NULL,
      ADD COLUMN node_id bigint(20) unsigned DEFAULT NULL;

ALTER TABLE genomic_align
      ADD KEY node_id(node_id);

#Populate the genomic_align node_id
UPDATE genomic_align ga, genomic_align_group gag SET ga.node_id = gag.node_id WHERE ga.genomic_align_id = gag.genomic_align_id;

#Remove genomic_align_group table
DROP TABLE genomic_align_group;

#Update taxon_id field of genome_db table
ALTER TABLE genome_db 
      MODIFY COLUMN taxon_id int(10) unsigned DEFAULT NULL; # KF taxon.taxon_id

#
#
# Updating the schema version
UPDATE meta SET meta_value = 66 where meta_key = "schema_version";

