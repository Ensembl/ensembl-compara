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

# patch_100_101_c.sql
#
# Title: Remove the n_goc_null column from the method_link_species_set_attr table
#
# Description:
#   This column is not needed any more as genes that have no neighbours now
#   have a GOC score of 0, which is consistent with the other missing
#   neighbours are considered.


ALTER TABLE method_link_species_set_attr DROP COLUMN n_goc_null;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_100_101_c.sql|mlss_attr.n_goc_null');

