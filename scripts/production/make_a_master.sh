#!/bin/bash

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

prod_cmd=mysql-eg-prod-1
prod_db=ensembl_compara_plants_40_93

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
    method_link_species_set_attr
    method_link_species_set_tag
    ncbi_taxa_name
    ncbi_taxa_node
    species_set
    species_set_header
    species_set_tag
)

echo "Copying tables"
$prod_cmd mysqldump $prod_db "${table_list[@]}" | $mast_cmd $mast_db
echo "Done! $mast_cmd $mast_db"
