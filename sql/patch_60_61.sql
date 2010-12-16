# Updating the schema version:
UPDATE meta SET meta_value = 61 where meta_key = "schema_version";

# Add a new index to the "domain" table
alter table domain add index method_link_species_set_id (method_link_species_set_id);

# Add a new index to the "species_set" table
alter table species_set add index genome_db_id (genome_db_id);

# Add a new index to the "protein_tree_member"
alter table protein_tree_member add index method_link_species_set_id (method_link_species_set_id);

# Add a new index to the "protein_tree_member_score"
alter table protein_tree_member_score add index method_link_species_set_id (method_link_species_set_id);

# Add a new index to the "super_protein_tree_member"
alter table super_protein_tree_member add index method_link_species_set_id (method_link_species_set_id);

# Add a new index to the "nc_tree_member"
alter table nc_tree_member add index method_link_species_set_id (method_link_species_set_id);

# Modify tag column in table species_set_tag 
alter table species_set_tag modify tag varchar(50) NOT NULL;

