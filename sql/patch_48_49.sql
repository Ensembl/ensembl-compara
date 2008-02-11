
# Updating the schema version

UPDATE meta SET meta_value = 49 where meta_key = "schema_version";


# Creating the new genomic_align_tree table for storing tree alignments

CREATE TABLE genomic_align_tree (
  node_id                     bigint(20) unsigned NOT NULL AUTO_INCREMENT, # internal id, FK genomic_align.genomic_align_id
  parent_id                   bigint(20) unsigned NOT NULL default '0',
  root_id                     bigint(20) unsigned NOT NULL default '0',
  left_index                  int(10) NOT NULL default '0',
  right_index                 int(10) NOT NULL default '0',
  left_node_id                bigint(10) NOT NULL default '0',
  right_node_id               bigint(10) NOT NULL default '0',
  distance_to_parent          double NOT NULL default '1',

  FOREIGN KEY (node_id) REFERENCES genomic_align(genomic_align_id),

  PRIMARY KEY node_id (node_id),
  KEY parent_id (parent_id),
  KEY root_id (root_id),
  KEY left_index (left_index),
  KEY right_index (right_index)
) COLLATE=latin1_swedish_ci;
