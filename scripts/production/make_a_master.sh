prod_cmd=mysql-eg-prod-1
prod_db=ensembl_compara_plants_39_92

mast_cmd=mysql-ens-compara-prod-2-ensadmin
mast_db=plants_compara_master_41_94

# ## TESTING
# $prod_cmd $prod_db
# $mast_cmd $mast_db

## Make the new master database
echo "Creating master db"
$mast_cmd mysqladmin CREATE $mast_db


## Carefull with this, but lets clean the production database...
echo "Cleaning the production db"
${prod_cmd}-ensrw $prod_db --show-warnings -vv -e '
  DELETE g, d FROM genome_db g
  INNER JOIN dnafrag d
  USING (genome_db_id)
  WHERE last_release IS NOT NULL;
  DELETE m, t FROM method_link_species_set m
  INNER JOIN method_link_species_set_tag t
  USING (method_link_species_set_id)
  WHERE last_release IS NOT NULL; 
  DELETE s, h FROM species_set s
  INNER JOIN species_set_header h
  USING (species_set_id)
  WHERE last_release IS NOT NULL; 
'



## Each of these tables should be copied over...

table_list=(
    dnafrag
    genome_db
    mapping_session
    meta
    method_link
    method_link_species_set
    method_link_species_set_tag
    ncbi_taxa_name
    ncbi_taxa_node
    species_set
    species_set_header
    species_set_tag
)

echo "Copying tables"
for table in ${table_list[*]}; do
    $prod_cmd mysqldump $prod_db $table \
        | $mast_cmd $mast_db &
done
echo "Done! $mast_cmd $mast_db"
