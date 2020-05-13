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

# Useful for debugging (will show the commands being run)
#set -x

server=mysql-ens-compara-prod-1-ensadmin
server_prev=mysql-ens-mirror-1

this_release=$(perl -e 'use Bio::EnsEMBL::ApiVersion; print software_version();')
last_release=$((this_release - 1))


function do_exit () {
  echo "'$1' is not defined"
  exit 1
}

[[ "${this_release}" == "" ]] && do_exit 'Cannot find the Ensembl API version'
[[ "${USER}" == "" ]] && do_exit "'USER' is not defined"
[[ "${ENSEMBL_CVS_ROOT_DIR}" == "" ]] && do_exit "'ENSEMBL_CVS_ROOT_DIR' is not defined"
[[ -e ${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/schema_patcher.pl ]] || do_exit "schema_patcher.pl not found in ${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/"



function dump_schema () {
    "$1" mysqldump --no-data --skip-add-drop-table --skip-lock-tables "$2" | sed 's/AUTO_INCREMENT=[0-9]*\b//'
}

function create_db () {
    "$1" -e "DROP DATABASE IF EXISTS $2"
    "$1" -e "CREATE DATABASE $2"
    "$1" "$2" < "$3"
    "$1" "$2" -Nqe "SHOW TABLES LIKE 'peptide_align_feature_%'" | sed 's/^/DROP TABLE /' | sed 's/$/;/' | "$1" "$2"
}

DBNAME_OLD_PATCHED="${USER}_schema_patch_test_old_patched"
DBNAME_NEW="${USER}_schema_patch_test_new"

# Load, patch and dump the old schema
dump_schema "$server_prev" ensembl_compara_${last_release} > old_schema.sql
create_db "$server" "$DBNAME_OLD_PATCHED" old_schema.sql
"$server_prev" mysqldump --skip-lock-tables "ensembl_compara_${last_release}" meta | "$server" "$DBNAME_OLD_PATCHED"

"${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/schema_patcher.pl" $(${server} details script) --database "$DBNAME_OLD_PATCHED" --type compara --from "${last_release}" --release "${this_release}" --verbose

dump_schema "${server}" "$DBNAME_OLD_PATCHED" > patched_old_schema.sql
"$server" -e "DROP DATABASE $DBNAME_OLD_PATCHED"

# Load and dump the new schema
create_db "$server" "$DBNAME_NEW" "${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/sql/table.sql"
dump_schema "${server}" "$DBNAME_NEW" > new_schema.sql
"$server" -e "DROP DATABASE $DBNAME_NEW"

echo
echo '***********************************************************************************************************************'
echo 'Here comes the diff. If you see anything below, it means that there is a discrepancy between the schema and the patches'
echo '***********************************************************************************************************************'
echo

sanitize_schema () {
    cat "$1" | grep -v '^-- Host:' | grep -v '^-- Dump completed on '
}

sdiff -w 200 -bs <(sanitize_schema patched_old_schema.sql) <(sanitize_schema new_schema.sql) | tee schemas.diff
