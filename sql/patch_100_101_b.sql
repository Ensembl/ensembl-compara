-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

# patch_100_101_b.sql
#
# Title: Increase the width of the strain_name column (genome_db table).
#
# Description:
#   The strain_name column of the genome_db table is not able to store
#   the name of our loa_loa genome (42 characters), so we simply increase
#   the width of the text field to match other fields of the table.


ALTER TABLE genome_db MODIFY strain_name VARCHAR(100) DEFAULT NULL;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_100_101_b.sql|genome_db.strain_name');

