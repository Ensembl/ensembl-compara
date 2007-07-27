
# Updating the schema version

UPDATE meta SET meta_value = 46 where meta_key = "schema_version";

# Renamed node_id to ancestor_node_id and created a tree_node_id that
# will make queries easier and faster when relating homologies to whole
# trees

ALTER TABLE homology CHANGE COLUMN node_id ancestor_node_id int(10) unsigned NOT NULL;

ALTER TABLE homology ADD COLUMN tree_node_id int(10) unsigned NOT NULL;
