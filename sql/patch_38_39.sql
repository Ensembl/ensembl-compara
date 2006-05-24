
# Updating the schema version

DELETE FROM meta WHERE meta_key="schema_version";
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",39);

# Renaming the old method_link_species_set table

ALTER TABLE ncbi_taxa_nodes RENAME ncbi_taxa_node;
ALTER TABLE ncbi_taxa_names RENAME ncbi_taxa_name;

# Creating new tables

CREATE TABLE protein_tree_node (
  node_id                         int(10) unsigned NOT NULL auto_increment, # unique internal id
  parent_id                       int(10) unsigned NOT NULL,
  root_id                         int(10) unsigned NOT NULL,
  left_index                      int(10) NOT NULL,
  right_index                     int(10) NOT NULL,
  distance_to_parent              double default 1.0 NOT NULL,
  
  PRIMARY KEY (node_id),
  KEY (parent_id),
  KEY (root_id),
  KEY (left_index),
  KEY (right_index)
);

CREATE TABLE protein_tree_member (
  node_id                     int(10) unsigned NOT NULL,
  member_id                   int(10) unsigned NOT NULL, 
  method_link_species_set_id  int(10) unsigned NOT NULL,
  cigar_line                  mediumtext,
  cigar_start                 int(10),
  cigar_end                   int(10),

  UNIQUE (node_id),
  KEY (member_id)
);

CREATE TABLE protein_tree_tag (
  node_id                int(10) unsigned NOT NULL,
  tag                    varchar(50),
  value                  mediumtext,

  UNIQUE tag_node_id (node_id, tag),
  KEY (node_id),
  KEY (tag)
);

