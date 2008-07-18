
# Updating the schema version

UPDATE meta SET meta_value = 50 where meta_key = "schema_version";

# e!49: genomic_align_tree.node_id linked to genomic_align.genomic_align_id
# e!50: genomic_align_tree.node_id now links to genomic_align_group.group_id and
#       genomic_align_group.genomic_align_id to genomic_align.genomic_align_id
# This is required to support composite segments in the GenomicAlignTrees. This
# patch assumes no data exists in the genomic_align_group table and there are no
# composite segments in the existing database. This is true for e!49

INSERT INTO genomic_align_group SELECT node_id, "epo", node_id FROM genomic_align_tree;

# sitewise DN/DS

CREATE TABLE sitewise_aln (
  sitewise_id                 int(10) unsigned NOT NULL auto_increment, # unique internal id
  aln_position                int(10) unsigned NOT NULL,
  node_id                     int(10) unsigned NOT NULL,
  tree_node_id                int(10) unsigned NOT NULL,
  omega                       float(10,5),
  omega_lower                 float(10,5),
  omega_upper                 float(10,5),
  threshold_on_branch_ds      float(10,5),
  type                        varchar(10) NOT NULL,

  FOREIGN KEY (node_id) REFERENCES protein_tree_node(node_id),

  UNIQUE aln_position_node_id_ds (aln_position,node_id,threshold_on_branch_ds),
  PRIMARY KEY (sitewise_id),
  KEY (node_id)
) COLLATE=latin1_swedish_ci;

CREATE TABLE sitewise_member (
  sitewise_id                 int(10) unsigned NOT NULL,
  member_id                   int(10) unsigned NOT NULL,
  member_position             int(10) unsigned NOT NULL,

  FOREIGN KEY (sitewise_id) REFERENCES sitewise_aln(sitewise_id),

  UNIQUE sitewise_member_position (sitewise_id,member_id,member_position),
  KEY (member_id)
) MAX_ROWS = 1000000000 COLLATE=latin1_swedish_ci;
