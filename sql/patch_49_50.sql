
# Updating the schema version

UPDATE meta SET meta_value = 50 where meta_key = "schema_version";

# e!49: genomic_align_tree.node_id linked to genomic_align.genomic_align_id
# e!50: genomic_align_tree.node_id now links to genomic_align_group.group_id and
#       genomic_align_group.genomic_align_id to genomic_align.genomic_align_id
# This is required to support composite segments in the GenomicAlignTrees. This
# patch assumes no data exists in the genomic_align_group table and there are no
# composite segments in the existing database. This is true for e!49

INSERT INTO genomic_align_group SELECT node_id, "epo", node_id FROM genomic_align_tree;

# DN/DS