# Updating the schema version:
UPDATE meta SET meta_value = 59 where meta_key = "schema_version";

# Use production names, i.e. no whitespaces and all lowercases:
UPDATE genome_db SET name = LCASE(REPLACE(name, " ", "_"));

# a new column to the dnafrag table to hold information about whether
# a DnaFrag is part of the reference assembly or not:
ALTER TABLE dnafrag ADD COLUMN is_reference tinyint(1) DEFAULT 1;
UPDATE dnafrag, genome_db
 SET is_reference = 0
 WHERE dnafrag.genome_db_id = genome_db.genome_db_id
 AND genome_db.name = "homo_sapiens"
 AND coord_system_name = "chromosome"
 AND (dnafrag.name like "H%" or dnafrag.name like "c%");


