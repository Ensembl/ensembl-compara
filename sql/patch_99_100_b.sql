-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

# patch_99_100_b.sql
#
# Title: Alter the homology_id column to 64-bits integer.
#
# Description:
#   The homology_id has only been 32-bits integer, which as it stands only
#   room for another 130 genomes (a total of 370 in vertebrates). 64-bits
#   means potential for another 100,000 genomes. 


ALTER TABLE homology MODIFY homology_id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;
ALTER TABLE homology_member MODIFY homology_id bigint(20) UNSIGNED NOT NULL;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_99_100_b.sql|homology_id_64-bits');

