# Updating the schema version

UPDATE meta SET meta_value = 56 where meta_key = "schema_version";


# Add strand info to constrained_element for EPO anchor generation

alter table constrained_element add column dnafrag_strand int(2);


