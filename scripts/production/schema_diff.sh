server=compara5

this_release=`perl -e 'use Bio::EnsEMBL::ApiVersion; print software_version();'`
last_release=$(($this_release-1))


function do_exit () {
  echo "'$1' is not defined"
  exit 1
}

[[ "${this_release}" == "" ]] && do_exit 'Cannot find the Ensembl API version'
[[ "${ENSADMIN_PSW}" == "" ]] && do_exit "'ENSADMIN_PSW' is not defined"
[[ "${USER}" == "" ]] && do_exit "'USER' is not defined"
[[ "${ENSEMBL_CVS_ROOT_DIR}" == "" ]] && do_exit "'ENSEMBL_CVS_ROOT_DIR' is not defined"
which db_cmd.pl > /dev/null || do_exit "db_cmd.pl not found in the path"
[[ -e ${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/schema_patcher.pl ]] || do_exit "schema_patcher.pl not found in ${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/"



function dump_schema () {
	mysqldump -u ensro -h $1 -P3306 --no-data --skip-add-drop-table $2 | sed 's/AUTO_INCREMENT=[0-9]*\b//'
}

function create_db () {
  db_cmd.pl -url $1 -sql 'CREATE DATABASE'
  db_cmd.pl -url $1 < $2
}


# Load, patch and dump the old schema
dump_schema ens-livemirror ensembl_compara_${last_release} > old_schema.sql
create_db "mysql://ensadmin:${ENSADMIN_PSW}@${server}/${USER}_schema_patch_test_old_patched" old_schema.sql
mysqldump -u ensro -h ens-livemirror -P3306 ensembl_compara_${last_release} meta | db_cmd.pl -url "mysql://ensadmin:${ENSADMIN_PSW}@${server}/${USER}_schema_patch_test_old_patched"

${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/schema_patcher.pl --host ${server} --port 3306 --user ensadmin --pass $ENSADMIN_PSW --database ${USER}_schema_patch_test_old_patched --type compara --from ${last_release} --release ${this_release} --verbose

dump_schema "${server}" "${USER}_schema_patch_test_old_patched" > patched_old_schema.sql
db_cmd.pl -url "mysql://ensadmin:${ENSADMIN_PSW}@${server}/${USER}_schema_patch_test_old_patched" -sql 'DROP DATABASE'

# Load and dump the new schema
create_db "mysql://ensadmin:${ENSADMIN_PSW}@${server}/${USER}_schema_patch_test_new" ${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/sql/table.sql
dump_schema "${server}" "${USER}_schema_patch_test_new" > new_schema.sql
db_cmd.pl -url "mysql://ensadmin:${ENSADMIN_PSW}@${server}/${USER}_schema_patch_test_new" -sql 'DROP DATABASE'

sdiff -w 200 -bs patched_old_schema.sql new_schema.sql
