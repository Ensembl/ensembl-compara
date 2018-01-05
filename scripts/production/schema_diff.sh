#!/bin/bash

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

server=mysql-ens-compara-prod-1-ensadmin

this_release=`perl -e 'use Bio::EnsEMBL::ApiVersion; print software_version();'`
last_release=$(($this_release-1))


function do_exit () {
  echo "'$1' is not defined"
  exit 1
}

[[ "${this_release}" == "" ]] && do_exit 'Cannot find the Ensembl API version'
[[ "${USER}" == "" ]] && do_exit "'USER' is not defined"
[[ "${ENSEMBL_CVS_ROOT_DIR}" == "" ]] && do_exit "'ENSEMBL_CVS_ROOT_DIR' is not defined"
which db_cmd.pl > /dev/null || do_exit "db_cmd.pl not found in the path"
[[ -e ${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/schema_patcher.pl ]] || do_exit "schema_patcher.pl not found in ${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/"



function dump_schema () {
    mysqldump $($1 details mysql) --no-data --skip-add-drop-table --skip-lock-tables $2 | sed 's/AUTO_INCREMENT=[0-9]*\b//'
}

function create_db () {
  db_cmd.pl -url $1 -sql 'DROP DATABASE if exists'
  db_cmd.pl -url $1 -sql 'CREATE DATABASE'
  db_cmd.pl -url $1 < $2
  db_cmd.pl -url $1 -sql "SHOW TABLES LIKE 'peptide_align_feature_%'" -- -N | sed 's/^/DROP TABLE /' | sed 's/$/;/' | db_cmd.pl -url $1 
}


# Load, patch and dump the old schema
dump_schema mysql-ensembl-mirror ensembl_compara_${last_release} > old_schema.sql
create_db "$(${server} details url)${USER}_schema_patch_test_old_patched" old_schema.sql
mysqldump $(mysql-ensembl-mirror details mysql) --skip-lock-tables ensembl_compara_${last_release} meta | db_cmd.pl -url "$(${server} details url)${USER}_schema_patch_test_old_patched"

${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/schema_patcher.pl $(${server} details script) --database ${USER}_schema_patch_test_old_patched --type compara --from ${last_release} --release ${this_release} --verbose

dump_schema "${server}" "${USER}_schema_patch_test_old_patched" > patched_old_schema.sql
db_cmd.pl -url "$(${server} details url)${USER}_schema_patch_test_old_patched" -sql 'DROP DATABASE'

# Load and dump the new schema
create_db "$(${server} details url)${USER}_schema_patch_test_new" ${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/sql/table.sql
dump_schema "${server}" "${USER}_schema_patch_test_new" > new_schema.sql
db_cmd.pl -url "$(${server} details url)${USER}_schema_patch_test_new" -sql 'DROP DATABASE'

sdiff -w 200 -bs patched_old_schema.sql new_schema.sql
