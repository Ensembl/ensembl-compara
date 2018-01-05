-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

/* 
 The script assumes both compara and ancestral core dbs are on the same mysql-server instance.
 Given a genomic_align_block_id it will delete the genomic_align_* entries and ancestral dnafrags 
 from the compara db and corresponding seqs from the core db.

 mysql> use my_compara_db
 mysql> \! mysql -uUsername -pPassword -hHost -Dmy_compara_db < this_file.sql
 mysql> call delgabs("genomic_align_block_id"); 
*/

DROP TABLE IF EXISTS temp_dnafrags2delete;
CREATE TABLE temp_dnafrags2delete (dnafrag_id bigint(20), name varchar(50), 
seq_region_id bigint(20) not null default 0,
unique key (dnafrag_id), unique key (name) ) ;

DELIMITER |

DROP FUNCTION IF EXISTS get_root_id;
CREATE FUNCTION get_root_id ( gab_id BIGINT )
RETURNS BIGINT
BEGIN 
  DECLARE root_id BIGINT;
  SET root_id = ( SELECT DISTINCT(gat.root_id) FROM genomic_align_tree gat
  INNER JOIN genomic_align_group gag ON gag.node_id = gat.node_id 
  INNER JOIN genomic_align ga ON ga.genomic_align_id = gag.genomic_align_id
  WHERE ga.genomic_align_block_id = gab_id );
  INSERT INTO temp_dnafrags2delete ( SELECT df.dnafrag_id, df.name, 0 FROM dnafrag df 
  INNER JOIN genomic_align ga ON ga.dnafrag_id = df.dnafrag_id 
  INNER JOIN genomic_align_group gag ON gag.genomic_align_id = ga.genomic_align_id
  INNER JOIN genomic_align_tree gat ON gag.node_id = gat.node_id 
  WHERE gat.root_id = root_id AND df.name LIKE "Ancestor%" );
  RETURN root_id;
END
|

DROP FUNCTION IF EXISTS get_ancestor_db_name;
CREATE FUNCTION get_ancestor_db_name ()
RETURNS VARCHAR(500) 
BEGIN
  DECLARE ancestor_db VARCHAR(500);
  SET ancestor_db = ( SELECT SUBSTR(locator, LOCATE("dbname=",locator) + 7, 
  (LOCATE(";", locator, (LOCATE("dbname=",locator))) - (LOCATE("dbname=",locator) + 7))) 
  FROM genome_db WHERE name = "ancestral_sequences");
  RETURN ancestor_db;
END
|

DROP PROCEDURE IF EXISTS populate_temp_table;
CREATE PROCEDURE populate_temp_table ( IN gab_id BIGINT, OUT ancestor_db VARCHAR(500), OUT root_id BIGINT )
BEGIN
  SELECT get_root_id( gab_id ) INTO root_id; 
  SELECT get_ancestor_db_name() INTO ancestor_db; 
  SET @update_stmt = CONCAT("UPDATE temp_dnafrags2delete tdf, ", ancestor_db, 
  ".seq_region asr SET tdf.seq_region_id = asr.seq_region_id WHERE tdf.name = asr.name;");
  PREPARE stmt FROM @update_stmt;
  EXECUTE stmt;
END
|

DROP PROCEDURE IF EXISTS delgabs;
CREATE PROCEDURE delgabs( IN gab_id BIGINT )
BEGIN
  DECLARE root_id BIGINT;
  DECLARE ancestDB VARCHAR(500);
  call populate_temp_table(gab_id, @ancestDB, @root_id);
  SET @delancest = CONCAT("DELETE ", @ancestDB, ".seq.*,",  @ancestDB, ".sr.* FROM ", @ancestDB, ".dna seq INNER JOIN ", @ancestDB, 
  ".seq_region sr ON sr.seq_region_id = seq.seq_region_id INNER JOIN temp_dnafrags2delete tdf ON tdf.seq_region_id = sr.seq_region_id;");
  PREPARE stmt FROM @delancest;
  EXECUTE stmt;
  DELETE df.* FROM dnafrag df INNER JOIN temp_dnafrags2delete tdf ON df.dnafrag_id = tdf.dnafrag_id;
  DELETE ga.*, gab.*, gag.*, gat.* FROM genomic_align ga INNER JOIN
  genomic_align_block gab ON gab.genomic_align_block_id = ga.genomic_align_block_id INNER JOIN 
  genomic_align_group gag ON gag.genomic_align_id = ga.genomic_align_id INNER JOIN 
  genomic_align_tree gat ON gag.node_id = gat.node_id WHERE gat.root_id = @root_id;
END
|
