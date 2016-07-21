# Instructions to make a new test database for homologies

You'll need the ensembl-hive scripts to be set up in your $PATH, and the environment variables $ENSADMIN\_PSW and $ENSEMBL\_CVS\_ROOT\_DIR.

## Test database for the REST API

1. Define a url

  ```bash
  export _TEST_DB_URL=mysql://ensadmin:${ENSADMIN_PSW}@compara5/mm14_homology_test_db_85
  ```

2. Create the database

  ```bash
  db_cmd.pl -url ${_TEST_DB_URL} -sql 'DROP DATABASE IF EXISTS'
  db_cmd.pl -url ${_TEST_DB_URL} -sql 'CREATE DATABASE'
  db_cmd.pl -url ${_TEST_DB_URL} < ${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/sql/table.sql
  ```

3. Import the data

  This will copy data from cc21\_ensembl\_compara\_84 to the test database, following the foreign keys found in cc21\_compara\_nctrees\_85 (this is needed because neither the source nor the target databases are in InnoDB and have foreign keys).
  We copy two gene-trees: ENSGT00390000003602 -BRCA2- and RF01299 -SNORD2-.

  ```bash
  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithFK -foreign_keys_db mysql://ensro@compara3/cc21_compara_nctrees_85 -db_conn mysql://ensro@compara5/cc21_ensembl_compara_84 -rfam_model_id RF01299 -protein_tree_stable_id ENSGT00390000003602 -compara_db $_TEST_DB_URL
  ```
  RF00012 is a good example of a gene-tree with a super-tree, but it is obviously pretty big.
  ENSFM00730001521062 is a good example of a Family. TODO: replace with PTHR

4. Delete unwanted stuff

  ```bash
  for i in species_tree_node_attr species_tree_node_tag method_link_species_set_tag gene_tree_root_attr
  do
    echo "TRUNCATE $i;"
  done | db_cmd.pl -url $_TEST_DB_URL
  db_cmd.pl -url $_TEST_DB_URL -sql 'DELETE FROM gene_tree_root_tag WHERE tag NOT LIKE "model\_%"'
  db_cmd.pl -url $_TEST_DB_URL -sql 'DELETE FROM other_member_sequence WHERE seq_type != "cds"'
  db_cmd.pl -url $_TEST_DB_URL -sql 'DELETE gene_align_member FROM gene_align JOIN gene_align_member USING (gene_align_id) WHERE seq_type != "cds"'
  db_cmd.pl -url $_TEST_DB_URL -sql 'DELETE FROM gene_align WHERE seq_type != "cds"'
  db_cmd.pl -url $_TEST_DB_URL -sql 'DELETE FROM other_member_sequence WHERE seq_type != "cds"'
  ```

5. Dump

  ```bash
  db_cmd.pl -url $_TEST_DB_URL -executable $ENSEMBL_CVS_ROOT_DIR/ensembl/misc-scripts/db/dump_mysql.pl -- --database mm14_homology_test_db_85 --verbose --testcompatible --directory dump_directory
  ```
  Then edit the sql file and add `CHARSET=latin1` to the meta and external\_db tables.

6. Manual edits

* To match the genes found in the human core database, I renamed a gene stable ID in the compara database
* To make some aligned strings different, I manually edited some cigar lines


